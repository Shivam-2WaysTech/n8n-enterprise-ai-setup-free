#!/bin/bash

# ============================================================================
# n8n Health Check Script
# ============================================================================
# This script performs comprehensive health checks on all n8n services

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Function to check if service is running
check_service() {
    local service_name=$1
    local container_name=$2
    
    if docker-compose ps | grep -q "$container_name.*Up"; then
        print_success "$service_name is running"
        return 0
    else
        print_error "$service_name is not running"
        return 1
    fi
}

# Function to check service health
check_health() {
    local service_name=$1
    local health_command=$2
    
    if eval "$health_command" >/dev/null 2>&1; then
        print_success "$service_name health check passed"
        return 0
    else
        print_error "$service_name health check failed"
        return 1
    fi
}

# Function to check port accessibility
check_port() {
    local service_name=$1
    local port=$2
    
    if nc -z localhost "$port" 2>/dev/null; then
        print_success "$service_name port $port is accessible"
        return 0
    else
        print_error "$service_name port $port is not accessible"
        return 1
    fi
}

echo "============================================================================"
echo "n8n Health Check Report"
echo "============================================================================"
echo "Timestamp: $(date)"
echo

# Check if docker-compose.yml exists
if [ ! -f "docker-compose.yaml" ]; then
    print_error "docker-compose.yaml not found in current directory"
    exit 1
fi

# Check if .env file exists
if [ ! -f ".env" ]; then
    print_error ".env file not found. Run ./scripts/setup.sh first"
    exit 1
fi

print_status "Checking Docker Compose services..."
echo

# Check service status
SERVICES_OK=0
TOTAL_SERVICES=0

# PostgreSQL
TOTAL_SERVICES=$((TOTAL_SERVICES + 1))
if check_service "PostgreSQL" "postgres"; then
    SERVICES_OK=$((SERVICES_OK + 1))
fi

# Redis
TOTAL_SERVICES=$((TOTAL_SERVICES + 1))
if check_service "Redis" "redis"; then
    SERVICES_OK=$((SERVICES_OK + 1))
fi

# n8n Main
TOTAL_SERVICES=$((TOTAL_SERVICES + 1))
if check_service "n8n Main" "n8n"; then
    SERVICES_OK=$((SERVICES_OK + 1))
fi

# n8n Worker
TOTAL_SERVICES=$((TOTAL_SERVICES + 1))
if check_service "n8n Worker" "n8n-worker"; then
    SERVICES_OK=$((SERVICES_OK + 1))
fi

# Nginx
TOTAL_SERVICES=$((TOTAL_SERVICES + 1))
if check_service "Nginx Load Balancer" "nginx"; then
    SERVICES_OK=$((SERVICES_OK + 1))
fi

echo
print_status "Checking service health..."
echo

# Health checks
HEALTH_OK=0
TOTAL_HEALTH=0

# PostgreSQL health
TOTAL_HEALTH=$((TOTAL_HEALTH + 1))
if check_health "PostgreSQL" "docker-compose exec -T postgres pg_isready -U n8n -d n8n"; then
    HEALTH_OK=$((HEALTH_OK + 1))
fi

# Redis health
TOTAL_HEALTH=$((TOTAL_HEALTH + 1))
REDIS_PASSWORD=$(grep "^REDIS_PASSWORD=" .env | cut -d'=' -f2)
if check_health "Redis" "docker-compose exec -T redis redis-cli -a '$REDIS_PASSWORD' ping"; then
    HEALTH_OK=$((HEALTH_OK + 1))
fi

# n8n health
TOTAL_HEALTH=$((TOTAL_HEALTH + 1))
if check_health "n8n Main" "curl -f -s -o /dev/null http://localhost:5678/healthz"; then
    HEALTH_OK=$((HEALTH_OK + 1))
fi

echo
print_status "Checking port accessibility..."
echo

# Port checks
PORTS_OK=0
TOTAL_PORTS=0

# Check main ports
TOTAL_PORTS=$((TOTAL_PORTS + 1))
if check_port "n8n Web Interface" "5678"; then
    PORTS_OK=$((PORTS_OK + 1))
fi

TOTAL_PORTS=$((TOTAL_PORTS + 1))
if check_port "PostgreSQL" "5432"; then
    PORTS_OK=$((PORTS_OK + 1))
fi

TOTAL_PORTS=$((TOTAL_PORTS + 1))
if check_port "Redis" "6379"; then
    PORTS_OK=$((PORTS_OK + 1))
fi

TOTAL_PORTS=$((TOTAL_PORTS + 1))
if check_port "Nginx Load Balancer" "80"; then
    PORTS_OK=$((PORTS_OK + 1))
fi

echo
print_status "Checking resource usage..."
echo

# Resource usage
if command -v docker >/dev/null 2>&1; then
    echo "Container Resource Usage:"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" | head -6
    echo
fi

# Disk usage
echo "Volume Usage:"
docker system df -v | grep -E "(VOLUME NAME|n8n_data|postgres_data|redis_data)" || echo "No volume information available"
echo

# Summary
echo "============================================================================"
echo "Health Check Summary"
echo "============================================================================"

if [ $SERVICES_OK -eq $TOTAL_SERVICES ]; then
    print_success "All services are running ($SERVICES_OK/$TOTAL_SERVICES)"
else
    print_error "Some services are not running ($SERVICES_OK/$TOTAL_SERVICES)"
fi

if [ $HEALTH_OK -eq $TOTAL_HEALTH ]; then
    print_success "All health checks passed ($HEALTH_OK/$TOTAL_HEALTH)"
else
    print_error "Some health checks failed ($HEALTH_OK/$TOTAL_HEALTH)"
fi

if [ $PORTS_OK -eq $TOTAL_PORTS ]; then
    print_success "All ports are accessible ($PORTS_OK/$TOTAL_PORTS)"
else
    print_error "Some ports are not accessible ($PORTS_OK/$TOTAL_PORTS)"
fi

echo
if [ $SERVICES_OK -eq $TOTAL_SERVICES ] && [ $HEALTH_OK -eq $TOTAL_HEALTH ] && [ $PORTS_OK -eq $TOTAL_PORTS ]; then
    print_success "n8n environment is healthy and ready to use!"
    echo
    echo "Access URLs:"
    echo "- n8n Interface: http://localhost:5678"
    echo "- Load Balancer: http://localhost:80"
    echo
    echo "Database Connections:"
    echo "- PostgreSQL: localhost:5432"
    echo "- Redis: localhost:6379"
else
    print_error "n8n environment has issues that need attention"
    echo
    echo "Troubleshooting steps:"
    echo "1. Check service logs: docker-compose logs [service-name]"
    echo "2. Restart services: docker-compose restart"
    echo "3. Check .env configuration"
    echo "4. Ensure ports are not in use by other applications"
fi

echo
print_status "For detailed troubleshooting, see SETUP.md"
