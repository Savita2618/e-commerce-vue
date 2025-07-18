#!/bin/bash

# ===================================
# Script d'initialisation simplifié
# ===================================

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Générer un mot de passe sécurisé
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

# Fonction principale
main() {
    log_info "🚀 Initialisation de l'environnement de production"
    echo
    
    # Générer les secrets
    if [ -z "$JWT_SECRET" ]; then
        JWT_SECRET=$(generate_password)
        log_success "JWT_SECRET généré: ${JWT_SECRET:0:8}..."
    fi
    
    if [ -z "$MONGO_ROOT_USERNAME" ]; then
        echo -n "Nom d'utilisateur MongoDB [admin]: "
        read MONGO_ROOT_USERNAME
        MONGO_ROOT_USERNAME=${MONGO_ROOT_USERNAME:-admin}
    fi
    
    if [ -z "$MONGO_ROOT_PASSWORD" ]; then
        MONGO_ROOT_PASSWORD=$(generate_password)
        log_success "Mot de passe MongoDB généré: ${MONGO_ROOT_PASSWORD:0:8}..."
    fi
    
    # Créer le fichier .env.prod
    log_info "🔧 Création du fichier .env.prod..."
    
    rm -f .env.prod
    
    echo "# Variables d'environnement - Production" > .env.prod
    echo "NODE_ENV=production" >> .env.prod
    echo "COMPOSE_PROJECT_NAME=ecommerce-prod" >> .env.prod
    echo "" >> .env.prod
    echo "# Docker Registry & Images" >> .env.prod
    echo "REGISTRY=ghcr.io" >> .env.prod
    echo "GITHUB_REPOSITORY=savita2618/e-commerce-vue" >> .env.prod
    echo "IMAGE_TAG=latest" >> .env.prod
    echo "" >> .env.prod
    echo "# JWT Configuration" >> .env.prod
    echo "JWT_SECRET=$JWT_SECRET" >> .env.prod
    echo "" >> .env.prod
    echo "# MongoDB Configuration" >> .env.prod
    echo "MONGO_ROOT_USERNAME=$MONGO_ROOT_USERNAME" >> .env.prod
    echo "MONGO_ROOT_PASSWORD=$MONGO_ROOT_PASSWORD" >> .env.prod
    echo "" >> .env.prod
    echo "# URIs MongoDB pour production" >> .env.prod
    echo "MONGODB_URI_AUTH=mongodb://$MONGO_ROOT_USERNAME:$MONGO_ROOT_PASSWORD@mongodb-auth:27017/authdb?authSource=admin" >> .env.prod
    echo "MONGODB_URI_PRODUCTS=mongodb://$MONGO_ROOT_USERNAME:$MONGO_ROOT_PASSWORD@mongodb-products:27017/productsdb?authSource=admin" >> .env.prod
    echo "MONGODB_URI_ORDERS=mongodb://$MONGO_ROOT_USERNAME:$MONGO_ROOT_PASSWORD@mongodb-orders:27017/ordersdb?authSource=admin" >> .env.prod
    echo "" >> .env.prod
    echo "# Services URLs" >> .env.prod
    echo "AUTH_SERVICE_URL=http://auth-service:3001" >> .env.prod
    echo "PRODUCT_SERVICE_URL=http://product-service:3000" >> .env.prod
    echo "ORDER_SERVICE_URL=http://order-service:3002" >> .env.prod
    echo "" >> .env.prod
    echo "# Frontend Configuration" >> .env.prod
    echo "VITE_AUTH_SERVICE_URL=http://localhost:3001" >> .env.prod
    echo "VITE_PRODUCT_SERVICE_URL=http://localhost:3000" >> .env.prod
    echo "VITE_ORDER_SERVICE_URL=http://localhost:3002" >> .env.prod
    echo "" >> .env.prod
    echo "# Ports" >> .env.prod
    echo "AUTH_SERVICE_PORT=3001" >> .env.prod
    echo "PRODUCT_SERVICE_PORT=3000" >> .env.prod
    echo "ORDER_SERVICE_PORT=3002" >> .env.prod
    echo "FRONTEND_PORT=8080" >> .env.prod
    echo "" >> .env.prod
    echo "# Debug" >> .env.prod
    echo "DEBUG=" >> .env.prod
    echo "LOG_LEVEL=info" >> .env.prod
    echo "" >> .env.prod
    echo "# Sécurité" >> .env.prod
    echo "SECURE_COOKIES=true" >> .env.prod
    echo "CORS_ORIGIN=http://localhost:8080" >> .env.prod
    echo "" >> .env.prod
    echo "# Monitoring" >> .env.prod
    echo "HEALTH_CHECK_TIMEOUT=30s" >> .env.prod
    echo "HEALTH_CHECK_INTERVAL=30s" >> .env.prod
    echo "HEALTH_CHECK_RETRIES=3" >> .env.prod
    
    log_success "✅ Fichier .env.prod créé avec succès"
    
    # Afficher les informations finales
    log_success "🎉 Initialisation terminée!"
    echo
    log_info "=== PROCHAINES ÉTAPES ==="
    log_info "1. Vérifiez le fichier .env.prod généré"
    log_info "2. Lancez le déploiement avec:"
    log_info "   ./scripts/deploy-registry.sh"
    log_info "   OU"
    log_info "   ./scripts/deploy-docker.sh production"
    echo
    log_info "=== INFORMATIONS IMPORTANTES ==="
    log_info "🔐 JWT Secret: ${JWT_SECRET:0:8}..."
    log_info "🗄️  MongoDB User: $MONGO_ROOT_USERNAME"
    log_info "🔑 MongoDB Password: ${MONGO_ROOT_PASSWORD:0:8}..."
    echo
    log_warning "⚠️  SAUVEGARDEZ CES INFORMATIONS!"
    log_warning "⚠️  Le fichier .env.prod contient des informations sensibles"
    echo
}

# Exécution
main "$@"