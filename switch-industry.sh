#!/bin/bash
# switch-industry.sh - OmniBase Industry Switcher

# Available industries
INDUSTRIES=("beauty" "medical" "hotel" "core" "veterinary" "childcare" "parking" "equipment_rental" "car_rental" "car_lot")

show_usage() {
    echo "🏭 OmniBase Industry Switcher"
    echo "============================="
    echo ""
    echo "Usage: $0 [INDUSTRY]"
    echo ""
    echo "Available industries:"
    for industry in "${INDUSTRIES[@]}"; do
        echo "  - $industry"
    done
    echo ""
    echo "Examples:"
    echo "  $0 beauty"
    echo "  $0 medical"
    echo "  $0 hotel"
    echo ""
}

# Check if industry is provided
if [ $# -eq 0 ]; then
    show_usage
    exit 1
fi

INDUSTRY=$1

# Validate industry
if [[ ! " ${INDUSTRIES[@]} " =~ " ${INDUSTRY} " ]]; then
    echo "❌ Invalid industry: $INDUSTRY"
    echo ""
    show_usage
    exit 1
fi

echo "🏭 Switching OmniBase to: $INDUSTRY"
echo "=================================="

# Stop current containers
echo "🛑 Stopping current containers..."
docker-compose down

echo ""
echo "🔧 Starting with INDUSTRY=$INDUSTRY..."

# Start with new industry
INDUSTRY=$INDUSTRY docker-compose up --build -d

echo ""
echo "⏳ Waiting for services to be ready..."
sleep 10

echo ""
echo "✅ Industry switch completed!"
echo ""
echo "🌐 Services:"
echo "  - API: http://localhost:8001"
echo "  - Frontend: http://localhost:5173"  
echo "  - WebSocket: ws://localhost:8083"
echo "  - pgAdmin: http://localhost:5050"
echo ""
echo "🔍 Run ./health-check.sh to verify all services"
echo ""
echo "📋 Current configuration:"
echo "  Industry: $INDUSTRY"
echo "  Database: omnibase (shared locally)"
echo "  Environment: development"