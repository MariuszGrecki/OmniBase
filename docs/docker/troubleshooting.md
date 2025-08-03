# Troubleshooting Guide

## 🐛 Najczęstsze problemy i rozwiązania

### 1. Konflikty portów

#### Problem
```
Error starting userland proxy: listen tcp4 0.0.0.0:8000: bind: address already in use
```

#### Rozwiązanie
```bash
# Sprawdź co używa portu
netstat -tulpn | grep :8000

# Zatrzymaj istniejący stack AtlasShift  
docker-compose -f ../atlasshift/docker-compose.yml down

# Lub zmień porty w docker-compose.yml
ports:
  - "8001:8000"  # Zmiana z 8000 na 8001
```

### 2. Database connection refused

#### Problem
```
SQLSTATE[HY000] [2002] Connection refused
```

#### Rozwiązanie
```bash
# Sprawdź czy PostgreSQL startuje
docker-compose logs omnibase-postgres

# Sprawdź network connectivity
docker-compose exec omnibase-api ping omnibase-postgres

# Sprawdź czy wait-for-it działa
docker-compose exec omnibase-api wait-for-it.sh omnibase-postgres:5432 -t 30

# Jeśli nadal nie działa, dodaj delay przed migracjami
# W entrypoint.sh:
sleep 10
php artisan migrate --force
```

### 3. WebSocket connection failed

#### Problem
```
WebSocket connection to 'ws://localhost:8083/app/omnibase_local' failed
```

#### Diagnostyka
```bash
# Sprawdź czy Reverb startuje
docker-compose logs omnibase-api | grep reverb

# Test connection z poziomu kontenera
docker-compose exec omnibase-api curl -v http://localhost:8083/app/omnibase_local

# Sprawdź port mapping
docker-compose ps
```

#### Rozwiązanie
```bash
# Upewnij się że Reverb startuje w supervisord.conf
[program:laravel-reverb]
command=php artisan reverb:start --host=0.0.0.0 --port=8083
autorestart=true

# Sprawdź konfigurację frontend
# config.js musi mieć:
wsHost: '127.0.0.1',
wsPort: '8083'
```

### 4. Hot-reload nie działa (Frontend)

#### Problem
Zmiany w kodzie React nie są odzwierciedlane w przeglądarce

#### Rozwiązanie
```yaml
# W docker-compose.yml dodaj environment
omnibase-frontend:
  environment:
    - WATCHPACK_POLLING=true
    - CHOKIDAR_USEPOLLING=true
  volumes:
    - ./OmniBaseFrontend:/app:cached
    - /app/node_modules  # Exclude node_modules
```

### 5. Laravel Passport keys missing

#### Problem
```
Key path "file:///var/www/storage/oauth-public.key" does not exist or is not readable
```

#### Rozwiązanie
```bash
# Regenerate keys w kontenerze
docker-compose exec omnibase-api php artisan passport:install --force

# Lub dodaj do entrypoint.sh
if [ ! -f "storage/oauth-private.key" ]; then
    php artisan passport:install --force
fi
```

### 6. Permission denied na storage

#### Problem
```
The stream or file "/var/www/storage/logs/laravel.log" could not be opened: failed to open stream: Permission denied
```

#### Rozwiązanie
```dockerfile
# W Dockerfile dodaj
RUN chown -R www-data:www-data /var/www/storage \
    && chown -R www-data:www-data /var/www/bootstrap/cache \
    && chmod -R 775 /var/www/storage \
    && chmod -R 775 /var/www/bootstrap/cache
```

### 7. Slow performance na Windows

#### Problem
Docker bardzo wolno działa na Windows

#### Rozwiązanie
```yaml
# Użyj cached volumes
volumes:
  - ./OmniBaseBackendNew:/var/www:cached
  - ./OmniBaseFrontend:/app:cached

# Exclude vendor i node_modules z synchronizacji
  - /var/www/vendor
  - /app/node_modules

# Rozważ WSL2 backend w Docker Desktop
```

### 8. Environment variables nie są czytane

#### Problem
Laravel nie widzi zmiennych środowiskowych z .env

#### Rozwiązanie
```bash
# Sprawdź czy .env jest poprawnie skopiowany
docker-compose exec omnibase-api cat .env

# Sprawdź czy APP_KEY jest ustawiony
docker-compose exec omnibase-api php artisan key:generate

# Clear config cache
docker-compose exec omnibase-api php artisan config:clear
```

### 9. CORS errors z frontend

#### Problem
```
Access to XMLHttpRequest blocked by CORS policy
```

#### Rozwiązanie
```php
// W config/cors.php
'allowed_origins' => [
    'http://localhost:5173',
    'http://127.0.0.1:5173',
],

'allowed_origins_patterns' => [
    '/^http:\/\/localhost:\d+$/',
],
```

### 10. Queue jobs nie są przetwarzane

#### Problem
Queue jobs pozostają w stanie "pending"

#### Diagnostyka
```bash
# Sprawdź czy queue worker działa
docker-compose logs omnibase-api | grep queue

# Sprawdź Redis connection
docker-compose exec omnibase-api php artisan queue:work --once --verbose

# Sprawdź job status
docker-compose exec omnibase-api php artisan queue:failed
```

#### Rozwiązanie
```bash
# Restart queue worker
docker-compose restart omnibase-api

# Clear failed jobs
docker-compose exec omnibase-api php artisan queue:flush

# Monitor queue w real-time
docker-compose exec omnibase-api php artisan queue:monitor
```

## 🔧 Narzędzia diagnostyczne

### Health Check Script
```bash
#!/bin/bash
# health-check.sh

echo "🔍 OmniBase Health Check"
echo "========================"

# Check containers
echo "📦 Container Status:"
docker-compose ps

echo ""
echo "🌐 Service Health:"

# API Health
echo -n "API (8001): "
curl -s -o /dev/null -w "%{http_code}" http://localhost:8001 || echo "FAIL"

# Frontend Health  
echo -n "Frontend (5173): "
curl -s -o /dev/null -w "%{http_code}" http://localhost:5173 || echo "FAIL"

# WebSocket Health
echo -n "WebSocket (8083): "
curl -s -o /dev/null -w "%{http_code}" http://localhost:8083/app/omnibase_local || echo "FAIL"

# Database Health
echo -n "Database (5433): "
docker-compose exec -T omnibase-postgres pg_isready -p 5432 || echo "FAIL"

# Redis Health
echo -n "Redis (6380): "
docker-compose exec -T omnibase-redis redis-cli ping || echo "FAIL"

echo ""
echo "📊 Resource Usage:"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"
```

### Log Aggregation
```bash
#!/bin/bash
# collect-logs.sh

mkdir -p logs/$(date +%Y-%m-%d)

# Collect all service logs
docker-compose logs omnibase-api > logs/$(date +%Y-%m-%d)/api.log
docker-compose logs omnibase-frontend > logs/$(date +%Y-%m-%d)/frontend.log  
docker-compose logs omnibase-postgres > logs/$(date +%Y-%m-%d)/postgres.log
docker-compose logs omnibase-redis > logs/$(date +%Y-%m-%d)/redis.log

echo "Logs collected in logs/$(date +%Y-%m-%d)/"
```

### Performance Monitoring
```bash
#!/bin/bash
# monitor.sh

# Watch container stats
watch -n 1 'docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"'
```

## 🚨 Emergency Procedures

### Complete Reset
```bash
#!/bin/bash
# reset-all.sh

echo "⚠️  This will destroy all data!"
read -p "Are you sure? (yes/no): " confirm

if [ "$confirm" = "yes" ]; then
    docker-compose down -v
    docker system prune -f
    docker volume prune -f
    docker-compose up --build
fi
```

### Backup Before Debug
```bash
#!/bin/bash
# backup-before-debug.sh

# Backup database
docker-compose exec omnibase-postgres pg_dump -U omnibase omnibase > backup_$(date +%Y%m%d_%H%M%S).sql

# Backup volumes
docker run --rm -v omnibase_postgres_data:/data -v $(pwd):/backup alpine tar czf /backup/postgres_backup_$(date +%Y%m%d_%H%M%S).tar.gz /data

echo "Backup completed. Safe to debug."
```

## 📞 Getting Help

### Informacje do zebrania przed zgłoszeniem
1. **Docker version**: `docker --version`
2. **Docker Compose version**: `docker-compose --version`
3. **OS and version**: `uname -a`
4. **Container logs**: `docker-compose logs`
5. **Container status**: `docker-compose ps`
6. **Error screenshots** jeśli dotyczy frontend

### Debugging Commands
```bash
# Enter container shell
docker-compose exec omnibase-api bash
docker-compose exec omnibase-frontend sh

# Check Laravel logs
docker-compose exec omnibase-api tail -f storage/logs/laravel.log

# Check supervisor status
docker-compose exec omnibase-api supervisorctl status

# Test database connection
docker-compose exec omnibase-api php artisan migrate:status

# Test WebSocket
docker-compose exec omnibase-api php artisan reverb:ping

# Test Redis
docker-compose exec omnibase-api php artisan cache:clear
```

## 🎯 Performance Tips

### Development Optimization
```yaml
# docker-compose.override.yml dla dev
version: '3.8'

services:
  omnibase-api:
    volumes:
      - ./OmniBaseBackendNew:/var/www:cached  # Cached mount
      - api_vendor:/var/www/vendor            # Named volume for vendor
    environment:
      - APP_DEBUG=true
      - LOG_LEVEL=debug

  omnibase-frontend:
    volumes:
      - ./OmniBaseFrontend:/app:cached
      - frontend_modules:/app/node_modules

volumes:
  api_vendor:
  frontend_modules:
```

### Production Monitoring
```yaml
# Dodaj do production compose
  prometheus:
    image: prom/prometheus
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml

  grafana:
    image: grafana/grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_PASSWORD}
```

---

**💡 Pro Tip**: Zawsze używaj `docker-compose logs -f [service_name]` do real-time debugging!

**🔄 Update frequency**: Ten dokument jest aktualizowany gdy znajdziemy nowe problemy i rozwiązania.