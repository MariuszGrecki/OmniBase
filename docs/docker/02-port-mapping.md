# Port Mapping Strategy

## 🔍 Analiza obecnego stanu

### Zajęte porty (AtlasShift stack)
```yaml
# Istniejące serwisy
8000:8000  # atlasshift-backend  
3000:3000  # atlasshift-frontend
8080:8080  # adminer (pgAdmin alternative)
6379:6379  # redis
5432:5432  # postgres
```

### Potrzeby OmniBase
```yaml
# Wymagane serwisy
Laravel API Server:    8000  # ❌ KONFLIKT
React Dev Server:      5173  # ✅ OK (Vite default)
WebSocket (Reverb):    8083  # ✅ prawdopodobnie OK
PostgreSQL:            5432  # ❌ KONFLIKT  
Redis:                 6379  # ❌ KONFLIKT
pgAdmin:               5050  # ✅ nowy port
Queue Worker:          N/A   # ✅ bez portu
```

## 🎯 Strategia rozwiązania

### Option A: Zmiana portów OmniBase (REKOMENDOWANE)
```yaml
# docker-compose.yml dla OmniBase
services:
  omnibase-backend:
    ports:
      - "8001:8000"    # Laravel API
      
  omnibase-frontend:  
    ports:
      - "5173:5173"    # React/Vite (bez konfliktu)
      
  omnibase-websocket:
    ports:
      - "8083:8083"    # Reverb WebSocket
      
  omnibase-postgres:
    ports:
      - "5433:5432"    # PostgreSQL na alternatywnym porcie
      
  omnibase-redis:
    ports:
      - "6380:6379"    # Redis na alternatywnym porcie
      
  omnibase-pgadmin:
    ports:
      - "5050:80"      # pgAdmin (nowy)
```

### Option B: Network izolacja (Bardziej zaawansowane)
```yaml
# Osobne Docker networks
networks:
  atlasshift-net:
    driver: bridge
  omnibase-net:
    driver: bridge
    
# Każdy stack w swojej sieci
# Porty widoczne tylko wewnętrznie
```

## 🔧 Implementacja - Development

### docker-compose.dev.yml
```yaml
version: '3.8'

services:
  # === BACKEND STACK ===
  omnibase-api:
    build: ./OmniBaseBackendNew
    ports:
      - "8001:8000"
    environment:
      - DB_HOST=omnibase-postgres
      - REDIS_HOST=omnibase-redis
      - REVERB_HOST=omnibase-websocket
    depends_on:
      - omnibase-postgres
      - omnibase-redis
    networks:
      - omnibase-net

  omnibase-websocket:
    build: ./OmniBaseBackendNew
    command: php artisan reverb:start --host=0.0.0.0 --port=8083
    ports:
      - "8083:8083"
    environment:
      - DB_HOST=omnibase-postgres
      - REDIS_HOST=omnibase-redis
    depends_on:
      - omnibase-postgres
      - omnibase-redis
    networks:
      - omnibase-net

  omnibase-queue:
    build: ./OmniBaseBackendNew
    command: php artisan queue:work --timeout=60
    environment:
      - DB_HOST=omnibase-postgres
      - REDIS_HOST=omnibase-redis
    depends_on:
      - omnibase-postgres
      - omnibase-redis
    networks:
      - omnibase-net

  # === FRONTEND ===
  omnibase-frontend:
    build: ./OmniBaseFrontend
    ports:
      - "5173:5173"
    environment:
      - VITE_API_URL=http://localhost:8001
      - VITE_WS_HOST=127.0.0.1
      - VITE_WS_PORT=8083
    depends_on:
      - omnibase-api
    networks:
      - omnibase-net

  # === DATABASE STACK ===
  omnibase-postgres:
    image: postgres:15-alpine
    ports:
      - "5433:5432"
    environment:
      POSTGRES_DB: omnibase
      POSTGRES_USER: omnibase
      POSTGRES_PASSWORD: secret
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - omnibase-net

  omnibase-redis:
    image: redis:7-alpine
    ports:
      - "6380:6379"
    networks:
      - omnibase-net

  omnibase-pgadmin:
    image: dpage/pgadmin4
    ports:
      - "5050:80"
    environment:
      PGADMIN_DEFAULT_EMAIL: admin@omnibase.local
      PGADMIN_DEFAULT_PASSWORD: admin
    networks:
      - omnibase-net

networks:
  omnibase-net:
    driver: bridge

volumes:
  postgres_data:
```

## 🌐 Production Multi-Tenant Strategy

### Per-Industry Servers (NOWA STRATEGIA)
```yaml
# beauty.omnibase.pl (osobny serwer)
INDUSTRY=beauty docker-compose up
ports: 8000:8000, 8083:8083  # Standard ports per serwer

# hotel.omnibase.pl (osobny serwer)  
INDUSTRY=hotel docker-compose up
ports: 8000:8000, 8083:8083  # Te same porty, ale inny serwer

# medical.omnibase.pl (osobny serwer)
INDUSTRY=medical docker-compose up
ports: 8000:8000, 8083:8083  # Te same porty, ale inny serwer

# Ten sam kod, różne INDUSTRY env variables
```

### Production Deployment Strategy
```bash
# Każdy serwer ma standardowe porty (8000, 8083)
# Różnicuje je INDUSTRY variable

# beauty-server.omnibase.pl
INDUSTRY=beauty docker-compose up
# API: :8000, WebSocket: :8083, DB: beauty_omnibase

# medical-server.omnibase.pl  
INDUSTRY=medical docker-compose up
# API: :8000, WebSocket: :8083, DB: medical_omnibase

# Nginx na każdym serwerze kieruje na localhost:8000
# Bez potrzeby custom port mappingu
```

## 📝 Konfiguracja aplikacji

### Backend (.env.docker)
```env
# Industry configuration (NOWE!)
INDUSTRY=${INDUSTRY:-beauty}
APP_URL=http://localhost:8001
DB_CONNECTION=pgsql
DB_HOST=omnibase-postgres
DB_PORT=5432
DB_DATABASE=omnibase  # Lokalne: jedna baza, Production: per industry

REDIS_HOST=omnibase-redis
REDIS_PORT=6379

BROADCAST_CONNECTION=reverb
REVERB_APP_ID=omnibase_local
REVERB_APP_KEY=omnibase_key_local  
REVERB_HOST=omnibase-websocket
REVERB_PORT=8083
```

### Frontend (config.js)
```javascript
const config = {
  apiUrl: import.meta.env.VITE_API_URL || 'http://localhost:8001',
  wsHost: import.meta.env.VITE_WS_HOST || '127.0.0.1', 
  wsPort: import.meta.env.VITE_WS_PORT || '8083',
  
  // Industry configuration (NOWE!)
  industry: import.meta.env.VITE_INDUSTRY || 'beauty',
}
```

## ✅ Zalety NOWEGO podejścia
- **Brak konfliktów** z istniejącym stackiem AtlasShift (lokalnie)
- **Modularny monolit** - jeden kod, wiele konfiguracji
- **Prosty deployment** - ten sam docker-compose per serwer
- **Standardowe porty** - bez custom port mappingu w production
- **Development friendly** - łatwe przełączanie przez INDUSTRY variable

## ⚠️ Uwagi (ZAKTUALIZOWANE)
1. **INDUSTRY variable** musi być przekazany do wszystkich kontenerów
2. **Laravel config** musi obsługiwać conditional module loading
3. **Frontend** musi dynamicznie ładować komponenty per branża
4. **Database schema** identyczne, dane scoped per company (lokalnie)
5. **Production** - osobne bazy danych per serwer (beauty_omnibase, medical_omnibase)