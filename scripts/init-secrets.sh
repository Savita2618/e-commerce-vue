#!/bin/bash

# ===================================
# Script d'initialisation des secrets Docker
# ===================================

set -e

# Couleurs pour les logs
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

# Fonction pour générer un mot de passe sécurisé
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

# Fonction pour créer un secret Docker
create_secret() {
    local secret_name=$1
    local secret_value=$2
    
    if docker secret inspect $secret_name >/dev/null 2>&1; then
        log_warning "Secret '$secret_name' existe déjà"
    else
        echo "$secret_value" | docker secret create $secret_name -
        log_success "Secret '$secret_name' créé"
    fi
}

# Fonction pour créer un secret interactif
create_interactive_secret() {
    local secret_name=$1
    local description=$2
    
    echo -n "Entrez $description: "
    read -s secret_value
    echo
    
    if [ -z "$secret_value" ]; then
        log_error "Valeur vide pour $description"
        return 1
    fi
    
    create_secret $secret_name "$secret_value"
}

# Fonction principale
main() {
    log_info "Initialisation des secrets Docker pour la production"
    
    # Vérifier que Docker Swarm est initialisé
    if ! docker node ls >/dev/null 2>&1; then
        log_info "Initialisation de Docker Swarm..."
        docker swarm init --advertise-addr 127.0.0.1
        log_success "Docker Swarm initialisé"
    fi
    
    echo
    log_info "Configuration des secrets de production..."
    echo
    
    # Secret JWT
    if [ -z "$JWT_SECRET" ]; then
        log_info "Génération automatique du JWT_SECRET..."
        JWT_SECRET=$(generate_password)
        log_success "JWT_SECRET généré automatiquement"
    fi
    create_secret "jwt_secret" "$JWT_SECRET"
    
    # Utilisateur root MongoDB
    if [ -z "$MONGO_ROOT_USERNAME" ]; then
        echo -n "Nom d'utilisateur root MongoDB [admin]: "
        read MONGO_ROOT_USERNAME
        MONGO_ROOT_USERNAME=${MONGO_ROOT_USERNAME:-admin}
    fi
    create_secret "mongo_root_username" "$MONGO_ROOT_USERNAME"
    
    # Mot de passe root MongoDB
    if [ -z "$MONGO_ROOT_PASSWORD" ]; then
        log_info "Génération automatique du mot de passe MongoDB..."
        MONGO_ROOT_PASSWORD=$(generate_password)
        log_success "Mot de passe MongoDB généré automatiquement"
    fi
    create_secret "mongo_root_password" "$MONGO_ROOT_PASSWORD"
    
    # Secrets SSL (optionnels)
    echo
    log_info "Configuration SSL (optionnel)..."
    echo -n "Voulez-vous configurer SSL ? [y/N]: "
    read configure_ssl
    
    if [ "$configure_ssl" = "y" ] || [ "$configure_ssl" = "Y" ]; then
        if [ -f "ssl/server.crt" ] && [ -f "ssl/server.key" ]; then
            create_secret "ssl_cert" "$(cat ssl/server.crt)"
            create_secret "ssl_key" "$(cat ssl/server.key)"
            log_success "Certificats SSL configurés"
        else
            log_warning "Certificats SSL non trouvés dans ./ssl/"
            log_info "Pour générer des certificats auto-signés:"
            log_info "mkdir -p ssl"
            log_info "openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ssl/server.key -out ssl/server.crt"
        fi
    fi
    
    echo
    log_success "Configuration des secrets terminée"
    echo
    log_info "Secrets créés:"
    docker secret ls --format "table {{.Name}}\t{{.CreatedAt}}"
    
    echo
    log_info "Variables d'environnement pour la production:"
    echo "export MONGO_ROOT_USERNAME='$MONGO_ROOT_USERNAME'"
    echo "export JWT_SECRET='$JWT_SECRET'"
    echo
    log_warning "Sauvegardez ces informations dans un endroit sûr!"
}

# Gestion des erreurs
trap 'log_error "Erreur lors de la création des secrets"; exit 1' ERR

# Exécution
main "$@"