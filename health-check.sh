#!/bin/bash
# health-check.sh - OmniBase Docker Health Check

echo "🔍 OmniBase Health Check"
echo "========================"

# Check containers
echo "📦 Container Status:"
docker-compose ps

echo ""
echo "🌐 Service Health:"

# API Health
echo -n "API (8001): "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8001 2>/dev/null)
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ]; then
    echo "✅ OK ($HTTP_CODE)"
else
    echo "❌ FAIL ($HTTP_CODE)"
fi

# Frontend Health  
echo -n "Frontend (5173): "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5173 2>/dev/null)
if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ OK"
else
    echo "❌ FAIL ($HTTP_CODE)"
fi

# WebSocket Health
echo -n "WebSocket (8083): "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8083/app/omnibase_local 2>/dev/null)
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "101" ]; then
    echo "✅ OK"
else
    echo "❌ FAIL ($HTTP_CODE)"
fi

# Database Health
echo -n "Database (5433): "
if docker-compose exec -T omnibase-postgres pg_isready -p 5432 >/dev/null 2>&1; then
    echo "✅ OK"
else
    echo "❌ FAIL"
fi

# Redis Health
echo -n "Redis (6380): "
if docker-compose exec -T omnibase-redis redis-cli ping >/dev/null 2>&1; then
    echo "✅ OK"
else
    echo "❌ FAIL"
fi

echo ""
echo "📊 Resource Usage:"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"

echo ""
echo "🏭 Current Industry Configuration:"
CURRENT_INDUSTRY=$(docker-compose exec -T omnibase-api printenv INDUSTRY 2>/dev/null || echo "Not set")
echo "Industry: $CURRENT_INDUSTRY"

echo ""
echo "📋 Recent Logs (last 10 lines):"
echo "--- API Logs ---"
docker-compose logs --tail 10 omnibase-api

echo ""
echo "--- Frontend Logs ---"
docker-compose logs --tail 10 omnibase-frontend