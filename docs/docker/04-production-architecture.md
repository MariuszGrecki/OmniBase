# Production Multi-Industry Architecture

## 🎯 Cel (NOWA STRATEGIA)
Zaprojektować architekturę produkcyjną OmniBase z obsługą:
- **Osobne serwery** per branża (beauty.omnibase.pl, medical.omnibase.pl)
- **Ten sam kod** z różnymi INDUSTRY environment variables
- **Osobne bazy danych** per serwer dla pełnej izolacji
- **Modularny monolit** - conditional loading per branża
- **Standardowe porty** na każdym serwerze (8000, 8083)

## 🏗️ Architektura Overview (NOWA)

```
beauty.omnibase.pl (Serwer 1)          medical.omnibase.pl (Serwer 2)
┌─────────────────────────────┐        ┌─────────────────────────────┐
│ INDUSTRY=beauty             │        │ INDUSTRY=medical            │
│ ┌─────────────────────────┐ │        │ ┌─────────────────────────┐ │
│ │ Ten sam Docker Image   │ │        │ │ Ten sam Docker Image   │ │
│ │ - Laravel API :8000    │ │        │ │ - Laravel API :8000    │ │
│ │ - React Frontend :5173 │ │        │ │ - React Frontend :5173 │ │
│ │ - WebSocket :8083      │ │        │ │ - WebSocket :8083      │ │
│ └─────────────────────────┘ │        │ └─────────────────────────┘ │
│ ┌─────────────────────────┐ │        │ ┌─────────────────────────┐ │
│ │ beauty_omnibase (DB)   │ │        │ │ medical_omnibase (DB)  │ │
│ │ Redis                  │ │        │ │ Redis                  │ │
│ └─────────────────────────┘ │        │ └─────────────────────────┘ │
└─────────────────────────────┘        └─────────────────────────────┘

hotel.omnibase.pl (Serwer 3)           core.omnibase.pl (Serwer 4)  
┌─────────────────────────────┐        ┌─────────────────────────────┐
│ INDUSTRY=hotel              │        │ INDUSTRY=core               │
│ (identyczna struktura)     │        │ (identyczna struktura)     │
└─────────────────────────────┘        └─────────────────────────────┘
```

## 🚀 NOWA STRATEGIA: Modularny Monolit

### Kluczowe założenia:
- ✅ **Ten sam kod** na wszystkich serwerach  
- ✅ **INDUSTRY variable** określa zachowanie
- ✅ **Osobne bazy danych** per serwer (beauty_omnibase, medical_omnibase)
- ✅ **Conditional module loading** w Laravel
- ✅ **Dynamic component loading** w React

### Production Docker Compose (IDENTYCZNY na każdym serwerze)

```yaml
# docker-compose.yml (ten sam plik na wszystkich serwerach!)
version: '3.8'

services:
  omnibase-api:
    build:
      context: ./OmniBaseBackendNew
      dockerfile: Dockerfile
    container_name: omnibase-api
    ports:
      - "8000:8000"  # Standard port na każdym serwerze
      - "8083:8083"  # WebSocket port
    environment:
      - APP_ENV=production
      - INDUSTRY=${INDUSTRY}  # ← KLUCZOWA ZMIENNA!
      - APP_URL=https://${INDUSTRY}.omnibase.pl
      - DB_HOST=omnibase-postgres
      - DB_DATABASE=${INDUSTRY}_omnibase  # beauty_omnibase, medical_omnibase
      - DB_USERNAME=${INDUSTRY}_user
      - DB_PASSWORD=${DB_PASSWORD}
      - REDIS_HOST=omnibase-redis
    volumes:
      - ./OmniBaseBackendNew:/var/www:cached
    depends_on:
      - omnibase-postgres
      - omnibase-redis
    networks:
      - omnibase-net

  omnibase-frontend:
    build:
      context: ./OmniBaseFrontend
      dockerfile: Dockerfile
    container_name: omnibase-frontend
    ports:
      - "5173:5173"
    environment:
      - VITE_API_URL=https://${INDUSTRY}.omnibase.pl
      - VITE_INDUSTRY=${INDUSTRY}  # ← Frontend wie jaka branża
    depends_on:
      - omnibase-api
    networks:
      - omnibase-net

  omnibase-postgres:
    image: postgres:15-alpine
    container_name: omnibase-postgres
    environment:
      POSTGRES_DB: ${INDUSTRY}_omnibase  # beauty_omnibase, medical_omnibase
      POSTGRES_USER: ${INDUSTRY}_user
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - omnibase-net

  omnibase-redis:
    image: redis:7-alpine
    container_name: omnibase-redis
    volumes:
      - redis_data:/data
    networks:
      - omnibase-net

networks:
  omnibase-net:
    driver: bridge

volumes:
  postgres_data:
    name: ${INDUSTRY}-postgres-data  # beauty-postgres-data
  redis_data:
    name: ${INDUSTRY}-redis-data
```

## 🌐 Nginx Configuration

### `/nginx/nginx.conf`
```nginx
upstream beauty_api {
    server beauty-api-1:8000;
    server beauty-api-2:8000;
    server beauty-api-3:8000;
}

upstream beauty_websocket {
    server beauty-websocket-1:8083;
    server beauty-websocket-2:8083;
}

upstream hotel_api {
    server hotel-api-1:8000;
    server hotel-api-2:8000;
}

# Beauty Industry
server {
    listen 443 ssl http2;
    server_name beauty.omnibase.pl;

    ssl_certificate /etc/ssl/certs/beauty.omnibase.pl.crt;
    ssl_certificate_key /etc/ssl/certs/beauty.omnibase.pl.key;

    # API Routes
    location /api/ {
        proxy_pass http://beauty_api;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # WebSocket Routes
    location /ws {
        proxy_pass http://beauty_websocket;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }

    # Frontend (SPA)
    location / {
        proxy_pass http://beauty-frontend:80;
        proxy_set_header Host $host;
    }
}

# Hotel Industry  
server {
    listen 443 ssl http2;
    server_name hotel.omnibase.pl;

    ssl_certificate /etc/ssl/certs/hotel.omnibase.pl.crt;
    ssl_certificate_key /etc/ssl/certs/hotel.omnibase.pl.key;

    location /api/ {
        proxy_pass http://hotel_api;
        # ... similar config
    }

    location /ws {
        proxy_pass http://hotel_websocket;
        # ... WebSocket config
    }

    location / {
        proxy_pass http://hotel-frontend:80;
    }
}

# SSL Redirect
server {
    listen 80;
    server_name beauty.omnibase.pl hotel.omnibase.pl medical.omnibase.pl;
    return 301 https://$server_name$request_uri;
}
```

## 🔐 Environment Configuration Per Industry

### Beauty Environment
```env
# .env.beauty.production
APP_NAME="OmniBase Beauty"
APP_ENV=production
APP_URL=https://beauty.omnibase.pl

# Database
DB_DATABASE=beauty_omnibase
DB_USERNAME=beauty_user

# Industry-specific settings
ACCOUNT_TYPE_FILTER=beauty
REVERB_APP_ID=beauty_prod_${RANDOM_STRING}

# Feature flags
ENABLE_APPOINTMENT_BOOKING=true
ENABLE_SPA_SERVICES=true
ENABLE_BEAUTY_INVENTORY=true
```

### Hotel Environment
```env
# .env.hotel.production  
APP_NAME="OmniBase Hotel"
APP_ENV=production
APP_URL=https://hotel.omnibase.pl

# Database
DB_DATABASE=hotel_omnibase
DB_USERNAME=hotel_user

# Industry-specific
ACCOUNT_TYPE_FILTER=hotel
REVERB_APP_ID=hotel_prod_${RANDOM_STRING}

# Feature flags
ENABLE_ROOM_MANAGEMENT=true
ENABLE_ONLINE_BOOKING=true
ENABLE_RECREATION_CENTERS=true
```

## 🚀 Deployment Strategy (NOWA)

### Per-Server Deployment (REKOMENDOWANY)
```bash
# beauty.omnibase.pl (Serwer 1)
export INDUSTRY=beauty
export DB_PASSWORD=beauty_secure_password
docker-compose up -d

# medical.omnibase.pl (Serwer 2)  
export INDUSTRY=medical
export DB_PASSWORD=medical_secure_password
docker-compose up -d

# hotel.omnibase.pl (Serwer 3)
export INDUSTRY=hotel
export DB_PASSWORD=hotel_secure_password
docker-compose up -d

# Ten sam docker-compose.yml na każdym serwerze!
```

### Environment Files per serwer
```bash
# beauty.omnibase.pl → .env.beauty
INDUSTRY=beauty
DB_PASSWORD=beauty_secure_password
APP_URL=https://beauty.omnibase.pl

# medical.omnibase.pl → .env.medical
INDUSTRY=medical  
DB_PASSWORD=medical_secure_password
APP_URL=https://medical.omnibase.pl
```

## 📊 Monitoring & Scaling

### Health Checks
```yaml
# W każdym service
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s
```

### Auto-scaling based on load
```yaml
# docker-compose.beauty.yml
deploy:
  replicas: 2
  update_config:
    parallelism: 1
    delay: 10s
  restart_policy:
    condition: on-failure
  resources:
    limits:
      cpus: '1.0'
      memory: 1G
    reservations:
      cpus: '0.5'  
      memory: 512M
```

### Prometheus Monitoring
```yaml
# Monitoring stack
prometheus:
  image: prom/prometheus
  volumes:
    - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
  networks:
    - monitoring-net

grafana:
  image: grafana/grafana
  environment:
    - GF_SECURITY_ADMIN_PASSWORD=admin
  networks:
    - monitoring-net
```

## 🔒 Security Considerations

### SSL/TLS Management
```yaml
# Let's Encrypt automation
certbot:
  image: certbot/certbot
  volumes:
    - ./ssl:/etc/letsencrypt
  command: >
    certonly --webroot --webroot-path=/var/www/certbot
    --email admin@omnibase.pl --agree-tos --no-eff-email
    -d beauty.omnibase.pl -d hotel.omnibase.pl
```

### Network Isolation
```yaml
# Izolacja sieci per industria
networks:
  beauty-internal:
    driver: overlay
    internal: true
  
  beauty-external:
    driver: overlay
    
  shared-services:
    driver: overlay
    internal: true
```

### Secrets Management
```yaml
# Docker secrets
secrets:
  beauty_db_password:
    file: ./secrets/beauty_db_password.txt
  hotel_db_password:
    file: ./secrets/hotel_db_password.txt

# W services
services:
  beauty-api:
    secrets:
      - beauty_db_password
    environment:
      - DB_PASSWORD_FILE=/run/secrets/beauty_db_password
```

## 💾 Backup Strategy

### Per-Industry Backups
```bash
#!/bin/bash
# backup-beauty.sh

# Database backup
docker exec beauty-postgres pg_dump -U beauty_user beauty_omnibase > \
    "/backups/beauty/db_$(date +%Y%m%d_%H%M%S).sql"

# Files backup  
docker run --rm -v beauty_uploads:/data -v /backups/beauty:/backup \
    alpine tar czf /backup/files_$(date +%Y%m%d_%H%M%S).tar.gz /data

# Upload to S3
aws s3 sync /backups/beauty/ s3://omnibase-backups/beauty/
```

## 📈 Performance Optimization

### Database Connection Pooling
```yaml
# PgBouncer per industry
beauty-pgbouncer:
  image: pgbouncer/pgbouncer
  environment:
    - DATABASES_HOST=beauty-postgres
    - DATABASES_PORT=5432
    - DATABASES_USER=beauty_user
    - POOL_MODE=transaction
    - MAX_CLIENT_CONN=1000
    - DEFAULT_POOL_SIZE=25
```

### Redis Clustering
```yaml
redis-cluster:
  image: redis:7-alpine
  command: redis-server --cluster-enabled yes --cluster-config-file nodes.conf
  deploy:
    replicas: 6
```

## ✅ Zalety NOWEJ STRATEGII

### Modularny Monolit:
- ✅ **Maintenance** - jeden kod do utrzymania
- ✅ **CI/CD** - jeden pipeline, wiele deployments  
- ✅ **Feature development** - nowa funkcja raz, działa wszędzie
- ✅ **Security** - pełna izolacja danych per serwer
- ✅ **Compliance** - każda branża ma własne środowisko
- ✅ **Scalability** - niezależne skalowanie per branża
- ✅ **Cost-effective** - jeden Docker image dla wszystkich

### Porównanie z innymi podejściami:
| Aspekt | Microservices | Shared DB Multi-tenant | **Modularny Monolit** |
|--------|---------------|-------------------------|----------------------|
| **Maintenance** | ❌ Złożone | ✅ Proste | ✅ **Bardzo proste** |
| **Data isolation** | ✅ Pełna | ⚠️ Częściowa | ✅ **Pełna** |
| **Development** | ❌ Skomplikowane | ✅ Proste | ✅ **Bardzo proste** |
| **Deployment** | ❌ Złożone | ⚠️ Średnie | ✅ **Proste** |
| **Scalability** | ✅ Elastyczne | ⚠️ Ograniczone | ✅ **Per branża** |

## 🎯 Rekomendacja FINALNA
**Modularny Monolit** to idealne rozwiązanie dla OmniBase bo:
- **Development velocity** - szybki rozwój nowych funkcji
- **Security first** - pełna izolacja per branża  
- **Operational simplicity** - jeden kod, łatwe zarządzanie
- **Business model** - idealny dla multi-industry platform

## ➡️ Następny krok: [Deployment Guide](05-deployment-guide.md)