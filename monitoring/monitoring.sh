#!/bin/bash

# ===================================
# Script de Monitoring - E-commerce Docker ESGI
# Surveillance complète des services et infrastructure
# ===================================

set -e

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Variables globales
ENVIRONMENT="dev"
MONITORING_INTERVAL=10
CONTINUOUS_MODE=false
SHOW_LOGS=false
SHOW_METRICS=false
SHOW_HEALTH=true
SPECIFIC_SERVICE=""
OUTPUT_FILE=""
ALERT_THRESHOLD_CPU=80
ALERT_THRESHOLD_MEMORY=80
ALERT_THRESHOLD_DISK=90
COMPOSE_FILE=""
ENV_FILE=""
ENV_FILE_OPTION=""

# URLs des services selon l'environnement
setup_urls() {
    if [ "$ENVIRONMENT" = "prod" ]; then
        BASE_URL="http://192.168.100.40"
        CURL_OPTS="-s"
        # Si l'utilisateur a passé --compose-file, on garde la valeur, sinon on met le défaut
        if [ -z "$COMPOSE_FILE" ]; then
            COMPOSE_FILE="docker-compose.prod.yml"
        fi
        # Si l'utilisateur a passé --env-file, on garde la valeur, sinon on met le défaut
        if [ -z "$ENV_FILE" ]; then
            ENV_FILE=".env.github"
        fi
        ENV_FILE_OPTION="--env-file $ENV_FILE"
        AUTH_URL="http://192.168.100.20:3001"
        PRODUCT_URL="http://192.168.100.21:3000"
        ORDER_URL="http://192.168.100.22:3002"
        FRONTEND_URL="http://192.168.100.30:8080"
    else
        BASE_URL="http://localhost"
        CURL_OPTS="-s"
        if [ -z "$COMPOSE_FILE" ]; then
            COMPOSE_FILE="docker-compose.yml"
        fi
        if [ -z "$ENV_FILE" ]; then
            ENV_FILE=".env"
        fi
        ENV_FILE_OPTION=""
        AUTH_URL="$BASE_URL:3001"
        PRODUCT_URL="$BASE_URL:3000"
        ORDER_URL="$BASE_URL:3002"
        FRONTEND_URL="$BASE_URL:8080"
    fi
}

# Fonctions d'affichage
print_header() {
    echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}       ${GREEN}E-commerce Monitoring${NC}         ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  Environment: ${YELLOW}$ENVIRONMENT${NC}                    ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  Time: ${BLUE}$(date '+%Y-%m-%d %H:%M:%S')${NC}      ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
}

print_section() {
    echo ""
    echo -e "${PURPLE}▶ $1${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Fonction d'aide
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --env=ENV              Environnement (dev|prod) [défaut: dev]"
    echo "  --compose-file=FILE    Fichier Docker Compose à utiliser"
    echo "  --env-file=FILE        Fichier d'environnement à utiliser"
    echo "  --service=NAME         Surveiller un service spécifique"
    echo "  --continuous           Mode surveillance continue"
    echo "  --interval=SEC         Intervalle en secondes [défaut: 10]"
    echo "  --logs                 Afficher les logs des services"
    echo "  --metrics              Afficher les métriques détaillées"
    echo "  --health               Vérification de santé uniquement"
    echo "  --output=FILE          Sauvegarder dans un fichier"
    echo "  --cpu-alert=PERCENT    Seuil d'alerte CPU [défaut: 80]"
    echo "  --memory-alert=PERCENT Seuil d'alerte mémoire [défaut: 80]"
    echo "  --disk-alert=PERCENT   Seuil d'alerte disque [défaut: 90]"
    echo "  --help                 Afficher cette aide"
    echo ""
    echo "Exemples:"
    echo "  $0                           # Monitoring basique dev"
    echo "  $0 --env=prod --continuous   # Surveillance continue prod"
    echo "  $0 --service=auth --logs     # Logs du service auth"
    echo "  $0 --metrics --output=report.txt  # Métriques dans fichier"
}

# Vérification de l'état des conteneurs Docker
check_containers() {
    print_section "État des Conteneurs Docker"
    
    if ! docker compose $ENV_FILE_OPTION -f "$COMPOSE_FILE" ps > /dev/null 2>&1; then
        print_error "Impossible d'accéder aux conteneurs Docker"
        return 1
    fi
    
    # Supprimer les warnings Docker Compose en redirigeant stderr
    local containers=$(docker compose $ENV_FILE_OPTION -f "$COMPOSE_FILE" ps --format "table {{.Service}}\t{{.State}}\t{{.Ports}}" 2>/dev/null | grep -v "WARN")
    
    if [ -n "$SPECIFIC_SERVICE" ]; then
        echo "$containers" | grep -i "$SPECIFIC_SERVICE" || print_warning "Service $SPECIFIC_SERVICE non trouvé"
    else
        echo "$containers"
    fi
    
    # Compter les conteneurs par état avec une méthode plus robuste
    local running_containers=$(docker compose $ENV_FILE_OPTION -f "$COMPOSE_FILE" ps -q 2>/dev/null | wc -l)
    local up_containers=$(docker compose $ENV_FILE_OPTION -f "$COMPOSE_FILE" ps --filter "status=running" -q 2>/dev/null | wc -l)
    
    # Vérifier si les variables sont vides et les initialiser
    if [ -z "$running_containers" ] || [ "$running_containers" = "" ]; then
        running_containers=0
    fi
    if [ -z "$up_containers" ] || [ "$up_containers" = "" ]; then
        up_containers=0
    fi
    
    echo ""
    if [ "$up_containers" -eq "$running_containers" ] && [ "$running_containers" -gt 0 ]; then
        print_success "Tous les conteneurs sont opérationnels ($up_containers/$running_containers)"
    elif [ "$running_containers" -eq 0 ]; then
        print_warning "Aucun conteneur détecté. Vérifiez que les services sont démarrés."
    else
        print_warning "Conteneurs opérationnels: $up_containers/$running_containers"
    fi
}

# Vérification de la santé des services
check_services_health() {
    if [ "$SHOW_HEALTH" != "true" ]; then
        return 0
    fi
    
    print_section "État des Services"
    
    # Vérifier d'abord si les conteneurs sont démarrés
    local running_containers=$(docker compose $ENV_FILE_OPTION -f "$COMPOSE_FILE" ps --filter "status=running" -q 2>/dev/null | wc -l)
    if [ "$running_containers" -eq 0 ]; then
        print_warning "Aucun conteneur en cours d'exécution. Démarrez les services avec:"
        print_info "docker compose up -d"
        return 1
    fi
    
    # Définir les services à tester
    declare -A services
    services["Frontend"]="$FRONTEND_URL/"
    services["Auth Service"]="$AUTH_URL/api/health"
    services["Product Service"]="$PRODUCT_URL/api/health"
    services["Order Service"]="$ORDER_URL/api/health"
    
    local healthy=0
    local total=0
    
    for service_name in "${!services[@]}"; do
        ((total++))
        local url="${services[$service_name]}"
        
        # Filtrer par service spécifique
        if [ -n "$SPECIFIC_SERVICE" ]; then
            if ! echo "$service_name" | grep -qi "$SPECIFIC_SERVICE"; then
                continue
            fi
        fi
        
        print_info "Test de $service_name..."
        local start_time=$(date +%s%N)
        local response=$(curl $CURL_OPTS -w "%{http_code}" -o /dev/null --connect-timeout 5 --max-time 10 "$url" 2>/dev/null || echo "000")
        local end_time=$(date +%s%N)
        local response_time=$(((end_time - start_time) / 1000000))
        
        if [ "$response" = "200" ]; then
            print_success "$service_name (${response_time}ms)"
            ((healthy++))
        elif [ "$response" = "000" ]; then
            print_error "$service_name - Connexion impossible"
        else
            print_error "$service_name - Code HTTP: $response"
        fi
    done
    
    echo ""
    if [ $healthy -eq $total ] && [ $total -gt 0 ]; then
        print_success "Tous les services sont sains ($healthy/$total)"
    else
        print_warning "Services sains: $healthy/$total"
        if [ $healthy -eq 0 ]; then
            print_info "Vérifiez que les services sont démarrés et que les ports sont correctement exposés"
        fi
    fi
}

# Surveillance des ressources système
check_system_resources() {
    if [ "$SHOW_METRICS" != "true" ]; then
        return 0
    fi
    
    print_section "Ressources Système"
    
    # CPU Usage - méthode plus robuste
    local cpu_usage=$(top -bn1 | grep "^%Cpu" | awk '{print $2}' | sed 's/%us,//' || echo "N/A")
    if [ "$cpu_usage" != "N/A" ]; then
        local cpu_percent=$(echo "$cpu_usage" | cut -d'.' -f1)
        echo -n "CPU Usage: $cpu_usage"
        if [ "$cpu_percent" -gt "$ALERT_THRESHOLD_CPU" ] 2>/dev/null; then
            echo -e " ${RED}[ALERT]${NC}"
        else
            echo -e " ${GREEN}[OK]${NC}"
        fi
    else
        echo "CPU Usage: Non disponible"
    fi
    
    # Memory Usage
    local memory_info=$(free -m | awk 'NR==2{printf "%.1f%%", $3*100/$2 }' 2>/dev/null || echo "N/A")
    if [ "$memory_info" != "N/A" ]; then
        local memory_percent=$(echo "$memory_info" | cut -d'%' -f1 | cut -d'.' -f1)
        echo -n "Memory Usage: $memory_info"
        if [ "$memory_percent" -gt "$ALERT_THRESHOLD_MEMORY" ] 2>/dev/null; then
            echo -e " ${RED}[ALERT]${NC}"
        else
            echo -e " ${GREEN}[OK]${NC}"
        fi
    else
        echo "Memory Usage: Non disponible"
    fi
    
    # Disk Usage
    local disk_usage=$(df -h / | awk 'NR==2{print $5}' | sed 's/%//' 2>/dev/null || echo "0")
    echo -n "Disk Usage: $disk_usage%"
    if [ "$disk_usage" -gt "$ALERT_THRESHOLD_DISK" ] 2>/dev/null; then
        echo -e " ${RED}[ALERT]${NC}"
    else
        echo -e " ${GREEN}[OK]${NC}"
    fi
    
    # Load Average
    local load_avg=$(uptime | awk -F'load average:' '{ print $2 }' 2>/dev/null || echo " N/A")
    echo "Load Average:$load_avg"
    
    # Docker Resources
    echo ""
    print_info "Ressources Docker:"
    if docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" 2>/dev/null | head -10; then
        :
    else
        print_warning "Impossible de récupérer les statistiques Docker"
    fi
}

# Surveillance des logs
show_service_logs() {
    if [ "$SHOW_LOGS" != "true" ]; then
        return 0
    fi
    
    print_section "Logs des Services"
    
    local services=("frontend" "auth-service" "product-service" "order-service")
    
    if [ -n "$SPECIFIC_SERVICE" ]; then
        services=("$SPECIFIC_SERVICE")
    fi
    
    for service in "${services[@]}"; do
        echo ""
        print_info "Logs récents - $service:"
        echo "----------------------------------------"
        
        if docker compose $ENV_FILE_OPTION -f "$COMPOSE_FILE" logs --tail=10 "$service" 2>/dev/null; then
            echo ""
        else
            print_warning "Aucun log disponible pour $service"
        fi
    done
}

# Vérification de la connectivité réseau
check_network_connectivity() {
    if [ "$SHOW_METRICS" != "true" ]; then
        return 0
    fi
    
    print_section "Connectivité Réseau"
    
    # Test des connexions internes Docker
    local networks=$(docker network ls --format "table {{.Name}}\t{{.Driver}}" | grep -v "DRIVER")
    echo "Réseaux Docker:"
    echo "$networks"
    
    echo ""
    print_info "Test de connectivité interne:"
    
    # Ping entre conteneurs (si possible)
    if docker compose $ENV_FILE_OPTION -f "$COMPOSE_FILE" ps | grep -q "Up"; then
        local frontend_ip=$(docker compose $ENV_FILE_OPTION -f "$COMPOSE_FILE" exec -T frontend hostname -i 2>/dev/null | tr -d '\r' || echo "N/A")
        local auth_ip=$(docker compose $ENV_FILE_OPTION -f "$COMPOSE_FILE" exec -T auth-service hostname -i 2>/dev/null | tr -d '\r' || echo "N/A")
        
        echo "Frontend IP: $frontend_ip"
        echo "Auth Service IP: $auth_ip"
    fi
}

# Surveillance de la base de données
check_database_status() {
    if [ "$SHOW_METRICS" != "true" ]; then
        return 0
    fi
    
    print_section "État des Bases de Données"
    
    local databases=("mongodb-auth" "mongodb-products" "mongodb-orders")
    
    for db in "${databases[@]}"; do
        if docker compose $ENV_FILE_OPTION -f "$COMPOSE_FILE" ps | grep -q "$db.*Up"; then
            print_success "$db est opérationnelle"
            
            # Essayer de récupérer des statistiques
            local stats=$(docker compose $ENV_FILE_OPTION -f "$COMPOSE_FILE" exec -T "$db" mongo --quiet --eval "db.stats()" 2>/dev/null || echo "Stats non disponibles")
            if [ "$stats" != "Stats non disponibles" ]; then
                echo "  Stats:"
                echo "$stats" | sed 's/^/    /'
            fi
        else
            print_error "$db n'est pas accessible"
        fi
    done
}

# Vérification des certificats SSL (production)
check_ssl_certificates() {
    if [ "$ENVIRONMENT" != "prod" ]; then
        return 0
    fi
    
    print_section "Certificats SSL"
    
    if [ -f "ssl/server.crt" ]; then
        local expiry=$(openssl x509 -in ssl/server.crt -noout -dates | grep "notAfter" | cut -d= -f2)
        local expiry_timestamp=$(date -d "$expiry" +%s 2>/dev/null || echo "0")
        local current_timestamp=$(date +%s)
        local days_until_expiry=$(( (expiry_timestamp - current_timestamp) / 86400 ))
        
        if [ $days_until_expiry -gt 30 ]; then
            print_success "Certificat SSL valide (expire dans $days_until_expiry jours)"
        elif [ $days_until_expiry -gt 0 ]; then
            print_warning "Certificat SSL expire dans $days_until_expiry jours"
        else
            print_error "Certificat SSL expiré"
        fi
        
        echo "Expiration: $expiry"
    else
        print_error "Certificat SSL non trouvé"
    fi
}

# Surveillance de la sécurité
check_security_metrics() {
    if [ "$SHOW_METRICS" != "true" ]; then
        return 0
    fi
    
    print_section "Métriques de Sécurité"
    
    # Vérifier les connexions actives
    local connections=$(ss -tuln | wc -l)
    echo "Connexions actives: $connections"
    
    # Vérifier les processus Docker
    local docker_processes=$(docker ps | wc -l)
    echo "Processus Docker: $((docker_processes - 1))"
    
    # Vérifier l'espace disque Docker
    local docker_space=$(docker system df | grep -v "TYPE" | awk '{sum += $4} END {print sum}' || echo "0")
    echo "Espace Docker utilisé: ${docker_space:-0}MB"
    
    # Dernières connexions (si disponible)
    if command -v last > /dev/null 2>&1; then
        echo ""
        print_info "Dernières connexions système:"
        last -n 5 | head -5
    fi
}

# Génération d'un rapport complet
generate_report() {
    local report_file="${OUTPUT_FILE:-monitoring-report-$(date +%Y%m%d-%H%M%S).txt}"
    print_section "Génération du Rapport"
    {
        echo "E-commerce Docker ESGI - Rapport de Monitoring"
        echo "============================================="
        echo "Date: $(date)"
        echo "Environnement: $ENVIRONMENT"
        echo "Généré par: $USER"
        echo ""
        echo "RÉSUMÉ EXÉCUTIF"
        echo "==============="
        local running_containers=$(docker compose $ENV_FILE_OPTION -f "$COMPOSE_FILE" ps --filter "status=running" -q 2>/dev/null | wc -l || echo "0")
        local total_containers=$(docker compose $ENV_FILE_OPTION -f "$COMPOSE_FILE" ps -q 2>/dev/null | wc -l || echo "0")
        echo "Conteneurs: $running_containers/$total_containers opérationnels"
        echo ""
        echo "ÉTAT DES SERVICES"
        echo "================="
        docker compose $ENV_FILE_OPTION -f "$COMPOSE_FILE" ps --format "table {{.Service}}\t{{.State}}\t{{.Ports}}" 2>/dev/null | grep -v "WARN" || echo "Erreur récupération conteneurs"
        echo ""
        echo "SANTÉ DES SERVICES"
        echo "=================="
        declare -A services
        services["Frontend"]="$FRONTEND_URL/"
        services["Auth Service"]="$AUTH_URL/api/health"
        services["Product Service"]="$PRODUCT_URL/api/health"
        services["Order Service"]="$ORDER_URL/api/health"
        for service_name in "${!services[@]}"; do
            local url="${services[$service_name]}"
            local response=$(curl $CURL_OPTS -w "%{http_code}" -o /dev/null --connect-timeout 3 --max-time 5 "$url" 2>/dev/null || echo "000")
            if [ "$response" = "200" ]; then
                echo "$service_name : OK (HTTP 200)"
            else
                echo "$service_name : KO (HTTP $response)"
            fi
        done
        echo ""
        echo "RESSOURCES SYSTÈME"
        echo "=================="
        local cpu_usage=$(top -bn1 | grep "^%Cpu" | awk '{print $2}' | sed 's/%us,//' 2>/dev/null || echo "N/A")
        local memory_usage=$(free -m | awk 'NR==2{printf "%.1f%%", $3*100/$2 }' 2>/dev/null || echo "N/A")
        local disk_usage=$(df -h / | awk 'NR==2{print $5}' 2>/dev/null || echo "N/A")
        local load_avg=$(uptime | awk -F'load average:' '{ print $2 }' 2>/dev/null || echo "N/A")
        echo "CPU: $cpu_usage"
        echo "Mémoire: $memory_usage"
        echo "Disque: $disk_usage"
        echo "Load Average: $load_avg"
        echo ""
        echo "STATS DOCKER"
        echo "============"
        docker stats --no-stream 2>/dev/null || echo "Erreur récupération stats"
        echo ""
        echo "BASES DE DONNÉES"
        echo "================"
        local databases=("mongodb-auth" "mongodb-products" "mongodb-orders")
        for db in "${databases[@]}"; do
            if docker compose $ENV_FILE_OPTION -f "$COMPOSE_FILE" ps | grep -q "$db.*Up"; then
                echo "$db : accessible"
                local stats=$(docker compose $ENV_FILE_OPTION -f "$COMPOSE_FILE" exec -T "$db" mongo --quiet --eval "db.stats()" 2>/dev/null || echo "Stats non disponibles")
                if [ "$stats" != "Stats non disponibles" ]; then
                    echo "  Stats:"
                    echo "$stats" | sed 's/^/    /'
                fi
            else
                echo "$db : non accessible"
            fi
        done
        echo ""
        echo "IPS DES SERVICES"
        echo "================"
        docker inspect --format '{{.Name}}: {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(docker ps -q) 2>/dev/null || echo "Erreur récupération IPs"
        echo ""
        echo "PORTS EXPOSÉS"
        echo "============="
        docker compose $ENV_FILE_OPTION -f "$COMPOSE_FILE" ps --format "table {{.Service}}\t{{.Ports}}" 2>/dev/null | grep -v "WARN" || echo "Erreur récupération ports"
    } > "$report_file"
    print_success "Rapport sauvegardé: $report_file"
}

# Mode surveillance continue
continuous_monitoring() {
    print_info "Mode surveillance continue activé (Ctrl+C pour arrêter)"
    print_info "Intervalle: ${MONITORING_INTERVAL}s"
    echo ""
    
    while true; do
        clear
        print_header
        check_containers
        check_services_health
        check_system_resources
        check_database_status
        check_network_connectivity
        check_ssl_certificates
        check_security_metrics
        
        if [ "$SHOW_LOGS" = "true" ]; then
            show_service_logs
        fi
        
        echo ""
        print_info "Prochaine mise à jour dans ${MONITORING_INTERVAL}s (Ctrl+C pour arrêter)"
        sleep "$MONITORING_INTERVAL"
    done
}

# Gestion des signaux
cleanup() {
    echo ""
    print_info "Arrêt du monitoring..."
    exit 0
}

trap cleanup SIGINT SIGTERM

# ===================================
# MAIN - Fonction principale
# ===================================

main() {
    # Traitement des arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --env=*)
                ENVIRONMENT="${1#*=}"
                shift
                ;;
            --compose-file=*)
                COMPOSE_FILE="${1#*=}"
                shift
                ;;
            --env-file=*)
                ENV_FILE="${1#*=}"
                shift
                ;;
            --service=*)
                SPECIFIC_SERVICE="${1#*=}"
                shift
                ;;
            --continuous)
                CONTINUOUS_MODE=true
                shift
                ;;
            --interval=*)
                MONITORING_INTERVAL="${1#*=}"
                shift
                ;;
            --logs)
                SHOW_LOGS=true
                shift
                ;;
            --metrics)
                SHOW_METRICS=true
                shift
                ;;
            --health)
                SHOW_HEALTH=true
                SHOW_METRICS=false
                SHOW_LOGS=false
                shift
                ;;
            --output=*)
                OUTPUT_FILE="${1#*=}"
                shift
                ;;
            --cpu-alert=*)
                ALERT_THRESHOLD_CPU="${1#*=}"
                shift
                ;;
            --memory-alert=*)
                ALERT_THRESHOLD_MEMORY="${1#*=}"
                shift
                ;;
            --disk-alert=*)
                ALERT_THRESHOLD_DISK="${1#*=}"
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                echo "Option inconnue: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Configuration des URLs selon l'environnement
    setup_urls
    
    # Validation de l'environnement
    if [ "$ENVIRONMENT" != "dev" ] && [ "$ENVIRONMENT" != "prod" ]; then
        print_error "Environnement invalide: $ENVIRONMENT (dev|prod)"
        exit 1
    fi
    
    # Vérifier que les fichiers Docker Compose existent
    if [ ! -f "$COMPOSE_FILE" ]; then
        print_error "Fichier $COMPOSE_FILE non trouvé"
        exit 1
    fi
    
    # Vérifier que Docker est accessible
    if ! docker ps > /dev/null 2>&1; then
        print_error "Docker n'est pas accessible. Vérifiez que Docker est démarré et que vous avez les permissions."
        exit 1
    fi
    
    # Mode continu ou unique
    if [ "$CONTINUOUS_MODE" = "true" ]; then
        continuous_monitoring
    else
        # Si OUTPUT_FILE est défini, ne rien afficher dans le terminal, juste générer le rapport
        if [ -n "$OUTPUT_FILE" ]; then
            generate_report
            print_info "Rapport généré : $OUTPUT_FILE"
            exit 0
        fi
        # Exécution unique (affichage terminal)
        print_header
        check_containers
        check_services_health
        if [ "$SHOW_METRICS" = "true" ]; then
            check_system_resources
        fi
        check_database_status
        check_network_connectivity
        check_ssl_certificates
        check_security_metrics
        if [ "$SHOW_LOGS" = "true" ]; then
            show_service_logs
        fi
        echo ""
        print_success "Monitoring terminé"
        # Afficher un résumé
        local running=$(docker compose -f "$COMPOSE_FILE" ps --filter "status=running" -q 2>/dev/null | wc -l || echo "0")
        local total=$(docker compose -f "$COMPOSE_FILE" ps -q 2>/dev/null | wc -l || echo "0")
        if [ "$running" -eq "$total" ] && [ "$total" -gt 0 ]; then
            print_success "Système opérationnel: $running/$total services actifs"
        elif [ "$total" -eq 0 ]; then
            print_warning "Aucun service détecté. Démarrez les services avec: docker compose up -d"
        else
            print_warning "Attention: $running/$total services actifs"
        fi
    fi
}

# Exécution du script principal
main "$@"