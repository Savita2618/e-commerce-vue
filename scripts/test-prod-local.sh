#!/bin/bash

# ===================================
# Script de test docker-compose.prod.yml en local
# ===================================

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Variables
PROJECT_NAME="ecommerce"
COMPOSE_FILE="docker-compose.prod.yml"

# Fonction de nettoyage
cleanup() {
    log_info "🧹 Nettoyage de l'environnement existant..."
    
    # Supprimer la stack si elle existe
    docker stack rm $PROJECT_NAME 2>/dev/null || true
    
    # Attendre que tout soit supprimé
    sleep 10
    
    # Supprimer les réseaux/volumes orphelins
    docker system prune -f --volumes 2>/dev/null || true
    
    log_success "Nettoyage terminé"
}

# Fonction pour vérifier les prérequis
check_prerequisites() {
    log_info "🔍 Vérification des prérequis..."
    
    # Vérifier Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker non installé"
        exit 1
    fi
    
    # Vérifier le fichier docker-compose.prod.yml
    if [ ! -f "$COMPOSE_FILE" ]; then
        log_error "Fichier $COMPOSE_FILE non trouvé"
        exit 1
    fi
    
    # Vérifier Docker Swarm
    if ! docker node ls &> /dev/null; then
        log_info "Initialisation de Docker Swarm..."
        docker swarm init --advertise-addr 127.0.0.1
        log_success "Docker Swarm initialisé"
    fi
    
    log_success "Prérequis OK"
}

# Fonction pour créer les secrets
create_secrets() {
    log_info "🔐 Création des secrets Docker..."
    
    # JWT Secret
    echo "efrei_super_pass_production_secret" | docker secret create jwt_secret - 2>/dev/null || log_warning "Secret jwt_secret existe déjà"
    
    # MongoDB credentials
    echo "admin" | docker secret create mongo_root_username - 2>/dev/null || log_warning "Secret mongo_root_username existe déjà"
    echo "production_password_12345" | docker secret create mongo_root_password - 2>/dev/null || log_warning "Secret mongo_root_password existe déjà"
    
    log_success "Secrets configurés"
}

# Fonction pour construire les images localement
build_images() {
    log_info "🏗️ Construction des images localement..."
    
    # Variables d'environnement nécessaires
    export GITHUB_REPOSITORY="Savita2618/e-commerce-vue"
    export IMAGE_TAG="latest"
    
    # Construire les images avec docker-compose
    # Remplacer temporairement les images du registry par des builds locaux
    sed 's|image: ghcr.io/${GITHUB_REPOSITORY}/\([^:]*\):${IMAGE_TAG:-latest}|build: ./services/\1|g' $COMPOSE_FILE > docker-compose.prod.local.yml
    
    # Corriger le frontend
    sed -i 's|build: ./services/frontend|build: ./frontend|g' docker-compose.prod.local.yml
    
    # Construire les images
    docker-compose -f docker-compose.prod.local.yml build --parallel
    
    # Tagger les images avec les noms attendus
    docker tag $(basename $(pwd))_auth-service ghcr.io/Savita2618/e-commerce-vue/auth-service:latest
    docker tag $(basename $(pwd))_product-service ghcr.io/Savita2618/e-commerce-vue/product-service:latest
    docker tag $(basename $(pwd))_order-service ghcr.io/Savita2618/e-commerce-vue/order-service:latest
    docker tag $(basename $(pwd))_frontend ghcr.io/Savita2618/e-commerce-vue/frontend:latest
    
    log_success "Images construites et taguées"
}

# Fonction pour déployer la stack
deploy_stack() {
    log_info "🚀 Déploiement de la stack en production..."
    
    # Variables d'environnement
    export GITHUB_REPOSITORY="Savita2618/e-commerce-vue"
    export IMAGE_TAG="latest"
    
    # Déployer la stack
    docker stack deploy -c $COMPOSE_FILE $PROJECT_NAME
    
    log_success "Stack déployée"
}

# Fonction pour attendre que les services soient prêts
wait_for_services() {
    log_info "⏳ Attente du démarrage des services..."
    
    local max_attempts=60
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        log_info "Tentative $attempt/$max_attempts..."
        
        # Vérifier le nombre de services en cours d'exécution
        local running_services=$(docker stack ps $PROJECT_NAME --filter "desired-state=running" --format "{{.CurrentState}}" | grep -c "Running" || echo "0")
        local total_services=$(docker stack ps $PROJECT_NAME --format "{{.Name}}" | wc -l)
        
        log_info "Services en cours: $running_services/$total_services"
        
        if [ "$running_services" -gt 0 ]; then
            # Tester les endpoints
            local services_ready=0
            
            # Test frontend
            if curl -sf http://localhost:8080 >/dev/null 2>&1; then
                log_success "✅ Frontend: OK"
                ((services_ready++))
            fi
            
            # Test auth service
            if curl -sf http://localhost:3001/api/health >/dev/null 2>&1; then
                log_success "✅ Auth Service: OK"
                ((services_ready++))
            fi
            
            # Test product service
            if curl -sf http://localhost:3000/api/health >/dev/null 2>&1; then
                log_success "✅ Product Service: OK"
                ((services_ready++))
            fi
            
            # Test order service
            if curl -sf http://localhost:3002/api/health >/dev/null 2>&1; then
                log_success "✅ Order Service: OK"
                ((services_ready++))
            fi
            
            if [ $services_ready -eq 4 ]; then
                log_success "🎉 Tous les services sont opérationnels!"
                return 0
            fi
        fi
        
        sleep 5
        ((attempt++))
    done
    
    log_error "❌ Timeout - Les services ne sont pas tous démarrés"
    return 1
}

# Fonction pour afficher les informations
show_info() {
    log_success "🎯 Test de production terminé!"
    echo
    log_info "=== SERVICES DISPONIBLES ==="
    log_info "Frontend: http://localhost:8080"
    log_info "Auth Service: http://localhost:3001"
    log_info "Product Service: http://localhost:3000"
    log_info "Order Service: http://localhost:3002"
    echo
    log_info "=== COMMANDES UTILES ==="
    log_info "Voir les services: docker stack ps $PROJECT_NAME"
    log_info "Voir les logs: docker service logs -f ${PROJECT_NAME}_frontend"
    log_info "Arrêter: docker stack rm $PROJECT_NAME"
    echo
}

# Fonction pour afficher les logs en cas d'erreur
show_debug_info() {
    log_error "🔍 Informations de debug:"
    echo
    log_info "=== STATUT DES SERVICES ==="
    docker stack ps $PROJECT_NAME
    echo
    log_info "=== SECRETS DOCKER ==="
    docker secret ls
    echo
    log_info "=== RÉSEAUX ==="
    docker network ls | grep $PROJECT_NAME
    echo
}

# Fonction principale
main() {
    log_info "🧪 Test de docker-compose.prod.yml en local"
    echo
    
    # Nettoyage initial
    cleanup
    
    # Vérifications
    check_prerequisites
    
    # Configuration
    create_secrets
    
    # Construction des images
    build_images
    
    # Déploiement
    deploy_stack
    
    # Attendre que tout soit prêt
    if wait_for_services; then
        show_info
        
        log_info "💡 Pour arrêter: docker stack rm $PROJECT_NAME"
    else
        log_error "Le test a échoué"
        show_debug_info
        exit 1
    fi
}

# Gestion d'interruption
trap 'log_warning "Test interrompu"; cleanup; exit 1' INT TERM

# Exécution
main "$@"