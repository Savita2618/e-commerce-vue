#!/bin/bash

# ===================================
# Script de déploiement Docker - E-commerce
# ===================================

set -e

# Couleurs pour les logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ENVIRONMENT=${1:-development}
COMPOSE_FILE=""
PROJECT_NAME="ecommerce"

# Fonctions utilitaires
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Fonction pour vérifier les prérequis
check_prerequisites() {
    log_info "Vérification des prérequis..."
    
    # Vérifier Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker n'est pas installé"
        exit 1
    fi
    
    # Vérifier Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose n'est pas installé"
        exit 1
    fi
    
    # Vérifier que Docker est en cours d'exécution
    if ! docker info &> /dev/null; then
        log_error "Docker n'est pas en cours d'exécution"
        exit 1
    fi
    
    log_success "Prérequis vérifiés"
}

# Fonction pour définir le fichier compose selon l'environnement
set_compose_file() {
    case $ENVIRONMENT in
        "development"|"dev")
            COMPOSE_FILE="docker-compose.yml"
            ;;
        "production"|"prod")
            COMPOSE_FILE="docker-compose.prod.yml"
            ;;
        "test")
            COMPOSE_FILE="docker-compose.test.yml"
            ;;
        *)
            log_error "Environnement non supporté: $ENVIRONMENT"
            exit 1
            ;;
    esac
    
    log_info "Utilisation du fichier: $COMPOSE_FILE"
}

# Fonction pour créer les secrets Docker (production)
create_secrets() {
    if [ "$ENVIRONMENT" = "production" ] || [ "$ENVIRONMENT" = "prod" ]; then
        log_info "Création des secrets Docker..."
        
        # Créer les secrets s'ils n'existent pas
        echo "efrei_super_pass_production_secret" | docker secret create jwt_secret - 2>/dev/null || true
        echo "admin" | docker secret create mongo_root_username - 2>/dev/null || true
        echo "production_password_12345" | docker secret create mongo_root_password - 2>/dev/null || true
        
        log_success "Secrets Docker créés"
    fi
}

# Fonction pour construire les images
build_images() {
    log_info "Construction des images Docker..."
    
    if [ "$ENVIRONMENT" = "development" ] || [ "$ENVIRONMENT" = "dev" ]; then
        # En développement, construire les images
        docker-compose -f $COMPOSE_FILE build --parallel
    else
        # En production, tirer les images depuis la registry
        docker-compose -f $COMPOSE_FILE pull
    fi
    
    log_success "Images prêtes"
}

# Fonction pour démarrer les services
start_services() {
    log_info "Démarrage des services..."
    
    # Arrêter les services existants
    docker-compose -f $COMPOSE_FILE down -v 2>/dev/null || true
    
    # Démarrer les services
    docker-compose -f $COMPOSE_FILE up -d
    
    log_success "Services démarrés"
}

# Fonction pour vérifier la santé des services
check_health() {
    log_info "Vérification de la santé des services..."
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        log_info "Tentative $attempt/$max_attempts..."
        
        # Vérifier auth-service
        if curl -sf http://localhost:3001/api/health > /dev/null 2>&1; then
            log_success "Auth service: OK"
        else
            log_warning "Auth service: En attente..."
        fi
        
        # Vérifier product-service
        if curl -sf http://localhost:3000/api/health > /dev/null 2>&1; then
            log_success "Product service: OK"
        else
            log_warning "Product service: En attente..."
        fi
        
        # Vérifier order-service
        if curl -sf http://localhost:3002/api/health > /dev/null 2>&1; then
            log_success "Order service: OK"
        else
            log_warning "Order service: En attente..."
        fi
        
        # Vérifier frontend
        if curl -sf http://localhost:8080/health > /dev/null 2>&1; then
            log_success "Frontend: OK"
            break
        else
            log_warning "Frontend: En attente..."
        fi
        
        sleep 5
        ((attempt++))
    done
    
    if [ $attempt -gt $max_attempts ]; then
        log_error "Échec de la vérification de santé après $max_attempts tentatives"
        exit 1
    fi
    
    log_success "Tous les services sont opérationnels"
}

# Fonction pour initialiser les données
initialize_data() {
    if [ "$ENVIRONMENT" = "development" ] || [ "$ENVIRONMENT" = "dev" ]; then
        log_info "Initialisation des données de test..."
        
        # Attendre que les services soient prêts
        sleep 10
        
        # Exécuter le script d'initialisation des produits
        if [ -f "./scripts/init-products.sh" ]; then
            chmod +x ./scripts/init-products.sh
            ./scripts/init-products.sh
            log_success "Données initialisées"
        else
            log_warning "Script d'initialisation non trouvé"
        fi
    fi
}

# Fonction pour afficher les informations de déploiement
show_deployment_info() {
    log_success "Déploiement terminé avec succès!"
    echo
    log_info "=== INFORMATIONS DE DÉPLOIEMENT ==="
    log_info "Environnement: $ENVIRONMENT"
    log_info "Frontend: http://localhost:8080"
    log_info "Auth Service: http://localhost:3001"
    log_info "Product Service: http://localhost:3000"
    log_info "Order Service: http://localhost:3002"
    echo
    log_info "=== COMMANDES UTILES ==="
    log_info "Voir les logs: docker-compose -f $COMPOSE_FILE logs -f"
    log_info "Arrêter: docker-compose -f $COMPOSE_FILE down"
    log_info "Status: docker-compose -f $COMPOSE_FILE ps"
    echo
}

# Fonction pour nettoyer les ressources
cleanup() {
    log_info "Nettoyage des ressources Docker..."
    
    # Supprimer les images non utilisées
    docker image prune -f
    
    # Supprimer les volumes non utilisés
    docker volume prune -f
    
    log_success "Nettoyage terminé"
}

# Fonction d'aide
show_help() {
    echo "Usage: $0 [ENVIRONNEMENT]"
    echo
    echo "Environnements disponibles:"
    echo "  development, dev    - Environnement de développement (défaut)"
    echo "  production, prod    - Environnement de production"
    echo "  test               - Environnement de test"
    echo
    echo "Exemples:"
    echo "  $0                 - Déploiement en développement"
    echo "  $0 development     - Déploiement en développement"
    echo "  $0 production      - Déploiement en production"
    echo
}

# Fonction principale
main() {
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        show_help
        exit 0
    fi
    
    log_info "Début du déploiement en environnement: $ENVIRONMENT"
    
    check_prerequisites
    set_compose_file
    create_secrets
    build_images
    start_services
    check_health
    initialize_data
    show_deployment_info
    
    if [ "$ENVIRONMENT" = "production" ] || [ "$ENVIRONMENT" = "prod" ]; then
        cleanup
    fi
}

# Gestion des signaux
trap 'log_error "Déploiement interrompu"; exit 1' INT TERM

# Exécution du script principal
main "$@"