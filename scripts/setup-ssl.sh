#!/bin/bash

# ===================================
# Script de configuration SSL pour Nginx
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

# Fonction pour créer le répertoire SSL
create_ssl_directory() {
    log_info "📁 Création du répertoire SSL..."
    
    mkdir -p nginx/ssl
    chmod 755 nginx/ssl
    
    log_success "✅ Répertoire nginx/ssl créé"
}

# Fonction pour générer les certificats SSL
generate_ssl_certificates() {
    log_info "🔐 Génération des certificats SSL auto-signés..."
    
    # Supprimer les anciens certificats s'ils existent
    rm -f nginx/ssl/server.crt nginx/ssl/server.key
    
    # Générer la clé privée
    openssl genrsa -out nginx/ssl/server.key 2048
    
    # Générer le certificat auto-signé
    openssl req -new -x509 -key nginx/ssl/server.key -out nginx/ssl/server.crt -days 365 -subj "/C=FR/ST=IDF/L=Paris/O=ESGI/OU=Docker/CN=localhost/emailAddress=admin@localhost"
    
    # Définir les permissions appropriées
    chmod 600 nginx/ssl/server.key
    chmod 644 nginx/ssl/server.crt
    
    log_success "✅ Certificats SSL générés"
}

# Fonction pour vérifier les certificats
verify_certificates() {
    log_info "🔍 Vérification des certificats..."
    
    if [ ! -f "nginx/ssl/server.crt" ] || [ ! -f "nginx/ssl/server.key" ]; then
        log_error "❌ Certificats SSL manquants"
        return 1
    fi
    
    # Vérifier le certificat
    if openssl x509 -in nginx/ssl/server.crt -text -noout > /dev/null 2>&1; then
        log_success "✅ Certificat SSL valide"
    else
        log_error "❌ Certificat SSL invalide"
        return 1
    fi
    
    # Vérifier la clé privée
    if openssl rsa -in nginx/ssl/server.key -check -noout > /dev/null 2>&1; then
        log_success "✅ Clé privée SSL valide"
    else
        log_error "❌ Clé privée SSL invalide"
        return 1
    fi
    
    # Vérifier que la clé correspond au certificat
    cert_modulus=$(openssl x509 -noout -modulus -in nginx/ssl/server.crt | openssl md5)
    key_modulus=$(openssl rsa -noout -modulus -in nginx/ssl/server.key | openssl md5)
    
    if [ "$cert_modulus" = "$key_modulus" ]; then
        log_success "✅ Le certificat et la clé correspondent"
    else
        log_error "❌ Le certificat et la clé ne correspondent pas"
        return 1
    fi
    
    # Afficher les informations du certificat
    log_info "📋 Informations du certificat:"
    openssl x509 -in nginx/ssl/server.crt -text -noout | grep -E "(Subject:|Issuer:|Not Before:|Not After:)"
}

# Fonction pour sauvegarder la configuration nginx actuelle
backup_nginx_config() {
    log_info "💾 Sauvegarde de la configuration nginx actuelle..."
    
    if [ -f "nginx/nginx.conf" ]; then
        cp nginx/nginx.conf nginx/nginx.conf.backup.$(date +%Y%m%d_%H%M%S)
        log_success "✅ Configuration sauvegardée"
    fi
}

# Fonction pour appliquer la nouvelle configuration SSL
apply_ssl_config() {
    log_info "🔧 Application de la configuration SSL..."
    
    # Remplacer par la configuration SSL activée
    # (L'utilisateur doit copier le contenu de l'artifact nginx_ssl_config)
    
    log_warning "⚠️  Vous devez maintenant copier la nouvelle configuration nginx.conf avec SSL activé"
    log_info "📝 Utilisez le contenu de l'artifact 'nginx.conf - Avec SSL activé'"
}

# Fonction pour redémarrer nginx
restart_nginx() {
    log_info "🔄 Redémarrage de nginx..."
    
    # Vérifier la configuration nginx
    if docker exec nginx-proxy-prod nginx -t > /dev/null 2>&1; then
        log_success "✅ Configuration nginx valide"
        
        # Redémarrer nginx
        docker compose -f docker-compose.prod.yml restart nginx-proxy
        log_success "✅ Nginx redémarré"
    else
        log_error "❌ Erreur dans la configuration nginx"
        docker exec nginx-proxy-prod nginx -t
        return 1
    fi
}

# Fonction pour tester SSL
test_ssl() {
    log_info "🧪 Test de la configuration SSL..."
    
    # Attendre que nginx redémarre
    sleep 5
    
    # Tester HTTP (devrait rediriger vers HTTPS)
    echo -n "   Test HTTP (redirection): "
    if curl -s -o /dev/null -w "%{http_code}" http://192.168.100.40 | grep -q "301"; then
        log_success "OK (redirection vers HTTPS)"
    else
        log_warning "Pas de redirection détectée"
    fi
    
    # Tester HTTPS
    echo -n "   Test HTTPS: "
    if curl -s -k -o /dev/null -w "%{http_code}" https://192.168.100.40 | grep -q "200"; then
        log_success "OK"
    else
        log_error "ÉCHEC"
        log_info "💡 Vérifiez les logs: docker logs nginx-proxy-prod"
    fi
}

# Fonction pour afficher les informations finales
show_final_info() {
    log_success "🎉 Configuration SSL terminée!"
    echo
    log_info "=== ACCÈS À L'APPLICATION ==="
    log_info "🌐 HTTP (redirige vers HTTPS): http://192.168.100.40"
    log_info "🔒 HTTPS: https://192.168.100.40"
    log_info "🔍 Health check: https://192.168.100.40/health"
    echo
    log_info "=== CERTIFICATS ==="
    log_info "📋 Certificat: nginx/ssl/server.crt"
    log_info "🔑 Clé privée: nginx/ssl/server.key"
    echo
    log_warning "⚠️  IMPORTANT"
    log_warning "• Les certificats sont auto-signés (navigateur affichera un avertissement)"
    log_warning "• En production, utilisez des certificats d'une CA reconnue (Let's Encrypt)"
    echo
    log_info "=== COMMANDES UTILES ==="
    log_info "📜 Logs nginx: docker logs nginx-proxy-prod -f"
    log_info "🔧 Test config: docker exec nginx-proxy-prod nginx -t"
    log_info "🔄 Redémarrer: docker compose -f docker-compose.prod.yml restart nginx-proxy"
    echo
}

# Fonction principale
main() {
    log_info "🚀 Configuration SSL pour Nginx"
    echo
    
    create_ssl_directory
    generate_ssl_certificates
    verify_certificates
    backup_nginx_config
    apply_ssl_config
    
    echo
    log_info "📝 PROCHAINE ÉTAPE MANUELLE:"
    log_info "1. Copiez la nouvelle configuration nginx.conf avec SSL activé"
    log_info "2. Exécutez: docker compose -f docker-compose.prod.yml restart nginx-proxy"
    log_info "3. Testez: curl -k https://192.168.100.40"
    echo
}

# Exécution
main "$@"