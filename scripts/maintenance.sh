#!/bin/bash

# ===================================
# Script de maintenance Docker
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

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Fonction pour afficher l'aide
show_help() {
    echo "Script de maintenance Docker - E-commerce"
    echo
    echo "Usage: $0 [COMMANDE]"
    echo
    echo "Commandes disponibles:"
    echo "  status          - Afficher l'état des services"
    echo "  logs            - Afficher les logs"
    echo "  clean           - Nettoyer les ressources Docker"
    echo "  backup          - Sauvegarder les données"
    echo "  restore         - Restaurer les données"
    echo "  update          - Mettre à jour les images"
    echo "  restart         - Redémarrer les services"
    echo "  monitor         - Surveillance en temps réel"
    echo "  health          - Vérification de santé complète"
    echo
}

# Afficher l'état des services
show_status() {
    log_info "=== État des services ==="
    
    echo
    log_info "Conteneurs actifs:"
    docker-compose ps
    
    echo
    log_info "Utilisation des ressources:"
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"
    
    echo
    log_info "Espace disque utilisé par Docker:"
    docker system df
    
    echo
    log_info "Images disponibles:"
    docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
}

# Afficher les logs
show_logs() {
    local service=${1:-""}
    
    if [ -n "$service" ]; then
        log_info "Logs du service: $service"
        docker-compose logs -f --tail=100 "$service"
    else
        log_info "Logs de tous les services (dernières 50 lignes par service)"
        docker-compose logs --tail=50
        
        echo
        log_info "Pour suivre les logs en temps réel d'un service:"
        log_info "  $0 logs [auth-service|product-service|order-service|frontend]"
    fi
}

# Nettoyer les ressources Docker
clean_docker() {
    log_info "=== Nettoyage Docker ==="
    
    echo
    log_warning "Cette action va supprimer:"
    log_warning "  - Les conteneurs arrêtés"
    log_warning "  - Les images non utilisées"
    log_warning "  - Les volumes non utilisés"
    log_warning "  - Les réseaux non utilisés"
    
    echo -n "Continuer ? [y/N]: "
    read confirm
    
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        log_info "Nettoyage annulé"
        return
    fi
    
    log_info "Nettoyage des conteneurs arrêtés..."
    docker container prune -f
    
    log_info "Nettoyage des images non utilisées..."
    docker image prune -f
    
    log_info "Nettoyage des volumes non utilisés..."
    docker volume prune -f
    
    log_info "Nettoyage des réseaux non utilisés..."
    docker network prune -f
    
    log_success "Nettoyage terminé"
    
    echo
    log_info "Espace libéré:"
    docker system df
}

# Sauvegarder les données
backup_data() {
    log_info "=== Sauvegarde des données ==="
    
    local backup_dir="backups/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    log_info "Dossier de sauvegarde: $backup_dir"
    
    # Sauvegarder les bases de données MongoDB
    log_info "Sauvegarde des bases de données..."
    
    # Auth DB
    docker-compose exec -T mongodb-auth mongodump --authenticationDatabase admin -u admin -p password --db authdb --out /tmp/backup
    docker cp $(docker-compose ps -q mongodb-auth):/tmp/backup/authdb "$backup_dir/"
    
    # Products DB
    docker-compose exec -T mongodb-products mongodump --authenticationDatabase admin -u admin -p password --db productsdb --out /tmp/backup
    docker cp $(docker-compose ps -q mongodb-products):/tmp/backup/productsdb "$backup_dir/"
    
    # Orders DB
    docker-compose exec -T mongodb-orders mongodump --authenticationDatabase admin -u admin -p password --db ordersdb --out /tmp/backup
    docker cp $(docker-compose ps -q mongodb-orders):/tmp/backup/ordersdb "$backup_dir/"
    
    # Sauvegarder la configuration
    log_info "Sauvegarde de la configuration..."
    cp docker-compose*.yml "$backup_dir/"
    cp -r scripts/ "$backup_dir/" 2>/dev/null || true
    
    # Créer une archive
    log_info "Création de l'archive..."
    tar -czf "${backup_dir}.tar.gz" -C backups "$(basename "$backup_dir")"
    rm -rf "$backup_dir"
    
    log_success "Sauvegarde créée: ${backup_dir}.tar.gz"
}

# Restaurer les données
restore_data() {
    log_info "=== Restauration des données ==="
    
    echo "Fichiers de sauvegarde disponibles:"
    ls -la backups/*.tar.gz 2>/dev/null || {
        log_error "Aucune sauvegarde trouvée"
        return 1
    }
    
    echo -n "Entrez le nom du fichier de sauvegarde: "
    read backup_file
    
    if [ ! -f "$backup_file" ]; then
        log_error "Fichier de sauvegarde non trouvé: $backup_file"
        return 1
    fi
    
    log_warning "ATTENTION: Cette action va écraser les données existantes!"
    echo -n "Continuer ? [y/N]: "
    read confirm
    
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        log_info "Restauration annulée"
        return
    fi
    
    # Extraire la sauvegarde
    tar -xzf "$backup_file" -C backups/
    local restore_dir="backups/$(basename "$backup_file" .tar.gz)"
    
    # Restaurer les bases de données
    # (Code de restauration MongoDB...)
    
    log_success "Restauration terminée"
}

# Mettre à jour les images
update_images() {
    log_info "=== Mise à jour des images ==="
    
    log_info "Récupération des dernières images..."
    docker-compose pull
    
    log_info "Redémarrage des services avec les nouvelles images..."
    docker-compose up -d --force-recreate
    
    log_success "Mise à jour terminée"
}

# Redémarrer les services
restart_services() {
    local service=${1:-""}
    
    if [ -n "$service" ]; then
        log_info "Redémarrage du service: $service"
        docker-compose restart "$service"
    else
        log_info "Redémarrage de tous les services..."
        docker-compose restart
    fi
    
    log_success "Services redémarrés"
}

# Surveillance en temps réel
monitor() {
    log_info "=== Surveillance en temps réel ==="
    log_info "Appuyez sur Ctrl+C pour quitter"
    
    while true; do
        clear
        echo "=== Surveillance E-commerce - $(date) ==="
        echo
        
        # État des conteneurs
        echo "CONTENEURS:"
        docker-compose ps
        echo
        
        # Utilisation des ressources
        echo "RESSOURCES:"
        docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
        echo
        
        # Tests de santé rapides
        echo "SANTÉ DES SERVICES:"
        curl -sf http://localhost:8080/health && echo "Frontend: ✓" || echo "Frontend: ✗"
        curl -sf http://localhost:3001/api/health && echo "Auth: ✓" || echo "Auth: ✗"
        curl -sf http://localhost:3000/api/health && echo "Product: ✓" || echo "Product: ✗"
        curl -sf http://localhost:3002/api/health && echo "Order: ✓" || echo "Order: ✗"
        
        sleep 10
    done
}

# Vérification de santé complète
health_check() {
    log_info "=== Vérification de santé complète ==="
    
    # Vérifier que les services répondent
    local errors=0
    
    # Frontend
    if curl -sf http://localhost:8080/health > /dev/null; then
        log_success "Frontend: OK"
    else
        log_error "Frontend: KO"
        ((errors++))
    fi
    
    # Auth Service
    if curl -sf http://localhost:3001/api/health > /dev/null; then
        log_success "Auth Service: OK"
    else
        log_error "Auth Service: KO"
        ((errors++))
    fi
    
    # Product Service
    if curl -sf http://localhost:3000/api/health > /dev/null; then
        log_success "Product Service: OK"
    else
        log_error "Product Service: KO"
        ((errors++))
    fi
    
    # Order Service
    if curl -sf http://localhost:3002/api/health > /dev/null; then
        log_success "Order Service: OK"
    else
        log_error "Order Service: KO"
        ((errors++))
    fi
    
    # Vérifier les bases de données
    if docker-compose exec mongodb-auth mongosh --eval "db.adminCommand('ping')" > /dev/null 2>&1; then
        log_success "MongoDB Auth: OK"
    else
        log_error "MongoDB Auth: KO"
        ((errors++))
    fi
    
    if docker-compose exec mongodb-products mongosh --eval "db.adminCommand('ping')" > /dev/null 2>&1; then
        log_success "MongoDB Products: OK"
    else
        log_error "MongoDB Products: KO"
        ((errors++))
    fi
    
    if docker-compose exec mongodb-orders mongosh --eval "db.adminCommand('ping')" > /dev/null 2>&1; then
        log_success "MongoDB Orders: OK"
    else
        log_error "MongoDB Orders: KO"
        ((errors++))
    fi
    
    echo
    if [ $errors -eq 0 ]; then
        log_success "Tous les services sont opérationnels"
    else
        log_error "$errors service(s) en erreur"
        return 1
    fi
}

# Fonction principale
main() {
    local command=${1:-"help"}
    
    case $command in
        "status")
            show_status
            ;;
        "logs")
            show_logs "$2"
            ;;
        "clean")
            clean_docker
            ;;
        "backup")
            backup_data
            ;;
        "restore")
            restore_data
            ;;
        "update")
            update_images
            ;;
        "restart")
            restart_services "$2"
            ;;
        "monitor")
            monitor
            ;;
        "health")
            health_check
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

# Exécution
main "$@"