# WebSocket Integration - Etap 2

## 🎯 Cel etapu
Integracja Laravel Reverb WebSocket w środowisku Docker z:
- **Real-time communication** między frontend a backend
- **JWT authentication** dla WebSocket connections
- **Broadcasting events** via Redis między kontenerami
- **Company-scoped channels** dla multi-tenant architecture
- **Proper networking** między wszystkimi serwisami

## 🏗️ Architektura komunikacji

```
┌─────────────────┐    WebSocket     ┌──────────────────┐
│  React Frontend │ ◄──────────────► │ Laravel Reverb   │
│  (Port 5173)    │                  │ (Port 8083)      │
└─────────────────┘                  └──────────────────┘
         │                                     │
         │ HTTP API                           │ Redis
         ▼                                     ▼
┌─────────────────┐    Broadcasting   ┌──────────────────┐
│  Laravel API    │ ◄──────────────► │     Redis        │
│  (Port 8001)    │                  │  (Port 6380)     │
└─────────────────┘                  └──────────────────┘
         │                                     ▲
         │ Database                           │
         ▼                                     │
┌─────────────────┐                          │
│   PostgreSQL    │                          │
│  (Port 5433)    │                          │
└─────────────────┘                          │
                                              │
┌─────────────────┐    Queue Jobs            │
│ Queue Worker    │ ◄────────────────────────┘
│ (No Port)       │
└─────────────────┘
```

## 🔧 Konfiguracja Laravel Reverb

### Environment Variables (.env.docker)

```env
# Broadcasting Configuration
BROADCAST_CONNECTION=reverb
BROADCAST_DRIVER=reverb

# Reverb WebSocket Settings  
REVERB_APP_ID=omnibase_local
REVERB_APP_KEY=omnibase_key_local
REVERB_APP_SECRET=omnibase_secret_local
REVERB_HOST=0.0.0.0
REVERB_PORT=8083
REVERB_SCHEME=http

# Redis Configuration for Broadcasting
REDIS_HOST=omnibase-redis
REDIS_PORT=6379
REDIS_DB=0

# WebSocket CORS Settings
REVERB_ALLOWED_ORIGINS=http://localhost:5173,http://127.0.0.1:5173
```

### Reverb Configuration (config/reverb.php)

```php
<?php

return [
    'default' => env('REVERB_SERVER', 'reverb'),

    'servers' => [
        'reverb' => [
            'host' => env('REVERB_HOST', '0.0.0.0'),
            'port' => env('REVERB_PORT', 8083),
            'hostname' => env('REVERB_HOSTNAME'),
            'options' => [
                'tls' => [],
            ],
            'max_request_size' => env('REVERB_MAX_REQUEST_SIZE', 10000),
            'scaling' => [
                'enabled' => env('REVERB_SCALING_ENABLED', false),
                'channel' => env('REVERB_SCALING_CHANNEL', 'reverb'),
                'server' => [
                    'url' => env('REDIS_URL'),
                    'host' => env('REDIS_HOST', '127.0.0.1'),
                    'port' => env('REDIS_PORT', 6379),
                    'username' => env('REDIS_USERNAME'),
                    'password' => env('REDIS_PASSWORD'),
                    'database' => env('REDIS_DB', 0),
                ],
            ],
            'apps' => [
                [
                    'app_id' => env('REVERB_APP_ID'),
                    'app_key' => env('REVERB_APP_KEY'),
                    'app_secret' => env('REVERB_APP_SECRET'),
                    'options' => [
                        'host' => env('REVERB_HOST'),
                        'port' => env('REVERB_PORT'),
                        'scheme' => env('REVERB_SCHEME', 'http'),
                        'allowed_origins' => explode(',', env('REVERB_ALLOWED_ORIGINS', '')),
                    ],
                ],
            ],
        ],
    ],
];
```

## 🔐 JWT Authentication przez WebSocket

### Frontend WebSocket Connection z JWT

```javascript
// src/providers/WebSocketProvider.jsx
import Echo from 'laravel-echo';
import Pusher from 'pusher-js';
import { getCookie } from '../utils/tokenManager';

const setupWebSocket = () => {
    const token = getCookie('OmniBaseToken');
    const wsHost = import.meta.env.VITE_WS_HOST || '127.0.0.1';
    const wsPort = import.meta.env.VITE_WS_PORT || '8083';
    
    if (!token) {
        console.warn('No JWT token found for WebSocket connection');
        return null;
    }

    return new Echo({
        broadcaster: 'reverb',
        key: 'omnibase_key_local',
        wsHost,
        wsPort,
        wssPort: wsPort,
        forceTLS: false,
        enabledTransports: ['ws', 'wss'],
        auth: {
            headers: {
                Authorization: `Bearer ${token}`,
                Accept: 'application/json',
            },
        },
        // Company-scoped channels
        authEndpoint: 'http://localhost:8001/api/broadcasting/auth',
    });
};

export const WebSocketProvider = ({ children }) => {
    const [echo, setEcho] = useState(null);
    const { user } = useContext(UserContext);
    const { selectedCompany } = useContext(CompaniesContext);

    useEffect(() => {
        if (user && selectedCompany) {
            const echoInstance = setupWebSocket();
            setEcho(echoInstance);

            // Listen to company-scoped channel
            if (echoInstance) {
                const channel = echoInstance.private(`company.${selectedCompany.id}`);
                
                // Listen for various events
                channel.listen('.resource.created', (e) => {
                    console.log('Resource created:', e);
                    // Invalidate queries, show notifications, etc.
                });

                channel.listen('.reservation.updated', (e) => {
                    console.log('Reservation updated:', e);
                });
            }

            return () => {
                echoInstance?.disconnect();
            };
        }
    }, [user, selectedCompany]);

    return (
        <WebSocketContext.Provider value={{ echo }}>
            {children}
        </WebSocketContext.Provider>
    );
};
```

### Backend WebSocket Authentication

```php
// routes/channels.php
<?php

use Illuminate\Support\Facades\Broadcast;
use App\Models\User;

// Company-scoped private channel
Broadcast::channel('company.{companyId}', function (User $user, int $companyId) {
    // Verify user belongs to this company
    return $user->companies()->where('company_id', $companyId)->exists();
});

// User-specific private channel
Broadcast::channel('user.{userId}', function (User $user, int $userId) {
    return $user->id === $userId;
});
```

```php
// app/Http/Middleware/WebSocketAuth.php
<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Laravel\Passport\TokenRepository;
use Laravel\Passport\Token;

class WebSocketAuth
{
    public function handle(Request $request, Closure $next)
    {
        $token = $request->bearerToken();
        
        if (!$token) {
            return response()->json(['error' => 'Unauthorized'], 401);
        }

        // Validate JWT token
        $tokenRepository = app(TokenRepository::class);
        $tokenModel = $tokenRepository->findValidToken($token);
        
        if (!$tokenModel) {
            return response()->json(['error' => 'Invalid token'], 401);
        }

        // Set authenticated user
        $request->setUserResolver(function () use ($tokenModel) {
            return $tokenModel->user;
        });

        return $next($request);
    }
}
```

## 📡 Broadcasting Events w Docker

### Model Broadcasting Events

```php
// app/Models/Resource.php
<?php

namespace App\Models;

use App\Traits\BroadcastsEvents;
use Illuminate\Database\Eloquent\Model;

class Resource extends Model
{
    use BroadcastsEvents;

    protected $fillable = ['name', 'type', 'company_id', 'industry_data'];

    // Broadcasting configuration
    protected function broadcastChannel(): string
    {
        return "company.{$this->company_id}";
    }

    protected function broadcastEventData(): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'type' => $this->type,
            'company_id' => $this->company_id,
            'updated_at' => $this->updated_at,
        ];
    }
}
```

### Broadcasting Events Trait

```php
// app/Traits/BroadcastsEvents.php
<?php

namespace App\Traits;

use Illuminate\Support\Facades\Broadcast;

trait BroadcastsEvents
{
    protected static function bootBroadcastsEvents()
    {
        static::created(function ($model) {
            $model->broadcastCreated();
        });

        static::updated(function ($model) {
            $model->broadcastUpdated();
        });

        static::deleted(function ($model) {
            $model->broadcastDeleted();
        });
    }

    protected function broadcastCreated()
    {
        Broadcast::channel($this->broadcastChannel())
            ->send(class_basename($this) . '.created', $this->broadcastEventData());
    }

    protected function broadcastUpdated()
    {
        Broadcast::channel($this->broadcastChannel())
            ->send(class_basename($this) . '.updated', $this->broadcastEventData());
    }

    protected function broadcastDeleted()
    {
        Broadcast::channel($this->broadcastChannel())
            ->send(class_basename($this) . '.deleted', ['id' => $this->id]);
    }

    // Override in models
    abstract protected function broadcastChannel(): string;
    abstract protected function broadcastEventData(): array;
}
```

## 🐳 Docker Configuration Update

### Supervisor Configuration Update

```ini
# OmniBaseBackendNew/docker/supervisord.conf

[supervisord]
nodaemon=true
user=root
logfile=/var/log/supervisor/supervisord.log
pidfile=/var/run/supervisord.pid

[program:laravel-serve]
command=php artisan serve --host=0.0.0.0 --port=8000
directory=/var/www
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
autorestart=true
startretries=3
priority=100

[program:laravel-reverb]
command=php artisan reverb:start --host=0.0.0.0 --port=8083 --verbose
directory=/var/www
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
autorestart=true
startretries=3
priority=200

[program:laravel-queue]
command=php artisan queue:work redis --sleep=3 --tries=3 --max-time=3600 --timeout=60
directory=/var/www
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
autorestart=true
startretries=3
numprocs=2
priority=300
```

### Docker Compose Network Configuration

```yaml
# docker-compose.yml - Network section update
version: '3.8'

services:
  omnibase-api:
    build:
      context: ./OmniBaseBackendNew
    container_name: omnibase-api
    ports:
      - "8001:8000"  # API
      - "8083:8083"  # WebSocket - WAŻNE: ten sam kontener!
    environment:
      # ... existing env vars ...
      - REVERB_HOST=0.0.0.0
      - REVERB_PORT=8083
      - REVERB_SCALING_ENABLED=true  # Enable Redis scaling
      - REDIS_HOST=omnibase-redis
    networks:
      - omnibase-net
    depends_on:
      - omnibase-postgres
      - omnibase-redis

  # Nie potrzebujemy osobnego kontenera WebSocket!
  # Reverb działa w tym samym kontenerze co API przez supervisor

  omnibase-frontend:
    environment:
      - VITE_API_URL=http://localhost:8001
      - VITE_WS_HOST=127.0.0.1
      - VITE_WS_PORT=8083
      - VITE_WS_SCHEME=ws

networks:
  omnibase-net:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
```

## 🧪 Testing WebSocket w Docker

### WebSocket Test Commands

```bash
#!/bin/bash
# test-websocket.sh

echo "🔍 Testing WebSocket Connection"

# 1. Check if Reverb is running
echo "📡 Checking Reverb process..."
docker-compose exec omnibase-api supervisorctl status laravel-reverb

# 2. Test WebSocket endpoint
echo "🔌 Testing WebSocket endpoint..."
curl -v http://localhost:8083/app/omnibase_local

# 3. Test with websocat (if available)
echo "💬 Testing WebSocket connection..."
# websocat ws://localhost:8083/app/omnibase_local

# 4. Check Redis connection
echo "📊 Testing Redis connection..."
docker-compose exec omnibase-redis redis-cli ping

# 5. Check broadcasting configuration
echo "⚙️ Checking Laravel config..."
docker-compose exec omnibase-api php artisan config:show broadcasting
```

### Frontend WebSocket Test Panel

```jsx
// src/components/WebSocketTestPanel/WebSocketTestPanel.jsx
import React, { useState, useContext } from 'react';
import { WebSocketContext } from '../../providers/WebSocketProvider';

export const WebSocketTestPanel = () => {
    const { echo } = useContext(WebSocketContext);
    const [messages, setMessages] = useState([]);
    const [testChannel, setTestChannel] = useState('');

    const testConnection = () => {
        if (!echo) {
            addMessage('❌ Echo instance not available');
            return;
        }

        addMessage('🔍 Testing WebSocket connection...');
        
        // Test private channel
        const channel = echo.private(`company.${testChannel}`);
        
        channel.subscribed(() => {
            addMessage('✅ Successfully subscribed to channel');
        });

        channel.error((error) => {
            addMessage(`❌ Channel error: ${error.message}`);
        });

        // Listen for test events
        channel.listen('.test.event', (data) => {
            addMessage(`📨 Received test event: ${JSON.stringify(data)}`);
        });
    };

    const addMessage = (message) => {
        setMessages(prev => [...prev, `${new Date().toLocaleTimeString()}: ${message}`]);
    };

    return (
        <div className="websocket-test-panel">
            <h3>🧪 WebSocket Test Panel</h3>
            
            <div className="test-controls">
                <input
                    type="text"
                    value={testChannel}
                    onChange={(e) => setTestChannel(e.target.value)}
                    placeholder="Company ID for testing"
                />
                <button onClick={testConnection}>Test Connection</button>
            </div>

            <div className="test-output">
                <h4>📋 Test Results:</h4>
                <div className="messages">
                    {messages.map((msg, index) => (
                        <div key={index} className="message">{msg}</div>
                    ))}
                </div>
            </div>

            <div className="connection-info">
                <h4>🔗 Connection Info:</h4>
                <p>Status: {echo ? '🟢 Connected' : '🔴 Disconnected'}</p>
                <p>Host: {import.meta.env.VITE_WS_HOST}:{import.meta.env.VITE_WS_PORT}</p>
            </div>
        </div>
    );
};
```

## 🚀 Performance Optimization

### Redis Scaling Configuration

```env
# .env.docker - Redis scaling dla multiple Reverb instances
REVERB_SCALING_ENABLED=true
REVERB_SCALING_CHANNEL=reverb
REDIS_URL=redis://omnibase-redis:6379/0
```

### Connection Pooling

```php
// config/database.php - Redis configuration
'redis' => [
    'client' => env('REDIS_CLIENT', 'phpredis'),
    
    'options' => [
        'cluster' => env('REDIS_CLUSTER', 'redis'),
        'prefix' => env('REDIS_PREFIX', Str::slug(env('APP_NAME', 'laravel'), '_').'_database_'),
    ],

    'default' => [
        'url' => env('REDIS_URL'),
        'host' => env('REDIS_HOST', '127.0.0.1'),
        'password' => env('REDIS_PASSWORD'),
        'port' => env('REDIS_PORT', '6379'),
        'database' => env('REDIS_DB', '0'),
        'read_write_timeout' => 60,
        'persistent_connections' => true,
    ],

    'cache' => [
        'url' => env('REDIS_URL'),
        'host' => env('REDIS_HOST', '127.0.0.1'),
        'password' => env('REDIS_PASSWORD'),
        'port' => env('REDIS_PORT', '6379'),
        'database' => env('REDIS_CACHE_DB', '1'),
    ],
],
```

## 🔧 Troubleshooting WebSocket

### Common Issues

1. **Connection Refused**
```bash
# Check if port is exposed
docker-compose ps
# Should show 8083:8083 mapping

# Check Reverb logs
docker-compose logs omnibase-api | grep reverb
```

2. **Authentication Failed**
```bash
# Check JWT token validity
docker-compose exec omnibase-api php artisan passport:check-token

# Test auth endpoint
curl -H "Authorization: Bearer YOUR_TOKEN" \
     http://localhost:8001/api/broadcasting/auth
```

3. **Events Not Broadcasting**
```bash
# Check Redis connection
docker-compose exec omnibase-api php artisan queue:work --once

# Test broadcasting manually
docker-compose exec omnibase-api php artisan tinker
> broadcast(new App\Events\TestEvent());
```

### Debug Mode

```env
# Enable verbose WebSocket logging
REVERB_LOG_LEVEL=debug
LOG_LEVEL=debug

# Enable Laravel broadcasting debug
BROADCAST_DEBUG=true
```

## ✅ Verification Checklist

Po implementacji sprawdź:

- [ ] **Reverb process** działa w kontenerze (supervisorctl status)
- [ ] **Port 8083** jest dostępny z host machine
- [ ] **WebSocket connection** łączy się z frontend
- [ ] **JWT authentication** działa dla private channels
- [ ] **Broadcasting events** są wysyłane po CRUD operations
- [ ] **Company-scoped channels** ograniczają dostęp
- [ ] **Redis** jako message broker działa poprawnie
- [ ] **Queue worker** przetwarza broadcasting jobs

## 🎯 Rezultat Etapu 2

Po zakończeniu tego etapu będziesz miał:
- ✅ **Działający WebSocket** w środowisku Docker
- ✅ **Real-time updates** między frontend a backend
- ✅ **Bezpieczną autoryzację** WebSocket connections
- ✅ **Multi-tenant broadcasting** per company
- ✅ **Scalable architecture** z Redis message broker

## ➡️ Następny krok: [Etap 3 - Environment Configuration](04-production-architecture.md)