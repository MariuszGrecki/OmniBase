# Development Setup - Etap 1

## 🎯 Cel etapu
Podstawowa konteneryzacja dla środowiska development:
- Jeden docker-compose z INDUSTRY variable
- Jedna baza danych lokalnie, przełączanie branży przez rebuild
- Izolacja od istniejącego stacku AtlasShift
- Hot-reload dla development
- Proste uruchomienie: `INDUSTRY=beauty docker-compose up --build`

## 📁 Struktura plików

```
d:\OmniBase\
├── docker-compose.yml          # Główny plik dla development
├── .env.docker                 # Environment variables
├── .dockerignore               # Globalne wykluczenia
├── OmniBaseBackendNew/
│   ├── Dockerfile              # Laravel container
│   ├── .dockerignore
│   └── docker/
│       ├── php.ini
│       ├── supervisord.conf    # Laravel multi-process
│       └── wait-for-it.sh      # Wait for database
└── OmniBaseFrontend/
    ├── Dockerfile              # React container  
    ├── .dockerignore
    └── docker/
        └── nginx.conf          # Development nginx
```

## 🐳 Dockerfiles

### Backend (Laravel) - `OmniBaseBackendNew/Dockerfile`

```dockerfile
FROM php:8.2-fpm-alpine

# Install system dependencies
RUN apk add --no-cache \
    git \
    curl \
    libpng-dev \
    libzip-dev \
    zip \
    unzip \
    postgresql-dev \
    supervisor \
    nginx

# Install PHP extensions
RUN docker-php-ext-configure pgsql -with-pgsql=/usr/local/pgsql \
    && docker-php-ext-install \
        pdo \
        pdo_pgsql \
        pgsql \
        zip \
        gd \
        pcntl

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /var/www

# Copy composer files
COPY composer.json composer.lock ./

# Install dependencies
RUN composer install --no-dev --optimize-autoloader --no-interaction

# Copy application code
COPY . .

# Set permissions
RUN chown -R www-data:www-data /var/www \
    && chmod -R 755 /var/www/storage \
    && chmod -R 755 /var/www/bootstrap/cache

# Copy configuration files
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY docker/php.ini /usr/local/etc/php/conf.d/custom.ini
COPY docker/wait-for-it.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/wait-for-it.sh

# Generate Laravel key (will be overridden by .env)
RUN php artisan key:generate --show

# Install Passport keys (in entrypoint)
COPY docker/entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 8000 8083

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
```

### Frontend (React) - `OmniBaseFrontend/Dockerfile`

```dockerfile
FROM node:18-alpine

# Set working directory
WORKDIR /app

# Copy package files
COPY package.json yarn.lock ./

# Install dependencies
RUN yarn install --frozen-lockfile

# Copy source code
COPY . .

# Expose port
EXPOSE 5173

# Development command with hot reload
CMD ["yarn", "dev", "--host", "0.0.0.0", "--port", "5173"]
```

## 🔧 Konfiguracja pomocnicza

### Supervisor config - `OmniBaseBackendNew/docker/supervisord.conf`

```ini
[supervisord]
nodaemon=true
user=root
logfile=/var/log/supervisor/supervisord.log
pidfile=/var/run/supervisord.pid

[program:php-fpm]
command=php-fpm -F
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
autorestart=false
startretries=0

[program:laravel-serve]
command=php artisan serve --host=0.0.0.0 --port=8000
directory=/var/www
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
autorestart=true
startretries=3

[program:laravel-reverb]
command=php artisan reverb:start --host=0.0.0.0 --port=8083
directory=/var/www
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
autorestart=true
startretries=3

[program:laravel-queue]
command=php artisan queue:work --timeout=60 --sleep=3 --tries=3
directory=/var/www
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
autorestart=true
startretries=3
```

### Entrypoint script - `OmniBaseBackendNew/docker/entrypoint.sh`

```bash
#!/bin/sh

# Wait for database
wait-for-it.sh omnibase-postgres:5432 --timeout=30 --strict

# Wait for Redis
wait-for-it.sh omnibase-redis:6379 --timeout=30 --strict

# Run migrations
php artisan migrate --force

# Install Passport if not exists
if [ ! -f "storage/oauth-private.key" ]; then
    php artisan passport:install --force
fi

# Clear caches
php artisan config:clear
php artisan cache:clear

# Execute the main command
exec "$@"
```

### Wait-for-it script - `OmniBaseBackendNew/docker/wait-for-it.sh`

```bash
#!/usr/bin/env bash
# Standard wait-for-it.sh script
# (Tu wstawiłbym pełny skrypt, ale jest długi - można pobrać z GitHub)
```

## 🌐 Docker Compose - Development

### `docker-compose.yml`

```yaml
version: '3.8'

services:
  # === BACKEND SERVICES ===
  omnibase-api:
    build:
      context: ./OmniBaseBackendNew
      dockerfile: Dockerfile
    container_name: omnibase-api
    ports:
      - "8001:8000"  # API
      - "8083:8083"  # WebSocket
    environment:
      - APP_ENV=local
      - APP_DEBUG=true
      - INDUSTRY=${INDUSTRY:-beauty}
      - DB_HOST=omnibase-postgres
      - DB_PORT=5432
      - DB_DATABASE=omnibase
      - DB_USERNAME=omnibase
      - DB_PASSWORD=secret
      - REDIS_HOST=omnibase-redis
      - REDIS_PORT=6379
      - BROADCAST_CONNECTION=reverb
      - REVERB_APP_ID=omnibase_local
      - REVERB_APP_KEY=omnibase_key_local
      - REVERB_HOST=0.0.0.0
      - REVERB_PORT=8083
    volumes:
      - ./OmniBaseBackendNew:/var/www:cached
      - /var/www/vendor
      - /var/www/node_modules
    depends_on:
      - omnibase-postgres
      - omnibase-redis
    networks:
      - omnibase-net
    restart: unless-stopped

  # === FRONTEND ===
  omnibase-frontend:
    build:
      context: ./OmniBaseFrontend
      dockerfile: Dockerfile
    container_name: omnibase-frontend
    ports:
      - "5173:5173"
    environment:
      - VITE_API_URL=http://localhost:8001
      - VITE_WS_HOST=127.0.0.1
      - VITE_WS_PORT=8083
      - VITE_INDUSTRY=${INDUSTRY:-beauty}
    volumes:
      - ./OmniBaseFrontend:/app:cached
      - /app/node_modules
    depends_on:
      - omnibase-api
    networks:
      - omnibase-net
    restart: unless-stopped

  # === DATABASE ===
  omnibase-postgres:
    image: postgres:15-alpine
    container_name: omnibase-postgres
    ports:
      - "5433:5432"  # Avoid conflict with existing postgres
    environment:
      POSTGRES_DB: omnibase
      POSTGRES_USER: omnibase
      POSTGRES_PASSWORD: secret
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./database/init:/docker-entrypoint-initdb.d
    networks:
      - omnibase-net
    restart: unless-stopped

  # === REDIS ===
  omnibase-redis:
    image: redis:7-alpine
    container_name: omnibase-redis
    ports:
      - "6380:6379"  # Avoid conflict with existing redis
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data
    networks:
      - omnibase-net
    restart: unless-stopped

  # === PGADMIN ===
  omnibase-pgadmin:
    image: dpage/pgadmin4:latest
    container_name: omnibase-pgadmin
    ports:
      - "5050:80"
    environment:
      PGADMIN_DEFAULT_EMAIL: admin@omnibase.local
      PGADMIN_DEFAULT_PASSWORD: admin
      PGADMIN_CONFIG_SERVER_MODE: 'False'
    volumes:
      - pgadmin_data:/var/lib/pgadmin
    depends_on:
      - omnibase-postgres
    networks:
      - omnibase-net
    restart: unless-stopped

networks:
  omnibase-net:
    driver: bridge
    name: omnibase-network

volumes:
  postgres_data:
    name: omnibase-postgres-data
  redis_data:
    name: omnibase-redis-data
  pgadmin_data:
    name: omnibase-pgadmin-data
```

## 🔑 Environment Configuration

### `.env.docker` (główny katalog)

```env
# Laravel Application
APP_NAME=OmniBase
APP_ENV=local
APP_KEY=base64:GENERATE_NEW_KEY_HERE
APP_DEBUG=true
APP_URL=http://localhost:8001

# Industry Configuration (NOWE!)
INDUSTRY=${INDUSTRY:-beauty}

# Database
DB_CONNECTION=pgsql
DB_HOST=omnibase-postgres
DB_PORT=5432
DB_DATABASE=omnibase
DB_USERNAME=omnibase
DB_PASSWORD=secret

# Redis
REDIS_HOST=omnibase-redis
REDIS_PORT=6379
REDIS_PASSWORD=null

# WebSocket (Reverb)
BROADCAST_CONNECTION=reverb
REVERB_APP_ID=omnibase_local
REVERB_APP_KEY=omnibase_key_local
REVERB_APP_SECRET=omnibase_secret_local
REVERB_HOST=0.0.0.0
REVERB_PORT=8083
REVERB_SCHEME=http

# Session
SESSION_DRIVER=redis
SESSION_LIFETIME=120

# Cache
CACHE_DRIVER=redis

# Queue
QUEUE_CONNECTION=redis
```

### Frontend config update - `OmniBaseFrontend/config.js`

```javascript
const config = {
    // API URL - różne dla dev vs production
    apiUrl: import.meta.env.VITE_API_URL || 'http://localhost:8001',
    
    // Industry configuration (NOWE!)
    industry: import.meta.env.VITE_INDUSTRY || 'beauty',
    
    // WebSocket configuration
    wsHost: import.meta.env.VITE_WS_HOST || '127.0.0.1',
    wsPort: import.meta.env.VITE_WS_PORT || '8083',
    wsScheme: import.meta.env.VITE_WS_SCHEME || 'ws',
    
    // WebSocket connection string
    get wsUrl() {
        return `${this.wsScheme}://${this.wsHost}:${this.wsPort}`;
    }
};

export default config;
```

## 🚀 Uruchomienie

### Pierwszy setup
```bash
# W głównym katalogu projektu
cd d:\OmniBase

# Copy environment
cp .env.docker OmniBaseBackendNew/.env

# Build i uruchom z wybraną branżą
INDUSTRY=beauty docker-compose up --build

# W osobnym terminalu - migracje (jeśli potrzebne)
docker-compose exec omnibase-api php artisan migrate --seed
```

### Przełączanie między branżami (NOWE!)
```bash
# Beauty Industry
INDUSTRY=beauty docker-compose up --build

# Medical Industry  
INDUSTRY=medical docker-compose up --build

# Hotel Industry
INDUSTRY=hotel docker-compose up --build

# Core Business (domyślne)
INDUSTRY=core docker-compose up --build
```

### Codzienne użycie
```bash
# Start z konkretną branżą
INDUSTRY=beauty docker-compose up

# Stop
docker-compose down

# Restart konkretnego serwisu (zachowuje INDUSTRY)
docker-compose restart omnibase-api

# Logs
docker-compose logs -f omnibase-api

# Sprawdź aktualną branżę
docker-compose exec omnibase-api printenv INDUSTRY
```

## 🔍 Weryfikacja

### Sprawdź czy wszystko działa:
1. **API**: http://localhost:8001
2. **Frontend**: http://localhost:5173  
3. **pgAdmin**: http://localhost:5050 (admin@omnibase.local / admin)
4. **WebSocket**: Test w frontend WebSocket panel
5. **Database**: Połączenie przez pgAdmin lub bezpośrednio port 5433

### Health checks:
```bash
# Status kontenerów
docker-compose ps

# Logi z problemami  
docker-compose logs omnibase-api
docker-compose logs omnibase-frontend

# Test WebSocket
curl -v http://localhost:8083/app/omnibase_local
```

## ✅ Oczekiwane korzyści Etapu 1
- **Izolacja** od AtlasShift stacku
- **Prostota** - `INDUSTRY=beauty docker-compose up --build`
- **Flexibilność** - łatwe przełączanie między branżami
- **Development-ready** - hot reload działa + jedna baza lokalnie
- **Debugowanie** - łatwy dostęp do logów
- **Modularny monolit** - jeden kod, wiele konfiguracji

## ➡️ Następny krok: [Etap 2 - WebSocket Integration](03-websocket-integration.md)