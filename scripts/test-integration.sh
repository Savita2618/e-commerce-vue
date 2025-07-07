#!/bin/bash

# ===================================
# Script de tests d'intégration
# ===================================

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
BASE_URL="http://localhost"
AUTH_PORT="3001"
PRODUCT_PORT="3000"
ORDER_PORT="3002"
FRONTEND_PORT="8080"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Fonction pour tester un endpoint
test_endpoint() {
    local name=$1
    local url=$2
    local expected_status=${3:-200}
    
    log_info "Test: $name"
    
    response=$(curl -s -w "%{http_code}" -o /tmp/response "$url")
    
    if [ "$response" = "$expected_status" ]; then
        log_success "$name: OK ($response)"
        return 0
    else
        log_error "$name: FAILED ($response)"
        return 1
    fi
}

# Fonction pour tester un endpoint avec JSON
test_json_endpoint() {
    local name=$1
    local url=$2
    local method=${3:-GET}
    local data=${4:-""}
    local headers=${5:-"Content-Type: application/json"}
    
    log_info "Test: $name"
    
    if [ "$method" = "POST" ] && [ -n "$data" ]; then
        response=$(curl -s -w "%{http_code}" -X POST -H "$headers" -d "$data" -o /tmp/response "$url")
    else
        response=$(curl -s -w "%{http_code}" -o /tmp/response "$url")
    fi
    
    if [ "$response" = "200" ] || [ "$response" = "201" ]; then
        log_success "$name: OK ($response)"
        return 0
    else
        log_error "$name: FAILED ($response)"
        cat /tmp/response
        return 1
    fi
}

# Attendre que les services soient disponibles
wait_for_services() {
    log_info "Attente des services..."
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -sf "$BASE_URL:$FRONTEND_PORT/health" > /dev/null 2>&1; then
            break
        fi
        
        log_info "Tentative $attempt/$max_attempts..."
        sleep 5
        ((attempt++))
    done
    
    if [ $attempt -gt $max_attempts ]; then
        log_error "Les services ne sont pas disponibles après $max_attempts tentatives"
        exit 1
    fi
    
    log_success "Services disponibles"
}

# Tests de santé des services
test_health_checks() {
    log_info "=== Tests de santé des services ==="
    
    test_endpoint "Auth Service Health" "$BASE_URL:$AUTH_PORT/api/health"
    test_endpoint "Product Service Health" "$BASE_URL:$PRODUCT_PORT/api/health"
    test_endpoint "Order Service Health" "$BASE_URL:$ORDER_PORT/api/health"
    test_endpoint "Frontend Health" "$BASE_URL:$FRONTEND_PORT/health"
}

# Tests des APIs
test_apis() {
    log_info "=== Tests des APIs ==="
    
    # Test Auth API
    log_info "Tests Auth Service..."
    
    # Inscription
    USER_DATA='{"email":"test@example.com","password":"password123"}'
    if test_json_endpoint "Auth - Inscription" "$BASE_URL:$AUTH_PORT/api/auth/register" "POST" "$USER_DATA"; then
        TOKEN=$(cat /tmp/response | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
        log_success "Token récupéré: ${TOKEN:0:20}..."
    fi
    
    # Connexion
    test_json_endpoint "Auth - Connexion" "$BASE_URL:$AUTH_PORT/api/auth/login" "POST" "$USER_DATA"
    
    # Profil (si token disponible)
    if [ -n "$TOKEN" ]; then
        curl -s -H "Authorization: Bearer $TOKEN" "$BASE_URL:$AUTH_PORT/api/auth/profile" > /tmp/response
        if [ $? -eq 0 ]; then
            log_success "Auth - Profil: OK"
        else
            log_error "Auth - Profil: FAILED"
        fi
    fi
    
    # Test Product API
    log_info "Tests Product Service..."
    test_endpoint "Product - Liste des produits" "$BASE_URL:$PRODUCT_PORT/api/products"
    
    # Test Order API (nécessite authentification)
    if [ -n "$TOKEN" ]; then
        log_info "Tests Order Service..."
        curl -s -H "Authorization: Bearer $TOKEN" "$BASE_URL:$ORDER_PORT/api/orders" > /tmp/response
        if [ $? -eq 0 ]; then
            log_success "Order - Liste des commandes: OK"
        else
            log_error "Order - Liste des commandes: FAILED"
        fi
    fi
}

# Test du frontend
test_frontend() {
    log_info "=== Tests Frontend ==="
    
    test_endpoint "Frontend - Page d'accueil" "$BASE_URL:$FRONTEND_PORT/"
    test_endpoint "Frontend - Assets CSS" "$BASE_URL:$FRONTEND_PORT/assets/index.css" 404 || true
    test_endpoint "Frontend - Fichier inexistant" "$BASE_URL:$FRONTEND_PORT/nonexistent" 404
}

# Tests de charge basiques
test_load() {
    log_info "=== Tests de charge basiques ==="
    
    log_info "Test de charge sur la page d'accueil..."
    for i in {1..10}; do
        curl -s "$BASE_URL:$FRONTEND_PORT/" > /dev/null &
    done
    wait
    log_success "Test de charge terminé"
}

# Rapport de tests
generate_report() {
    log_info "=== Rapport de tests ==="
    
    echo "Date: $(date)"
    echo "Services testés:"
    echo "  - Auth Service: $BASE_URL:$AUTH_PORT"
    echo "  - Product Service: $BASE_URL:$PRODUCT_PORT"
    echo "  - Order Service: $BASE_URL:$ORDER_PORT"
    echo "  - Frontend: $BASE_URL:$FRONTEND_PORT"
    echo
    
    # Vérification des conteneurs
    log_info "État des conteneurs:"
    docker-compose ps
    
    # Utilisation des ressources
    log_info "Utilisation des ressources:"
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
}

# Fonction principale
main() {
    log_info "Début des tests d'intégration"
    
    wait_for_services
    test_health_checks
    test_apis
    test_frontend
    test_load
    generate_report
    
    log_success "Tests d'intégration terminés avec succès!"
}

# Nettoyage en cas d'erreur
cleanup() {
    rm -f /tmp/response
}

trap cleanup EXIT

# Exécution
main "$@"