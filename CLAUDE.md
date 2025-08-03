# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

OmniBase is a multi-industry business management platform built with:
- **Backend**: Laravel 11.9 API with Laravel Passport JWT authentication
- **Frontend**: React 18 + TanStack Query + Vite
- **WebSocket**: Laravel Reverb for real-time communication
- **Database**: PostgreSQL with multi-tenant architecture

The system supports multiple business types across 9 industries: hospitality (hotels & recreational centers), beauty (salons, cosmetics, SPA), healthcare (medical practices, veterinary clinics), childcare (kindergartens & nurseries), parking management, equipment rental, car rental & dealerships, and core business management.

## Common Development Commands

### Backend (Laravel) - `OmniBaseBackendNew/`
```bash
# Development servers (run simultaneously in separate terminals)
php artisan serve                    # API server (port 8000)
php artisan reverb:start            # WebSocket server (port 8083)
php artisan queue:work --timeout=60 # Queue worker (critical for real-time)

# Database operations
php artisan migrate
php artisan db:seed
php artisan migrate:refresh --seed

# Laravel Passport
php artisan passport:install
php artisan passport:keys

# Cache management
php artisan cache:clear
php artisan config:clear
php artisan config:cache
php artisan queue:restart

# Testing
php artisan test
```

### Frontend (React) - `OmniBaseFrontend/`
```bash
# Development
yarn dev                # Vite dev server (port 5173)

# Build and deployment
yarn build
yarn preview

# Linting
yarn lint
```

## Architecture Overview

### Multi-Industry Support
- **Universal login** at `/login` - works for all account types
- **Industry-specific registration** at `/register/{account_type}` (core, hotel, beauty, medical, veterinary, childcare, parking, equipment_rental, car_rental, car_lot)
- **Dynamic component loading** using Vite-compatible import.meta.glob
- **Industry-specific configurations** for colors, features, and UI

### Authentication Flow
- **JWT tokens** via Laravel Passport (migrated from Sanctum)
- **Cookie-based storage** for tokens (`OmniBaseToken`, `OmniBaseUser`, `OmniBaseCompany`)
- **Automatic token refresh** and logout on expiration
- **WebSocket authentication** using JWT Bearer tokens

### Real-time Features
- **WebSocket integration** with Laravel Reverb
- **Private channels** scoped by company ID (`company.{companyId}`)
- **Automatic query invalidation** on WebSocket events
- **Broadcasting events** for all CRUD operations (*.created, *.updated, *.deleted)

### Data Management
- **TanStack Query v5** for API state management and caching
- **Company-scoped queries** - all data filtered by user's company_id
- **Optimistic updates** for better UX
- **Real-time synchronization** via WebSocket events

## Key File Locations

### Backend Structure
```
OmniBaseBackendNew/
├── app/Http/Controllers/Api/     # API controllers
├── app/Models/                   # Eloquent models with BroadcastsEvents trait
├── app/Events/                   # WebSocket events (auto-generated)
├── app/Http/Requests/            # Form validation
├── routes/api.php                # API routes
├── database/migrations/          # Database schema
└── config/broadcasting.php       # WebSocket configuration
```

### Frontend Structure
```
OmniBaseFrontend/
├── src/services/                 # API layer with axios
├── src/hooks/                    # TanStack Query hooks
├── src/hooks/mutations/          # Mutation hooks
├── src/containers/               # Context providers
├── src/components/               # Reusable components
├── src/pages/                    # Page components
├── src/containers/Modals/        # Modal components (needs TanStack Query migration)
└── src/utils/                    # Utilities (queryKeys, queryClient)
```

## Critical Development Notes

### Backend Requirements
1. **Always run 3 processes**: `php artisan serve`, `php artisan reverb:start`, `php artisan queue:work`
2. **Company scoping**: All queries must filter by `company_id`
3. **JWT authentication**: Use `Auth::guard('api')->user()` for protected routes
4. **Broadcasting events**: Models use `BroadcastsEvents` trait for automatic WebSocket events

### Frontend Requirements
1. **Authentication-aware contexts**: UserContext and CompaniesContext only fetch when authenticated
2. **Query key scoping**: All TanStack Query keys include `companyId` for multi-tenancy
3. **WebSocket integration**: Real-time updates automatically invalidate relevant queries
4. **Modal pattern**: Use mutation hooks instead of direct API calls (migration in progress)

### Critical Multi-Tenant Patterns
- **Backend**: Always scope data by `$user->company_id`
- **Frontend**: Include `companyId` in all query keys: `['resources', companyId]`
- **WebSocket**: Private channels scoped to company: `company.{companyId}`
- **Security**: Validate user belongs to company before data access

## WebSocket Setup

The real-time system requires proper configuration:

1. **Environment variables** (`.env`):
```env
BROADCAST_CONNECTION=reverb
REVERB_APP_ID=omnibase_local
REVERB_APP_KEY=omnibase_key_local
REVERB_APP_SECRET=omnibase_secret_local
REVERB_HOST="localhost"
REVERB_PORT=8083
```

2. **Frontend config** (`config.js`):
```js
wsHost: '127.0.0.1'
wsPort: 8083
```

## Industry-Specific Development

### Supported Account Types
- `core` - Core business management
- `hotel` - Hotels and recreational centers with booking management
- `beauty` - Beauty salons, cosmetic centers, SPA with appointment booking
- `medical` - Medical practices and clinics with patient/appointment management
- `veterinary` - Veterinary clinics with pet/appointment management
- `childcare` - Kindergartens and nurseries with children/staff/payment management
- `parking` - Parking management and billing systems
- `equipment_rental` - Equipment rental (bikes, tools, electronics)
- `car_rental` - Car rental services
- `car_lot` - Car dealerships with vehicle sales and fleet management

### Registration Flow
- Universal login handles all account types
- Separate registration endpoints validate industry-specific data
- Company model includes `account_type` and `industry_data` JSON field

### Detailed Business Types Overview
- **Hotel & Recreation** - Online booking system for hotels and recreational centers
- **Beauty & SPA** - Online booking system for beauty industry (hair salons, cosmetic centers, SPA)
- **Medical & Healthcare** - Appointment booking for medical practices and clinics
- **Veterinary** - Appointment booking for veterinary clinics and practices
- **Childcare** - Management system for kindergartens and nurseries (children, staff, payments)
- **Parking Management** - Parking management and billing systems
- **Equipment Rental** - Equipment rental services (bikes, tools, electronics)
- **Car Rental** - Car rental services management
- **Car Dealership** - Car dealership management (sales and fleet status)

## Current Migration Status

### ✅ Completed
- JWT authentication with Laravel Passport
- WebSocket integration with proper authentication
- Context optimization to prevent login page errors
- Dynamic component loading (Vite compatibility)
- Multi-industry support with universal login

### 🔄 In Progress
- Modal components migration to TanStack Query mutations (0/12 completed)
- Complete TanStack Query integration across all components

## Common Issues & Troubleshooting

1. **Real-time updates not working**: Ensure queue worker is running (`php artisan queue:work`)
2. **WebSocket connection failed**: Check if port 8083 is available and Reverb server is running
3. **Login redirect loops**: Fixed - contexts now only fetch when authenticated
4. **Dynamic imports failing**: Fixed - using import.meta.glob for Vite compatibility
5. **Cross-company data access**: Always validate `company_id` in backend and include in frontend query keys

## Testing Commands

### Backend Tests
```bash
php artisan test                          # Run all tests
php artisan test --filter UserTest        # Run specific test
```

### Frontend Tests
```bash
yarn test                                 # Run Jest tests (if configured)
```

### Manual Testing
- Use WebSocket test panel in frontend for real-time testing
- Test with `php artisan reverb:start --debug` for verbose WebSocket logs
- Verify JWT tokens in browser cookies: `OmniBaseToken`, `OmniBaseUser`, `OmniBaseCompany`