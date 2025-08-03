# 🚀 OmniBase Docker Quick Start Guide

**Status:** ✅ **GOTOWE DO TESTOWANIA!**

## 📋 **Co jest gotowe:**
- ✅ Kompletna dockeryzacja z INDUSTRY support
- ✅ Przełączanie branż jedną komendą
- ✅ Supervisor (3 procesy Laravel w jednym kontenerze)
- ✅ WebSocket (Laravel Reverb) + Queue worker
- ✅ Health check scripts
- ✅ Development-friendly setup

---

## 🚀 **PIERWSZE URUCHOMIENIE**

### 1. **Przygotowanie środowiska**
```bash
cd D:\OmniBase

# Skopiuj environment file
copy .env.docker OmniBaseBackendNew\.env
```

### 2. **Pierwsze uruchomienie z Beauty industry**
```bash
# Uruchom z branżą Beauty (domyślne)
INDUSTRY=beauty docker-compose up --build
```

### 3. **Weryfikacja (w osobnym terminalu)**
```bash
# Sprawdź status wszystkich serwisów
./health-check.sh

# Lub ręcznie:
# API: http://localhost:8001
# Frontend: http://localhost:5173
# pgAdmin: http://localhost:5050 (admin@omnibase.local / admin123)
```

---

## 🏭 **PRZEŁĄCZANIE MIĘDZY BRANŻAMI**

### **Metoda 1: Helper script (REKOMENDOWANE)**
```bash
# Przełącz na Medical
./switch-industry.sh medical

# Przełącz na Hotel  
./switch-industry.sh hotel

# Przełącz na Beauty
./switch-industry.sh beauty
```

### **Metoda 2: Ręczne przełączanie**
```bash
# Stop obecnego
docker-compose down

# Start z nową branżą
INDUSTRY=medical docker-compose up --build
INDUSTRY=hotel docker-compose up --build
INDUSTRY=veterinary docker-compose up --build
```

---

## 🔧 **DOSTĘPNE KOMENDY**

### **Podstawowe operacje:**
```bash
# Start z konkretną branżą
INDUSTRY=beauty docker-compose up

# Stop wszystkiego
docker-compose down

# Restart bez rebuilding
docker-compose restart

# Rebuild i start
INDUSTRY=beauty docker-compose up --build
```

### **Debugging:**
```bash
# Sprawdź status kontenerów
docker-compose ps

# Zobacz logi
docker-compose logs -f omnibase-api
docker-compose logs -f omnibase-frontend

# Wejdź do kontenera
docker-compose exec omnibase-api bash

# Sprawdź aktualną branżę
docker-compose exec omnibase-api printenv INDUSTRY
```

### **Laravel komendy w kontenerze:**
```bash
# Migracje
docker-compose exec omnibase-api php artisan migrate

# Seeding
docker-compose exec omnibase-api php artisan db:seed

# Clear cache
docker-compose exec omnibase-api php artisan cache:clear

# Check supervisor status
docker-compose exec omnibase-api supervisorctl status
```

---

## 🌐 **DOSTĘPNE SERWISY**

| Serwis | URL | Opis |
|--------|-----|------|
| **API** | http://localhost:8001 | Laravel API |
| **Frontend** | http://localhost:5173 | React App (hot-reload) |
| **WebSocket** | ws://localhost:8083 | Laravel Reverb |
| **pgAdmin** | http://localhost:5050 | Database management |
| **Redis** | localhost:6380 | Redis (internal) |
| **PostgreSQL** | localhost:5433 | Database (internal) |

---

## 🏭 **DOSTĘPNE BRANŻE**

| Industry | Komenda | Opis |
|----------|---------|------|
| **beauty** | `INDUSTRY=beauty` | Salony piękności, SPA |
| **medical** | `INDUSTRY=medical` | Praktyki medyczne |
| **hotel** | `INDUSTRY=hotel` | Hotele, ośrodki rekreacyjne |
| **veterinary** | `INDUSTRY=veterinary` | Kliniki weterynaryjne |
| **childcare** | `INDUSTRY=childcare` | Przedszkola, żłobki |
| **parking** | `INDUSTRY=parking` | Zarządzanie parkingami |
| **equipment_rental** | `INDUSTRY=equipment_rental` | Wypożyczalnie sprzętu |
| **car_rental** | `INDUSTRY=car_rental` | Wypożyczalnie aut |
| **car_lot** | `INDUSTRY=car_lot` | Dealerzy samochodowi |
| **core** | `INDUSTRY=core` | Biznes uniwersalny |

---

## 🔍 **DIAGNOSTYKA PROBLEMÓW**

### **Problem: Porty zajęte**
```bash
# Sprawdź co używa portów
netstat -ano | findstr :8001
netstat -ano | findstr :5173

# Zatrzymaj AtlasShift jeśli konflikt
docker-compose -f ../atlasshift/docker-compose.yml down
```

### **Problem: Kontener nie startuje**
```bash
# Sprawdź logi
docker-compose logs omnibase-api

# Sprawdź czy baza jest dostępna
docker-compose exec omnibase-api wait-for-it.sh omnibase-postgres:5432 -t 30
```

### **Problem: WebSocket nie działa**
```bash
# Test WebSocket
curl -v http://localhost:8083/app/omnibase_local

# Sprawdź Reverb process
docker-compose exec omnibase-api supervisorctl status laravel-reverb
```

### **Problem: Hot-reload nie działa**
```bash
# Sprawdź czy Vite server jest dostępny
curl http://localhost:5173

# Restart frontend
docker-compose restart omnibase-frontend
```

---

## ⚡ **NASTĘPNE KROKI**

Po udanych testach:

1. **Konfiguracja Laravel** - dodanie INDUSTRY support w kodzie
2. **WebSocket integration** - test real-time events  
3. **Frontend components** - dynamic loading per industry
4. **Database seeding** - test data per industry

---

## 📞 **WSPARCIE**

Jeśli coś nie działa:
1. Uruchom `./health-check.sh`
2. Sprawdź logi: `docker-compose logs`
3. Zrestartuj: `docker-compose down && INDUSTRY=beauty docker-compose up --build`

---

**🎯 Status**: ✅ **READY FOR TESTING!**
**🗓️ Utworzono**: 2025-08-02
**🏭 Default Industry**: beauty