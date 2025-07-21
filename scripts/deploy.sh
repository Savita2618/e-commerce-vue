#!/bin/bash

# ===================================
# Script de déploiement E-commerce
# Docker Compose v2 - Syntaxe moderne
# Usage: ./scripts/deploy.sh [github|gitlab]
# ===================================

set -e

# Couleurs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Aide
if [ "$#" -ne 1 ]; then
    echo -e "${RED}Usage: ./scripts/deploy.sh [github|gitlab]${NC}"
    echo ""
    echo -e "${YELLOW}Exemples:${NC}"
    echo "  ./scripts/deploy.sh github   # Utilise les images GitHub"
    echo "  ./scripts/deploy.sh gitlab   # Utilise les images GitLab"
    echo ""
    echo -e "${YELLOW}Prérequis:${NC}"
    echo "  - Docker Compose v2 installé"
    echo "  - Authentification GitLab (si gitlab choisi)"
    exit 1
fi

REGISTRY_TYPE=$1

# Vérifier Docker Compose v2
echo -e "${BLUE}Vérification Docker Compose v2...${NC}"
if ! docker compose version >/dev/null 2>&1; then
    echo -e "${RED}Erreur: Docker Compose v2 non trouvé${NC}"
    echo "Installez Docker Compose v2 ou utilisez 'docker-compose' v1"
    exit 1
fi

COMPOSE_VERSION=$(docker compose version --short 2>/dev/null || echo "unknown")
echo -e "${GREEN}Docker Compose v2 détecté: $COMPOSE_VERSION${NC}"

# Configuration selon le registry
case $REGISTRY_TYPE in
    "github")
        ENV_FILE=".env.github"
        COMPOSE_FILE="docker-compose.prod.yml"
        echo -e "${GREEN}Déploiement avec images GitHub (public)${NC}"
        ;;
    "gitlab")
        ENV_FILE=".env.gitlab"
        COMPOSE_FILE="docker-compose.prod.gitlab.yml"
        echo -e "${GREEN}Déploiement avec images GitLab (privé)${NC}"
        
        # Vérifier l'authentification GitLab
        echo -e "${YELLOW}Vérification de l'authentification GitLab...${NC}"
        if ! docker pull registry.gitlab.com/savita2618/e-commerce-docker-esgi/auth-service:latest >/dev/null 2>&1; then
            echo -e "${RED}Erreur: Authentification GitLab requise${NC}"
            echo ""
            echo -e "${YELLOW}Connectez-vous avec:${NC}"
            echo "  docker login registry.gitlab.com"
            echo "  Username: votre_username_gitlab"
            echo "  Password: votre_token_gitlab"
            echo ""
            echo -e "${YELLOW}Pour créer un token:${NC}"
            echo "  GitLab → Settings → Access Tokens → scope 'read_registry'"
            exit 1
        fi
        echo -e "${GREEN}Authentification GitLab OK${NC}"
        ;;
    *)
        echo -e "${RED}Registry non supporté: $REGISTRY_TYPE${NC}"
        echo "Utilisez 'github' ou 'gitlab'"
        exit 1
        ;;
esac

# Vérifier les fichiers requis
echo -e "${BLUE}Vérification des fichiers...${NC}"
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}Erreur: $ENV_FILE introuvable${NC}"
    exit 1
fi

if [ ! -f "$COMPOSE_FILE" ]; then
    echo -e "${RED}Erreur: $COMPOSE_FILE introuvable${NC}"
    exit 1
fi

echo -e "${GREEN}Fichiers trouvés:${NC}"
echo "  Env file: $ENV_FILE"
echo "  Compose:  $COMPOSE_FILE"

# Afficher la configuration qui sera utilisée
echo -e "${BLUE}Configuration chargée:${NC}"
source $ENV_FILE
echo "  NODE_ENV: ${NODE_ENV:-not_set}"
echo "  PROJECT:  ${COMPOSE_PROJECT_NAME:-not_set}"
echo "  TAG:      ${IMAGE_TAG:-not_set}"

# Arrêter les conteneurs existants
echo -e "${YELLOW}Arrêt des conteneurs existants...${NC}"
docker compose --env-file $ENV_FILE -f $COMPOSE_FILE down --remove-orphans 2>/dev/null || true

# Nettoyer les images non utilisées (optionnel)
read -p "Nettoyer les images Docker non utilisées? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Nettoyage des images...${NC}"
    docker image prune -f
fi

# Démarrer les services
echo -e "${YELLOW}Démarrage des services avec Docker Compose v2...${NC}"
docker compose --env-file $ENV_FILE -f $COMPOSE_FILE up -d

# Vérifier que les conteneurs démarrent
echo -e "${BLUE}Vérification des conteneurs...${NC}"
sleep 5
docker compose --env-file $ENV_FILE -f $COMPOSE_FILE ps

# Attendre le démarrage complet
echo -e "${YELLOW}Attente du démarrage complet (30s)...${NC}"
sleep 30

# Tests de santé détaillés
echo -e "${BLUE}Tests de santé des services...${NC}"

services=(
    "frontend:8080:/"
    "auth-service:3001:/health"
    "auth-service:3001:/"
    "product-service:3000:/health"
    "product-service:3000:/"
    "order-service:3002:/health"
    "order-service:3002:/"
)

for service_config in "${services[@]}"; do
    IFS=':' read -r service_name port endpoint <<< "$service_config"
    
    if curl -f -s "http://localhost:$port$endpoint" >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} $service_name ($port$endpoint)"
        break
    else
        echo -e "  ${YELLOW}?${NC} $service_name ($port$endpoint) - teste autre endpoint..."
    fi
done

# Afficher les logs récents de chaque service
echo -e "${BLUE}Logs récents des services:${NC}"
services_list=("frontend" "auth-service" "product-service" "order-service")
for service in "${services_list[@]}"; do
    echo -e "${YELLOW}--- $service ---${NC}"
    docker compose --env-file $ENV_FILE -f $COMPOSE_FILE logs --tail=3 $service 2>/dev/null || echo "Service $service non trouvé"
done

# Résumé final
echo ""
echo -e "${GREEN}=================================${NC}"
echo -e "${GREEN}    DÉPLOIEMENT TERMINÉ${NC}"
echo -e "${GREEN}=================================${NC}"
echo ""
echo -e "${YELLOW}🌐 Services accessibles:${NC}"
echo "  Frontend:         http://localhost:8080"
echo "  Auth Service:     http://localhost:3001"
echo "  Product Service:  http://localhost:3000"
echo "  Order Service:    http://localhost:3002"
if [ -f "nginx/nginx.conf" ]; then
    echo "  Nginx Proxy:      http://localhost:80"
fi
echo ""
echo -e "${YELLOW}📊 Registry utilisé:${NC} $REGISTRY_TYPE"
echo -e "${YELLOW}🏷️  Tag des images:${NC} ${IMAGE_TAG}"
echo -e "${YELLOW}🐳 Docker Compose:${NC} v2 ($COMPOSE_VERSION)"
echo ""
echo -e "${YELLOW}📝 Commandes utiles:${NC}"
echo "  Voir tous les logs:     docker compose --env-file $ENV_FILE -f $COMPOSE_FILE logs -f"
echo "  Logs d'un service:      docker compose --env-file $ENV_FILE -f $COMPOSE_FILE logs -f [service]"
echo "  Statut des services:    docker compose --env-file $ENV_FILE -f $COMPOSE_FILE ps"
echo "  Arrêter tout:           docker compose --env-file $ENV_FILE -f $COMPOSE_FILE down"
echo "  Redémarrer:             ./scripts/deploy.sh $REGISTRY_TYPE"
echo "  Forcer rebuild:         docker compose --env-file $ENV_FILE -f $COMPOSE_FILE up -d --force-recreate"
echo ""
echo -e "${GREEN}✅ Déploiement réussi !${NC}"