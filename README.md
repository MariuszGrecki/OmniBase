# OmniBase

**Multi-Industry Business Management Platform**

A comprehensive business management solution supporting 9 different industries with real-time features, multi-tenant architecture, and industry-specific customizations.

## 🏢 Supported Industries

- **🏨 Hotel & Recreation** - Online booking system for hotels and recreational centers
- **💄 Beauty & SPA** - Appointment booking for beauty industry (hair salons, cosmetic centers, SPA)
- **🏥 Medical & Healthcare** - Appointment booking for medical practices and clinics  
- **🐾 Veterinary** - Appointment booking for veterinary clinics and practices
- **🧸 Childcare** - Management system for kindergartens and nurseries (children, staff, payments)
- **🅿️ Parking Management** - Parking management and billing systems
- **🔧 Equipment Rental** - Equipment rental services (bikes, tools, electronics)
- **🚗 Car Rental** - Car rental services management
- **🚙 Car Dealership** - Car dealership management (sales and fleet status)

## 🛠️ Tech Stack

### Backend
- **Laravel 11.9** - PHP framework with API-first architecture
- **Laravel Passport** - JWT authentication system
- **Laravel Reverb** - WebSocket server for real-time communication
- **PostgreSQL** - Primary database with multi-tenant support
- **Redis** - Cache and queue management

### Frontend
- **React 18** - Modern UI framework
- **TanStack Query v5** - API state management and caching
- **Vite** - Fast development and build tool
- **Dynamic Component Loading** - Industry-specific UI components

### Infrastructure
- **Docker** - Complete containerization
- **Supervisor** - Multi-process management
- **Multi-tenant Architecture** - Company-scoped data isolation

## 🚀 Quick Start with Docker

### Prerequisites
- Docker and Docker Compose installed
- Ports available: 5173, 8001, 8083, 5433, 6380, 5050

### 1. Clone and Setup
```bash
git clone <repository-url>
cd OmniBase
```

### 2. Start with Default Industry (Beauty)
```bash
docker-compose up --build -d
```

### 3. Start with Specific Industry
```bash
# Medical industry
INDUSTRY=medical docker-compose up -d

# Hotel industry  
INDUSTRY=hotel docker-compose up -d

# Available: beauty, medical, hotel, veterinary, childcare, parking, equipment_rental, car_rental, car_lot
```

### 4. Access Services
- **Frontend**: http://localhost:5173
- **Backend API**: http://localhost:8001  
- **WebSocket**: ws://localhost:8083
- **pgAdmin**: http://localhost:5050 (admin@example.com / admin123)
- **PostgreSQL**: localhost:5433 (omnibase / secret)
- **Redis**: localhost:6380

## 🏗️ Architecture Overview

### Multi-Tenant Design
- **Universal Login** - Single login endpoint for all industries
- **Industry-Specific Registration** - Separate endpoints per business type
- **Company-Scoped Data** - All data filtered by `company_id`
- **Dynamic UI** - Industry-specific components and styling

### Real-Time Features
- **WebSocket Integration** - Laravel Reverb with JWT authentication
- **Private Channels** - Company-scoped: `company.{companyId}`
- **Auto Query Invalidation** - TanStack Query syncs with WebSocket events
- **Broadcasting Events** - All CRUD operations broadcast changes

### API Architecture
- **RESTful APIs** - Clean, consistent endpoints
- **JWT Authentication** - Secure token-based auth
- **Multi-Process Backend** - API + WebSocket + Queue workers
- **Real-Time Sync** - Automatic data synchronization

## 📁 Project Structure

```
OmniBase/
├── OmniBaseBackendNew/          # Laravel 11 API
│   ├── app/Http/Controllers/Api/ # API controllers
│   ├── app/Models/              # Eloquent models
│   ├── app/Events/              # WebSocket events
│   ├── database/migrations/     # Database schema
│   └── docker/                  # Docker configuration
├── OmniBaseFrontend/            # React application
│   ├── src/services/            # API layer
│   ├── src/hooks/               # TanStack Query hooks
│   ├── src/components/          # Reusable components
│   └── src/pages/               # Page components
├── docs/docker/                 # Docker documentation
├── docker-compose.yml           # Container orchestration
└── README.md                    # This file
```

## 🔧 Development

### Backend Development
```bash
# Enter backend container
docker exec -it omnibase-api bash

# Run migrations
php artisan migrate

# Generate API keys
php artisan passport:install

# Clear cache
php artisan cache:clear
php artisan config:clear
```

### Frontend Development
```bash
# Enter frontend container  
docker exec -it omnibase_frontend sh

# Install dependencies
yarn install

# Development server
yarn dev
```

### Database Management
```bash
# Connect to PostgreSQL
docker exec -it omnibase-postgres psql -U omnibase -d omnibase

# View logs
docker logs omnibase-api
docker logs omnibase_frontend
```

## 🌐 Industry Configuration

### Switching Industries
Each industry has its own configuration and UI components:

```bash
# Development - switch locally
INDUSTRY=beauty docker-compose up -d
INDUSTRY=medical docker-compose up -d

# Production - separate servers per industry
# beauty.omnibase.pl: INDUSTRY=beauty
# medical.omnibase.pl: INDUSTRY=medical
```

### Industry Features
- **Dynamic Component Loading** - Industry-specific UI
- **Custom Color Schemes** - Per-industry branding
- **Feature Toggles** - Industry-specific functionality
- **Separate Registration** - Custom onboarding flows

## 🔒 Security Features

- **JWT Authentication** - Secure token-based access
- **Company Data Isolation** - Multi-tenant security
- **WebSocket Authentication** - Bearer token validation
- **API Rate Limiting** - Request throttling
- **Input Validation** - Request validation layers

## 📊 Database Schema

### Core Tables
- `users` - User accounts with company relationships
- `companies` - Multi-tenant company data
- `resources` - Industry-specific resources
- `customers` - Customer management
- `reservations` - Booking and appointment system
- `blockades` - Resource blocking/maintenance
- `tasks` - Internal task management

### Authentication Tables
- `oauth_*` - Laravel Passport JWT system
- `personal_access_tokens` - API tokens

## 🚦 API Endpoints

### Authentication
```
POST /api/login          # Universal login
POST /api/register/{type} # Industry-specific registration
POST /api/logout         # Logout
```

### Core Resources
```
GET    /api/companies    # Company data
GET    /api/users        # Company users
GET    /api/resources    # Industry resources
GET    /api/customers    # Customer management
GET    /api/reservations # Bookings/appointments
```

## 📡 WebSocket Events

### Event Types
- `*.created` - Resource creation
- `*.updated` - Resource updates  
- `*.deleted` - Resource deletion

### Channel Structure
```javascript
// Private company channel
channel: `company.${companyId}`

// Example events
'reservation.created'
'customer.updated'
'resource.deleted'
```

## 🧪 Testing

### Backend Tests
```bash
docker exec omnibase-api php artisan test
```

### Manual Testing
- WebSocket test panel in frontend
- pgAdmin for database inspection
- API testing via browser/Postman

## 📋 Environment Variables

### Docker Compose
```env
INDUSTRY=beauty          # Target industry
DB_CONNECTION=pgsql      # Database type
DB_HOST=omnibase-postgres # Database host
REVERB_APP_KEY=***       # WebSocket key
REDIS_HOST=omnibase-redis # Cache host
```

## 🔍 Troubleshooting

### Common Issues

1. **Port Conflicts**
   - Check ports 5173, 8001, 8083, 5433, 6380, 5050
   - Stop conflicting services

2. **WebSocket Connection Failed**
   - Ensure Reverb server is running
   - Check port 8083 availability
   - Verify JWT token validity

3. **Database Connection**
   - Verify PostgreSQL container is running
   - Check database credentials
   - Ensure migrations are run

4. **Cache Issues**
   - Clear Laravel cache: `php artisan cache:clear`
   - Clear config cache: `php artisan config:clear`

### Development Commands
```bash
# View all containers
docker ps --filter "name=omnibase"

# Check logs
docker logs omnibase-api --tail 50
docker logs omnibase_frontend --tail 50

# Restart services
docker-compose restart

# Clean rebuild
docker-compose down
docker-compose up --build -d
```

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## 📄 License

This project is proprietary software. All rights reserved.

---

## 📞 Support

For technical support or questions about implementation, please refer to:
- `docs/docker/` - Detailed Docker documentation
- `CLAUDE.md` - Development guidelines and architecture details
- Issue tracker for bug reports and feature requests

**Built with ❤️ for multi-industry business management**