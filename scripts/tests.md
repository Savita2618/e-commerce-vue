# Guide de Tests - E-commerce Docker ESGI

## Table des Matières

1. [Prérequis et Configuration](#prérequis-et-configuration)
2. [Tests de Base - Conteneurs](#tests-de-base---conteneurs)
3. [Tests HTTP - Développement](#tests-http---développement)
4. [Tests HTTPS - Production](#tests-https---production)
5. [Tests d'Intégration Complets](#tests-dintégration-complets)
6. [Scripts de Tests Automatisés](#scripts-de-tests-automatisés)
7. [Troubleshooting](#troubleshooting)

---

## Prérequis et Configuration

### Variables d'Environnement de Test

```bash
# Variables de base
export TEST_USER_EMAIL="test@example.com"
export TEST_USER_PASSWORD="password123"
export ADMIN_TOKEN="efrei_super_pass"
export TEST_USER_ID="test-user-id"

# URLs selon l'environnement
export DEV_BASE_URL="http://localhost"
export PROD_BASE_URL="http://192.168.100.40"
export PROD_HTTPS_URL="https://192.168.100.40"
```

### Vérification de l'Environnement

```bash
# Vérifier Docker
docker --version
docker compose version

# Vérifier que les services sont démarrés
docker ps -a

# Vérifier les réseaux Docker
docker network ls | grep ecommerce
```

---

## Tests de Base - Conteneurs

### Vérification des Conteneurs

```bash
# État de tous les conteneurs
docker ps -a

# Conteneurs spécifiques du projet
docker ps -a | grep -E "(ecommerce|frontend|mongo)"

# Statut des conteneurs par service
echo "AUTH SERVICE"
docker ps -a | grep auth
echo "PRODUCT SERVICE"
docker ps -a | grep product
echo "ORDER SERVICE"
docker ps -a | grep order
echo "FRONTEND"
docker ps -a | grep frontend
echo "MONGODB"
docker ps -a | grep mongo
```

### Vérification des Logs

```bash
# Logs détaillés par service
echo "LOGS AUTH SERVICE"
docker logs ecommerce-auth | tail -10

echo "LOGS PRODUCT SERVICE"
docker logs ecommerce-products | tail -10

echo "LOGS ORDER SERVICE"
docker logs ecommerce-orders | tail -10

echo "LOGS FRONTEND"
docker logs ecommerce-frontend | tail -10

# Logs MongoDB
echo "LOGS MONGODB"
docker logs mongo-test | tail -10
```

### Tests de Connectivité Réseau

```bash
# Inspecter le réseau e-commerce
docker network inspect ecommerce-network

# Tester la connectivité entre conteneurs
docker exec ecommerce-auth ping -c 3 mongo-test
docker exec ecommerce-products ping -c 3 mongo-test
docker exec ecommerce-orders ping -c 3 mongo-test
```

---

## Tests HTTP - Développement

### Auth Service (Port 3001)

#### Health Check
```bash
echo "AUTH SERVICE HEALTH CHECK"
curl -w "\nStatus: %{http_code}\nTime: %{time_total}s\n" \
     http://localhost:3001/api/health
```

#### Test d'Inscription
```bash
echo "TEST INSCRIPTION"
curl -X POST http://localhost:3001/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"'$TEST_USER_EMAIL'","password":"'$TEST_USER_PASSWORD'"}' \
  -w "\nStatus: %{http_code}\nTime: %{time_total}s\n"
```

#### Test de Connexion
```bash
echo "TEST CONNEXION"
curl -X POST http://localhost:3001/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"'$TEST_USER_EMAIL'","password":"'$TEST_USER_PASSWORD'"}' \
  -w "\nStatus: %{http_code}\nTime: %{time_total}s\n"
```

#### Sauvegarder le Token
```bash
echo "RÉCUPÉRATION DU TOKEN"
TOKEN=$(curl -s -X POST http://localhost:3001/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"'$TEST_USER_EMAIL'","password":"'$TEST_USER_PASSWORD'"}' \
  | grep -o '"token":"[^"]*' | cut -d'"' -f4)

if [ -n "$TOKEN" ]; then
    echo "Token récupéré: ${TOKEN:0:20}..."
    export AUTH_TOKEN="$TOKEN"
else
    echo "Échec de récupération du token"
fi
```

#### Test du Profil Utilisateur
```bash
echo "TEST PROFIL UTILISATEUR"
if [ -n "$AUTH_TOKEN" ]; then
    curl -H "Authorization: Bearer $AUTH_TOKEN" \
         http://localhost:3001/api/auth/profile \
         -w "\nStatus: %{http_code}\nTime: %{time_total}s\n"
else
    echo "Token non disponible"
fi
```

### Product Service (Port 3000)

#### Health Check et Logs
```bash
echo "PRODUCT SERVICE HEALTH CHECK"
docker logs ecommerce-products | tail -5
curl -w "\nStatus: %{http_code}\nTime: %{time_total}s\n" \
     http://localhost:3000/api/health
```

#### Liste des Produits
```bash
echo "LISTE DES PRODUITS (au début - vide)"
curl http://localhost:3000/api/products \
     -w "\nStatus: %{http_code}\nTime: %{time_total}s\n"
```

#### Créer un Produit de Test
```bash
echo "CRÉATION D'UN PRODUIT DE TEST"
curl -X POST http://localhost:3000/api/products \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d '{
    "name": "Produit Test",
    "price": 99.99,
    "description": "Description test pour les tests automatisés",
    "stock": 10,
    "category": "Test"
  }' \
  -w "\nStatus: %{http_code}\nTime: %{time_total}s\n"
```

#### Vérifier la Création du Produit
```bash
echo "VÉRIFICATION DE LA CRÉATION"
curl http://localhost:3000/api/products \
     -w "\nStatus: %{http_code}\nTime: %{time_total}s\n"
```

#### Récupérer l'ID du Produit
```bash
echo "RÉCUPÉRATION DE L'ID DU PRODUIT"
PRODUCT_ID=$(curl -s http://localhost:3000/api/products | \
             grep -o '"_id":"[^"]*' | head -1 | cut -d'"' -f4)

if [ -n "$PRODUCT_ID" ]; then
    echo "Product ID récupéré: $PRODUCT_ID"
    export TEST_PRODUCT_ID="$PRODUCT_ID"
else
    echo "Aucun produit trouvé"
fi
```

#### Test du Panier

**Ajouter au Panier:**
```bash
echo "AJOUT AU PANIER"
if [ -n "$TEST_PRODUCT_ID" ]; then
    curl -X POST http://localhost:3000/api/cart/add \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $ADMIN_TOKEN" \
      -d '{
        "userId": "'$TEST_USER_ID'",
        "productId": "'$TEST_PRODUCT_ID'",
        "quantity": 2
      }' \
      -w "\nStatus: %{http_code}\nTime: %{time_total}s\n"
else
    echo "Product ID non disponible"
fi
```

**Voir le Panier:**
```bash
echo "CONSULTATION DU PANIER"
curl http://localhost:3000/api/cart \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "userId: $TEST_USER_ID" \
  -w "\nStatus: %{http_code}\nTime: %{time_total}s\n"
```

### Order Service (Port 3002)

#### Health Check et Logs
```bash
echo "ORDER SERVICE HEALTH CHECK"
docker logs ecommerce-orders | tail -5
curl -w "\nStatus: %{http_code}\nTime: %{time_total}s\n" \
     http://localhost:3002/api/health
```

#### Créer une Commande
```bash
echo "CRÉATION D'UNE COMMANDE"
if [ -n "$AUTH_TOKEN" ] && [ -n "$TEST_PRODUCT_ID" ]; then
    curl -X POST http://localhost:3002/api/orders \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $AUTH_TOKEN" \
      -d '{
        "products": [{
          "productId": "'$TEST_PRODUCT_ID'",
          "quantity": 1
        }],
        "shippingAddress": {
          "street": "123 Test Street",
          "city": "Test City",
          "postalCode": "12345",
          "country": "France"
        }
      }' \
      -w "\nStatus: %{http_code}\nTime: %{time_total}s\n"
else
    echo "Token ou Product ID non disponible"
fi
```

#### Voir les Commandes
```bash
echo "CONSULTATION DES COMMANDES"
if [ -n "$AUTH_TOKEN" ]; then
    curl http://localhost:3002/api/orders \
      -H "Authorization: Bearer $AUTH_TOKEN" \
      -w "\nStatus: %{http_code}\nTime: %{time_total}s\n"
else
    echo "Token non disponible"
fi
```

### Frontend (Port 8080)

#### Tests d'Accès Frontend
```bash
echo "FRONTEND TESTS"

# Vérifier les logs
docker logs ecommerce-frontend | tail -5

# Test d'accès (headers seulement)
echo "TEST HEADERS FRONTEND"
curl -I http://localhost:8080

# Test d'accès complet
echo "TEST ACCÈS COMPLET"
curl -s http://localhost:8080 | head -20

# Test avec IP directe du conteneur (si disponible)
FRONTEND_IP=$(docker inspect ecommerce-frontend | grep -o '"IPAddress": "[^"]*' | cut -d'"' -f4 | head -1)
if [ -n "$FRONTEND_IP" ]; then
    echo "TEST AVEC IP DIRECTE: $FRONTEND_IP"
    curl -I http://$FRONTEND_IP:8080/
fi
```

---

## Tests HTTPS - Production

### Configuration de Base

```bash
# Variables pour la production
export PROD_EMAIL="test@email.com"
export PROD_PASSWORD="esgi123456"
export PROD_SERVER="192.168.100.40"
```

### Tests d'Authentification HTTPS

#### Connexion Sécurisée
```bash
echo "CONNEXION HTTPS PRODUCTION"
TOKEN_HTTPS=$(curl -k -s -X POST https://$PROD_SERVER/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"'$PROD_EMAIL'","password":"'$PROD_PASSWORD'"}' \
  | grep -o '"token":"[^"]*' | cut -d'"' -f4)

if [ -n "$TOKEN_HTTPS" ]; then
    echo "Token HTTPS récupéré: ${TOKEN_HTTPS:0:20}..."
    export PROD_TOKEN="$TOKEN_HTTPS"
else
    echo "Échec de récupération du token HTTPS"
fi
```

#### Health Checks HTTPS
```bash
echo "HEALTH CHECKS HTTPS"
curl -k -w "\nStatus: %{http_code}\nTime: %{time_total}s\n" \
     https://$PROD_SERVER/api/auth/health

curl -k -w "\nStatus: %{http_code}\nTime: %{time_total}s\n" \
     https://$PROD_SERVER/api/products/health

curl -k -w "\nStatus: %{http_code}\nTime: %{time_total}s\n" \
     https://$PROD_SERVER/api/orders/health
```

### Gestion des Commandes en Production

#### Voir Toutes les Commandes
```bash
echo "TOUTES LES COMMANDES"
if [ -n "$PROD_TOKEN" ]; then
    curl -k -s https://$PROD_SERVER/api/orders \
      -H "Authorization: Bearer $PROD_TOKEN" | jq '.'
else
    echo "Token production non disponible"
fi
```

#### Récupérer l'ID d'une Commande
```bash
echo "RÉCUPÉRATION ID COMMANDE"
if [ -n "$PROD_TOKEN" ]; then
    ORDER_ID=$(curl -k -s https://$PROD_SERVER/api/orders \
      -H "Authorization: Bearer $PROD_TOKEN" | \
      jq -r '.[0]._id // empty')
    
    if [ -n "$ORDER_ID" ] && [ "$ORDER_ID" != "null" ]; then
        echo "Order ID récupéré: $ORDER_ID"
        export PROD_ORDER_ID="$ORDER_ID"
    else
        # Utiliser un ID d'exemple si aucune commande trouvée
        export PROD_ORDER_ID="686e72fe49f64b39c85f5e24"
        echo "Utilisation de l'ID d'exemple: $PROD_ORDER_ID"
    fi
fi
```

#### Tests de Gestion des Statuts de Commande
```bash
echo "GESTION DES STATUTS DE COMMANDE"

if [ -n "$PROD_TOKEN" ] && [ -n "$PROD_ORDER_ID" ]; then
    # Confirmer la commande
    echo "Confirmation de la commande"
    curl -k -X PATCH https://$PROD_SERVER/api/orders/$PROD_ORDER_ID/status \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $PROD_TOKEN" \
      -d '{"status": "confirmed"}' \
      -w "\nStatus: %{http_code}\n"
    
    sleep 2
    
    # Marquer comme expédiée
    echo "Expédition de la commande"
    curl -k -X PATCH https://$PROD_SERVER/api/orders/$PROD_ORDER_ID/status \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $PROD_TOKEN" \
      -d '{"status": "shipped"}' \
      -w "\nStatus: %{http_code}\n"
    
    sleep 2
    
    # Marquer comme livrée
    echo "Livraison de la commande"
    curl -k -X PATCH https://$PROD_SERVER/api/orders/$PROD_ORDER_ID/status \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $PROD_TOKEN" \
      -d '{"status": "delivered"}' \
      -w "\nStatus: %{http_code}\n"
    
    # Vérifier le statut final
    echo "Vérification du statut final"
    curl -k -s https://$PROD_SERVER/api/orders/$PROD_ORDER_ID \
      -H "Authorization: Bearer $PROD_TOKEN" | \
      jq '.status // "Status not found"'
else
    echo "Token ou Order ID non disponible"
fi
```

**Statuts de commande disponibles :**
- `pending` : En attente
- `confirmed` : Confirmée
- `shipped` : Expédiée
- `delivered` : Livrée
- `cancelled` : Annulée

### Tests de Sécurité SSL

#### Vérification du Certificat
```bash
echo "VÉRIFICATION DU CERTIFICAT SSL"
openssl s_client -connect $PROD_SERVER:443 -servername localhost <<< "Q" | \
grep -E "(subject|issuer|notAfter)"
```

#### Test de Redirection HTTP vers HTTPS
```bash
echo "TEST DE REDIRECTION HTTP vers HTTPS"
curl -I http://$PROD_SERVER 2>/dev/null | grep -E "(HTTP|Location)"
```

#### Test des Headers de Sécurité
```bash
echo "HEADERS DE SÉCURITÉ"
curl -k -I https://$PROD_SERVER/ | \
grep -E "(Strict-Transport-Security|X-Frame-Options|X-Content-Type-Options)"
```

---

## Tests d'Intégration Complets

### Script de Test Complet - Développement

```bash
#!/bin/bash
# test-integration-dev.sh

echo "TESTS D'INTÉGRATION - DÉVELOPPEMENT"
echo "======================================"

# 1. Vérification préalable
echo "Vérification des conteneurs..."
if ! docker ps | grep -q ecommerce; then
    echo "Conteneurs e-commerce non trouvés"
    exit 1
fi

# 2. Health checks
echo "Health checks..."
SERVICES=("auth:3001" "products:3000" "orders:3002")
for service in "${SERVICES[@]}"; do
    IFS=':' read -r name port <<< "$service"
    if curl -f -s http://localhost:$port/api/health > /dev/null; then
        echo "OK $name ($port)"
    else
        echo "ERREUR $name ($port)"
    fi
done

# 3. Test du workflow complet
echo "Workflow d'inscription → connexion → produit → commande"

# Inscription
echo "Inscription..."
REGISTER_RESULT=$(curl -s -w "%{http_code}" -X POST http://localhost:3001/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"workflow@test.com","password":"test123"}')

echo "Résultat inscription: ${REGISTER_RESULT: -3}"

# Connexion et récupération du token
echo "Connexion..."
TOKEN=$(curl -s -X POST http://localhost:3001/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"workflow@test.com","password":"test123"}' | \
  grep -o '"token":"[^"]*' | cut -d'"' -f4)

if [ -n "$TOKEN" ]; then
    echo "Token récupéré"
else
    echo "Échec de récupération du token"
    exit 1
fi

# Test des produits
echo "Test des produits..."
PRODUCTS=$(curl -s http://localhost:3000/api/products)
PRODUCT_COUNT=$(echo "$PRODUCTS" | jq '. | length' 2>/dev/null || echo "0")
echo "Produits trouvés: $PRODUCT_COUNT"

# Test des commandes
echo "Test des commandes..."
ORDERS=$(curl -s -H "Authorization: Bearer $TOKEN" http://localhost:3002/api/orders)
ORDER_COUNT=$(echo "$ORDERS" | jq '. | length' 2>/dev/null || echo "0")
echo "Commandes trouvées: $ORDER_COUNT"

echo "Tests d'intégration terminés"
```

### Script de Test Complet - Production

```bash
#!/bin/bash
# test-integration-prod.sh

echo "TESTS D'INTÉGRATION - PRODUCTION HTTPS"
echo "========================================"

SERVER="192.168.100.40"

# 1. Test de connectivité
echo "Test de connectivité..."
if curl -k -f -s https://$SERVER/health > /dev/null; then
    echo "Serveur accessible"
else
    echo "Serveur non accessible"
    exit 1
fi

# 2. Test SSL
echo "Test SSL..."
SSL_EXPIRY=$(openssl s_client -connect $SERVER:443 -servername localhost 2>/dev/null <<< "Q" | \
             openssl x509 -noout -dates | grep notAfter | cut -d= -f2)
echo "Certificat expire le: $SSL_EXPIRY"

# 3. Connexion et tests
echo "Connexion production..."
PROD_TOKEN=$(curl -k -s -X POST https://$SERVER/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@email.com","password":"esgi123456"}' | \
  grep -o '"token":"[^"]*' | cut -d'"' -f4)

if [ -n "$PROD_TOKEN" ]; then
    echo "Connexion production réussie"
    
    # Test des commandes
    echo "Test des commandes..."
    ORDER_COUNT=$(curl -k -s https://$SERVER/api/orders \
      -H "Authorization: Bearer $PROD_TOKEN" | jq '. | length' 2>/dev/null)
    echo "Commandes trouvées: $ORDER_COUNT"
    
else
    echo "Échec de connexion production"
fi

echo "Tests de production terminés"
```

---

## Scripts de Tests Automatisés

### Script Principal de Tests

```bash
#!/bin/bash
# run-all-tests.sh

set -e

echo "SUITE DE TESTS COMPLÈTE E-COMMERCE"
echo "===================================="

# Configuration
TEST_ENV=${1:-dev}
VERBOSE=${2:-false}

case $TEST_ENV in
    "dev")
        BASE_URL="http://localhost"
        ;;
    "prod")
        BASE_URL="https://192.168.100.40"
        CURL_OPTS="-k"
        ;;
    *)
        echo "Usage: $0 [dev|prod] [verbose]"
        exit 1
        ;;
esac

echo "Environment: $TEST_ENV"
echo "Base URL: $BASE_URL"

# Fonction pour afficher les détails si mode verbose
log_verbose() {
    if [ "$VERBOSE" = "true" ]; then
        echo "  $1"
    fi
}

# Fonction de test avec retry
test_endpoint() {
    local url=$1
    local expected_status=${2:-200}
    local max_retries=${3:-3}
    local retry=0
    
    while [ $retry -lt $max_retries ]; do
        local status=$(curl $CURL_OPTS -s -w "%{http_code}" -o /dev/null "$url")
        
        if [ "$status" = "$expected_status" ]; then
            echo "OK $url ($status)"
            return 0
        fi
        
        retry=$((retry + 1))
        log_verbose "Retry $retry/$max_retries for $url"
        sleep 2
    done
    
    echo "ERREUR $url ($status, expected $expected_status)"
    return 1
}

# Tests de santé
echo "Health Checks..."
test_endpoint "$BASE_URL:3001/api/health" 200
test_endpoint "$BASE_URL:3000/api/health" 200
test_endpoint "$BASE_URL:3002/api/health" 200

if [ "$TEST_ENV" = "dev" ]; then
    test_endpoint "$BASE_URL:8080" 200
fi

# Tests API avec données
echo "Tests API..."

# Test d'inscription
REGISTER_STATUS=$(curl $CURL_OPTS -s -w "%{http_code}" -o /dev/null \
  -X POST $BASE_URL:3001/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"autotest@example.com","password":"test123"}')

if [ "$REGISTER_STATUS" = "201" ] || [ "$REGISTER_STATUS" = "200" ] || [ "$REGISTER_STATUS" = "409" ]; then
    echo "OK Inscription ($REGISTER_STATUS)"
else
    echo "ERREUR Inscription ($REGISTER_STATUS)"
fi

# Test de connexion
LOGIN_STATUS=$(curl $CURL_OPTS -s -w "%{http_code}" -o /dev/null \
  -X POST $BASE_URL:3001/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"autotest@example.com","password":"test123"}')

if [ "$LOGIN_STATUS" = "200" ]; then
    echo "OK Connexion ($LOGIN_STATUS)"
else
    echo "ERREUR Connexion ($LOGIN_STATUS)"
fi

echo "Suite de tests terminée"
```

### Script de Performance

```bash
#!/bin/bash
# performance-test.sh

echo "TESTS DE PERFORMANCE"
echo "======================"

BASE_URL="http://localhost"
CONCURRENT_USERS=5
REQUESTS_PER_USER=10

echo "Tests avec $CONCURRENT_USERS utilisateurs simultanés"
echo "Chaque utilisateur fait $REQUESTS_PER_USER requêtes"

# Test de charge sur health check
echo "Test de charge - Health Check..."
for i in $(seq 1 $CONCURRENT_USERS); do
    (
        for j in $(seq 1 $REQUESTS_PER_USER); do
            time curl -s http://localhost:3001/api/health > /dev/null
        done
    ) &
done

wait
echo "Test de charge terminé"

# Test de temps de réponse
echo "Tests de temps de réponse..."
ENDPOINTS=(
    "http://localhost:3001/api/health"
    "http://localhost:3000/api/health"
    "http://localhost:3002/api/health"
    "http://localhost:3000/api/products"
)

for endpoint in "${ENDPOINTS[@]}"; do
    time_total=$(curl -w "%{time_total}" -s -o /dev/null "$endpoint")
    printf "%-40s: %.3fs\n" "$endpoint" "$time_total"
done
```

---

## Troubleshooting

### Problèmes Courants et Solutions

#### Services qui ne Démarrent Pas

```bash
# Diagnostic complet
echo "DIAGNOSTIC SERVICES"

# Vérifier l'état des conteneurs
docker ps -a | grep -E "(ecommerce|frontend|mongo)"

# Vérifier les logs d'erreur
for service in auth products orders frontend; do
    echo "Logs $service"
    docker logs ecommerce-$service 2>&1 | tail -5
done

# Vérifier les ports occupés
echo "Ports utilisés"
ss -tlnp | grep -E ":(3001|3000|3002|8080|27017)\s"

# Vérifier l'espace disque
echo "Espace disque"
df -h /
docker system df
```

#### Problèmes de Base de Données

```bash
# Test de connectivité MongoDB
echo "TEST MONGODB"

# Vérifier que MongoDB répond
docker exec mongo-test mongosh --eval "db.adminCommand('ping')" \
  --username admin --password password --authenticationDatabase admin

# Lister les bases de données
docker exec mongo-test mongosh --eval "show dbs" \
  --username admin --password password --authenticationDatabase admin

# Test de connexion depuis les services
for service in auth products orders; do
    echo "Test connexion $service → MongoDB"
    docker exec ecommerce-$service nc -zv mongo-test 27017
done
```

#### Problèmes Réseau

```bash
# Diagnostic réseau Docker
echo "DIAGNOSTIC RÉSEAU"

# Lister les réseaux
docker network ls

# Inspecter le réseau e-commerce
docker network inspect ecommerce-network | jq '.[0].Containers'

# Test de connectivité inter-conteneurs
docker exec ecommerce-auth ping -c 3 ecommerce-products
docker exec ecommerce-products ping -c 3 ecommerce-orders
```

#### Problèmes SSL/HTTPS

```bash
# Diagnostic SSL
echo "DIAGNOSTIC SSL"

# Vérifier les certificats
if [ -f "ssl/server.crt" ]; then
    openssl x509 -in ssl/server.crt -text -noout | grep -E "(Subject|Issuer|Not After)"
fi

if [ -f "nginx/ssl/server.crt" ]; then
    openssl x509 -in nginx/ssl/server.crt -text -noout | grep -E "(Subject|Issuer|Not After)"
fi

# Test de connectivité SSL
openssl s_client -connect localhost:443 -servername localhost <<< "Q" | \
  grep -E "(SSL-Session|Verify return code)"
```

### Script de Nettoyage et Reset

```bash
#!/bin/bash
# reset-environment.sh

echo "NETTOYAGE DE L'ENVIRONNEMENT"
echo "==============================="

read -p "Êtes-vous sûr de vouloir tout nettoyer ? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
fi

# Arrêter tous les conteneurs
echo "Arrêt des conteneurs..."
docker compose down --remove-orphans

# Supprimer les conteneurs e-commerce
echo "Suppression des conteneurs..."
docker rm -f $(docker ps -aq --filter "name=ecommerce") 2>/dev/null || true

# Nettoyer les images non utilisées
echo "Nettoyage des images..."
docker image prune -f

# Nettoyer les volumes
echo "Nettoyage des volumes..."
docker volume prune -f

# Nettoyer les réseaux
echo "Nettoyage des réseaux..."
docker network prune -f

# Reset des données de test
echo "Reset des données de test..."
rm -f test-results.log performance-results.log

echo "Environnement nettoyé"
echo "Vous pouvez maintenant redémarrer avec: docker compose up -d"
```

---

## Utilisation des Scripts

### Rendre les Scripts Exécutables

```bash
# Créer le dossier tests
mkdir -p tests

# Copier les scripts dans le dossier tests
# (copiez le contenu des scripts ci-dessus)

# Rendre les scripts exécutables
chmod +x tests/*.sh
chmod +x scripts/*.sh
```

### Exécution des Tests

```bash
# Tests complets de développement
./tests/test-integration-dev.sh

# Tests de production
./tests/test-integration-prod.sh

# Tests automatisés
./tests/run-all-tests.sh dev
./tests/run-all-tests.sh prod verbose

# Tests de performance
./tests/performance-test.sh

# Reset de l'environnement
./tests/reset-environment.sh
```

---

## Rapports de Tests

### Génération de Rapport HTML

```bash
#!/bin/bash
# generate-test-report.sh

REPORT_FILE="test-report-$(date +%Y%m%d-%H%M%S).html"

cat > "$REPORT_FILE" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Rapport de Tests - E-commerce ESGI</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .success { color: #28a745; }
        .error { color: #dc3545; }
        .warning { color: #ffc107; }
        table { border-collapse: collapse; width: 100%; margin: 20px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <h1>Rapport de Tests E-commerce</h1>
    <p><strong>Date:</strong> $(date)</p>
    <p><strong>Environnement:</strong> Développement + Production</p>
    
    <h2>Résultats des Tests</h2>
    <table>
        <tr><th>Service</th><th>Endpoint</th><th>Statut</th><th>Temps</th></tr>
EOF

# Exécuter les tests et ajouter au rapport
ENDPOINTS=(
    "Auth:http://localhost:3001/api/health"
    "Products:http://localhost:3000/api/health"
    "Orders:http://localhost:3002/api/health"
    "Frontend:http://localhost:8080"
)

for endpoint_info in "${ENDPOINTS[@]}"; do
    IFS=':' read -r service_name url <<< "$endpoint_info"
    
    start_time=$(date +%s%N)
    status=$(curl -s -w "%{http_code}" -o /dev/null "$url" 2>/dev/null || echo "000")
    end_time=$(date +%s%N)
    duration=$(echo "scale=3; ($end_time - $start_time) / 1000000000" | bc)
    
    if [ "$status" = "200" ]; then
        status_class="success"
        status_text="OK $status"
    else
        status_class="error"
        status_text="ERREUR $status"
    fi
    
    cat >> "$REPORT_FILE" << EOF
        <tr>
            <td>$service_name</td>
            <td>$url</td>
            <td class="$status_class">$status_text</td>
            <td>${duration}s</td>
        </tr>
EOF
done

cat >> "$REPORT_FILE" << EOF
    </table>
    
    <h2>Informations Système</h2>
    <pre>$(docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}")</pre>
    
</body>
</html>
EOF

echo "Rapport généré: $REPORT_FILE"
```