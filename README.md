# E-commerce Vue.js - Projet Docker ESGI

## Description

Application e-commerce complète développée avec une architecture microservices containerisée avec Docker. Le projet utilise Vue.js pour le frontend et Node.js/Express pour les services backend, avec MongoDB comme base de données pour chaque microservice.

## Architecture du Projet

### Services
- **Frontend Vue.js** (Port 8080) - Interface utilisateur
- **Auth Service** (Port 3001) - Service d'authentification JWT  
- **Product Service** (Port 3000) - Gestion des produits et panier
- **Order Service** (Port 3002) - Gestion des commandes
- **MongoDB** - Base de données pour chaque service
- **Nginx** - Reverse proxy (production uniquement)

### Communication
- Frontend ↔ Services backend via API REST
- Authentification JWT entre les services
- Communication interne Docker via réseau bridge

## Structure des Dossiers

```
e-commerce-vue/
├── frontend/                          # Application Vue.js
│   ├── src/                          # Code source frontend
│   ├── public/                       # Assets statiques
│   ├── Dockerfile                    # Multi-stage (build/dev/prod)
│   ├── nginx.conf                    # Configuration Nginx
│   ├── package.json
│   └── vite.config.js
├── services/                         # Microservices backend
│   ├── auth-service/                 # Service authentification
│   │   ├── src/
│   │   │   ├── app.js               # Point d'entrée
│   │   │   ├── controllers/         # Logique métier
│   │   │   ├── models/              # Modèles MongoDB
│   │   │   ├── routes/              # Routes API
│   │   │   └── middleware/          # Middleware JWT
│   │   ├── tests/                   # Tests unitaires
│   │   ├── Dockerfile               # Multi-stage
│   │   └── package.json
│   ├── product-service/              # Service produits
│   │   ├── src/
│   │   │   ├── app.js
│   │   │   ├── controllers/         # Product + Cart controllers
│   │   │   ├── models/              # Product + Cart models
│   │   │   └── routes/              # Product + Cart routes
│   │   ├── tests/
│   │   ├── Dockerfile
│   │   └── package.json
│   └── order-service/                # Service commandes
│       ├── src/
│       │   ├── app.js
│       │   ├── controllers/         # Order controller
│       │   ├── models/              # Order model
│       │   └── routes/              # Order routes
│       ├── tests/
│       ├── Dockerfile
│       └── package.json
├── nginx/                            # Configuration Nginx
│   ├── nginx.conf                   # Config production avec SSL
│   └── backup/                      # Configs alternatives
├── ssl/                             # Certificats SSL (production)
├── scripts/                         # Scripts d'automatisation
│   ├── setup.sh                     # Installation environnement
│   ├── run-tests.sh                 # Exécution des tests
│   ├── deploy.sh                    # Déploiement PM2
│   ├── monitoring.sh                # Surveillance des services
│   └── init-products.sh             # Initialisation des données
├── monitoring/                       # Configuration monitoring
├── backup/                          # Sauvegardes
├── docker-compose.yml               # Configuration développement
├── docker-compose.prod.yml          # Configuration production
├── docker-compose.prod.gitlab.yml   # Configuration GitLab CI/CD
├── docker-compose.prod.gitlab.yml   # Configuration GitLab CI/CD
├── .env.example                     # Variables d'environnement
├── .gitlab-ci.yml                   # Pipeline GitLab CI/CD
├── .dockerignore
├── .gitignore
└── README.md
```

## Prérequis Système

### Debian 12 (Compatible)

#### Installation Docker Compose v2
```bash
# Mise à jour du système
sudo apt update && sudo apt upgrade -y

# Installation des dépendances
sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release

# Ajout de la clé GPG Docker
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Ajout du repository Docker
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Installation Docker Engine et Compose v2
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Vérification des versions
docker --version
docker compose version

# Ajout de l'utilisateur au groupe docker
sudo usermod -aG docker $USER
newgrp docker
```

#### Installation Node.js (LTS)
```bash
# Installation via NodeSource (recommandé)
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt install -y nodejs

# Ou via Snap (alternative)
sudo snap install node --classic

# Vérification
node --version
npm --version
```

#### Outils additionnels
```bash
# Outils de développement
sudo apt install -y git curl wget vim nano htop tree jq

# PM2 pour déploiement manuel (optionnel)
sudo npm install -g pm2
```

## Configuration des Environnements

### Branche `develop` (Développement)

#### Variables d'environnement (.env)
```bash
# Copier le template
cp .env.example .env

# Variables principales
NODE_ENV=development
COMPOSE_PROJECT_NAME=ecommerce-dev
IMAGE_TAG=develop

# Base de données
MONGO_ROOT_USERNAME=admin
MONGO_ROOT_PASSWORD=password

# Sécurité
JWT_SECRET=your_jwt_secret_key_here

# URLs des services (développement)
VITE_AUTH_SERVICE_URL=http://localhost:3001
VITE_PRODUCT_SERVICE_URL=http://localhost:3000
VITE_ORDER_SERVICE_URL=http://localhost:3002
```

#### Lancement du développement
```bash
# Installation des dépendances
./scripts/setup.sh

# Démarrage des services
docker compose up -d

# Vérification des conteneurs
docker compose ps

# Suivi des logs
docker compose logs -f

# Arrêt des services
docker compose down
```

### Branche `main` (Production)

#### Configuration SSL

##### Utilisation du script automatisé (Recommandé)
```bash
# Génération automatique des certificats SSL
./scripts/setup-ssl.sh

# Le script génère automatiquement :
# - nginx/ssl/server.crt (certificat)
# - nginx/ssl/server.key (clé privée)
# - Configuration nginx avec SSL activé
```

##### Configuration manuelle des certificats (alternative)
```bash
# Création du dossier SSL
mkdir -p ssl

# Génération du certificat auto-signé
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout ssl/server.key \
  -out ssl/server.crt \
  -subj "/C=FR/ST=IDF/L=Paris/O=ESGI/OU=IT/CN=localhost"

# Permissions appropriées
sudo chmod 600 ssl/server.key
sudo chmod 644 ssl/server.crt
```

##### Certificats Let's Encrypt (production réelle)
```bash
# Installation Certbot
sudo apt install -y certbot python3-certbot-nginx

# Génération du certificat (remplacer votre-domaine.com)
sudo certbot --nginx -d votre-domaine.com

# Renouvellement automatique
sudo crontab -e
# Ajouter : 0 12 * * * /usr/bin/certbot renew --quiet
```

#### Variables d'environnement production (.env.prod)
```bash
NODE_ENV=production
COMPOSE_PROJECT_NAME=ecommerce-prod
IMAGE_TAG=latest

# Base de données sécurisée
MONGO_ROOT_USERNAME=admin
MONGO_ROOT_PASSWORD=strong_production_password

# JWT sécurisé
JWT_SECRET=very_strong_jwt_secret_key_production

# URLs des services (production)
VITE_AUTH_SERVICE_URL=/api/auth
VITE_PRODUCT_SERVICE_URL=/api/products
VITE_ORDER_SERVICE_URL=/api/orders

# SSL
SSL_CERT_PATH=/app/ssl/server.crt
SSL_KEY_PATH=/app/ssl/server.key
```

#### Déploiement avec GitLab CI/CD

Le projet inclut un fichier spécifique pour GitLab CI/CD :

```bash
# Configuration automatique via GitLab CI/CD
# Le pipeline utilise docker-compose.prod.gitlab.yml

# Variables GitLab CI/CD requises :
# - CI_REGISTRY_IMAGE : URL du registry GitLab
# - IMAGE_TAG : Tag des images (automatique)
# - JWT_SECRET : Secret JWT pour production
# - MONGO_ROOT_USERNAME : Utilisateur MongoDB
# - MONGO_ROOT_PASSWORD : Mot de passe MongoDB

# Le déploiement automatique utilise :
docker-compose -f docker-compose.prod.gitlab.yml up -d

# Avec les variables d'environnement GitLab injectées automatiquement
```

#### Déploiement production avec Docker Compose

```bash
# Méthode 1 : Script automatisé (Recommandé)
./scripts/deploy.sh

# Le script deploy.sh gère automatiquement :
# - Sélection du registre (local/gitlab)
# - Configuration des variables d'environnement
# - Démarrage des services en production
# - Tests de santé des services
# - Affichage des logs et statuts

# Méthode 2 : Manuel
# Configuration des secrets Docker
./scripts/init-secrets.sh

# Démarrage en production
docker compose -f docker-compose.prod.yml --env-file .env.prod up -d

# Vérification
docker compose -f docker-compose.prod.yml ps

# Monitoring
./scripts/monitoring.sh --env=prod
```

#### Déploiement avec Docker Swarm (Bonus)

```bash
# Initialiser Docker Swarm
docker swarm init

# Déployer la Stack
docker stack deploy -c docker-compose.prod.yml e-commerce

# Vérifier le déploiement
docker stack services e-commerce
```

## Utilisation des Scripts

### setup.sh - Installation et configuration
```bash
# Installation complète de l'environnement
./scripts/setup.sh

# Options disponibles
./scripts/setup.sh --help
./scripts/setup.sh --dev      # Configuration développement
./scripts/setup.sh --prod     # Configuration production
./scripts/setup.sh --clean    # Nettoyage complet
```

### run-tests.sh - Tests automatisés
```bash
# Exécution de tous les tests
./scripts/run-tests.sh

# Tests par service
./scripts/run-tests.sh --service=auth
./scripts/run-tests.sh --service=product
./scripts/run-tests.sh --service=order
./scripts/run-tests.sh --service=frontend

# Tests d'intégration
./scripts/run-tests.sh --integration

# Tests avec couverture
./scripts/run-tests.sh --coverage
```

### deploy.sh - Déploiement automatisé
```bash
# Déploiement production avec script
./scripts/deploy.sh

# Le script gère automatiquement :
# - Détection du type de registre (local/gitlab)
# - Configuration des variables d'environnement
# - Démarrage des services selon l'environnement
# - Vérification de la santé des services
# - Tests d'intégration automatiques
# - Affichage des informations de connexion

# Redémarrage des services
./scripts/deploy.sh --restart

# Utilisation avec registre spécifique
./scripts/deploy.sh local    # Utilise les images locales
./scripts/deploy.sh gitlab   # Utilise le registre GitLab
```

### setup-ssl.sh - Configuration SSL
```bash
# Configuration SSL automatique
./scripts/setup-ssl.sh

# Le script :
# - Génère les certificats auto-signés
# - Configure nginx avec SSL
# - Valide la configuration
# - Teste les connexions HTTPS
# - Sauvegarde la config précédente
```

### monitoring.sh - Surveillance des services
```bash
# Monitoring développement
./scripts/monitoring.sh --env=dev

# Monitoring production
./scripts/monitoring.sh --env=prod

# Monitoring spécifique
./scripts/monitoring.sh --service=auth
./scripts/monitoring.sh --logs
./scripts/monitoring.sh --metrics
```

### deploy.sh - Déploiement PM2
```bash
# Déploiement avec PM2 (pré-production)
./scripts/deploy.sh

# Redémarrage des services
./scripts/deploy.sh --restart

# Arrêt des services
./scripts/deploy.sh --stop
```

## Tests des Services

### Tests HTTP (Développement)

#### Auth Service (Port 3001)
```bash
# Health check
curl -X GET http://localhost:3001/api/health

# Inscription utilisateur
curl -X POST http://localhost:3001/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123",
    "name": "Test User"
  }'

# Connexion utilisateur
curl -X POST http://localhost:3001/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123"
  }'

# Profil utilisateur (avec token)
curl -X GET http://localhost:3001/api/auth/profile \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

#### Product Service (Port 3000)
```bash
# Health check
curl -X GET http://localhost:3000/api/health

# Liste des produits
curl -X GET http://localhost:3000/api/products

# Détail d'un produit
curl -X GET http://localhost:3000/api/products/:id

# Ajouter au panier (avec token)
curl -X POST http://localhost:3000/api/cart \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "productId": "product_id_here",
    "quantity": 2
  }'

# Voir le panier
curl -X GET http://localhost:3000/api/cart \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

#### Order Service (Port 3002)
```bash
# Health check
curl -X GET http://localhost:3002/api/health

# Créer une commande (avec token)
curl -X POST http://localhost:3002/api/orders \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "items": [
      {
        "productId": "product_id_here",
        "quantity": 1,
        "price": 29.99
      }
    ],
    "total": 29.99
  }'

# Historique des commandes
curl -X GET http://localhost:3002/api/orders \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

#### Frontend (Port 8080)
```bash
# Health check
curl -X GET http://localhost:8080

# Vérification du build
curl -X GET http://localhost:8080/assets/

# Test de routage SPA
curl -X GET http://localhost:8080/login
curl -X GET http://localhost:8080/products
```

### Tests HTTPS (Production)

#### Configuration SSL active

```bash
# Health check sécurisé
curl -k -X GET https://localhost/api/health

# Auth service via Nginx
curl -k -X POST https://localhost/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123"
  }'

# Product service via Nginx
curl -k -X GET https://localhost/api/products

# Order service via Nginx
curl -k -X GET https://localhost/api/orders \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"

# Frontend sécurisé
curl -k -X GET https://localhost/

# Vérification du certificat
openssl s_client -connect localhost:443 -servername localhost
```

### Tests d'intégration complets

```bash
#!/bin/bash
# Test complet de l'application

echo "Test d'intégration E-commerce"

# Variables
BASE_URL="http://localhost"
if [ "$1" = "--https" ]; then
  BASE_URL="https://localhost"
  CURL_OPTS="-k"
fi

# 1. Vérifier que tous les services sont up
echo "1. Health checks..."
curl $CURL_OPTS -f $BASE_URL:3001/api/health || exit 1
curl $CURL_OPTS -f $BASE_URL:3000/api/health || exit 1  
curl $CURL_OPTS -f $BASE_URL:3002/api/health || exit 1
curl $CURL_OPTS -f $BASE_URL:8080/ || exit 1

# 2. Inscription
echo "2. Inscription utilisateur..."
REGISTER_RESPONSE=$(curl $CURL_OPTS -s -X POST $BASE_URL:3001/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "integration@test.com",
    "password": "test123",
    "name": "Integration Test"
  }')

echo "Réponse inscription: $REGISTER_RESPONSE"

# 3. Connexion
echo "3. Connexion utilisateur..."
LOGIN_RESPONSE=$(curl $CURL_OPTS -s -X POST $BASE_URL:3001/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "integration@test.com", 
    "password": "test123"
  }')

TOKEN=$(echo $LOGIN_RESPONSE | jq -r '.token')
echo "Token récupéré: $TOKEN"

# 4. Liste des produits
echo "4. Récupération des produits..."
PRODUCTS_RESPONSE=$(curl $CURL_OPTS -s -X GET $BASE_URL:3000/api/products)
FIRST_PRODUCT_ID=$(echo $PRODUCTS_RESPONSE | jq -r '.[0]._id')
echo "Premier produit ID: $FIRST_PRODUCT_ID"

# 5. Ajout au panier
echo "5. Ajout au panier..."
CART_RESPONSE=$(curl $CURL_OPTS -s -X POST $BASE_URL:3000/api/cart \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{
    \"productId\": \"$FIRST_PRODUCT_ID\",
    \"quantity\": 1
  }")

echo "Réponse panier: $CART_RESPONSE"

# 6. Création commande
echo "6. Création de commande..."
ORDER_RESPONSE=$(curl $CURL_OPTS -s -X POST $BASE_URL:3002/api/orders \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "items": [
      {
        "productId": "'$FIRST_PRODUCT_ID'",
        "quantity": 1,
        "price": 29.99
      }
    ],
    "total": 29.99
  }')

echo "Réponse commande: $ORDER_RESPONSE"

echo "Test d'intégration terminé avec succès !"
```

## Pipeline GitLab CI/CD

### Branches et Workflow

- **develop** : Environnement de développement, déploiement automatique
- **main** : Environnement de production, déploiement manuel
- **feature/** : Branches de fonctionnalités, tests uniquement
- **hotfix/** : Corrections urgentes, déploiement rapide

### Jobs du Pipeline

1. **validate** : Vérification de la structure du projet
2. **build** : Construction des images Docker pour chaque service
3. **test** : Tests unitaires et d'intégration
4. **security** : Scan de sécurité avec Trivy
5. **integration** : Tests d'intégration complets
6. **deploy** : Déploiement automatique (develop) ou manuel (main)

### Variables GitLab CI/CD Required

```
CI_REGISTRY_IMAGE: Registry Docker GitLab
JWT_SECRET: Secret pour les tokens JWT
MONGO_ROOT_USERNAME: Utilisateur MongoDB
MONGO_ROOT_PASSWORD: Mot de passe MongoDB  
IMAGE_TAG: Tag des images (auto ou latest)
```

## Monitoring et Logs

### Logs des services
```bash
# Logs en temps réel (développement)
docker compose logs -f

# Logs par service
docker compose logs -f frontend
docker compose logs -f auth-service
docker compose logs -f product-service  
docker compose logs -f order-service

# Logs production
docker compose -f docker-compose.prod.yml logs -f

# Logs avec timestamps
docker compose logs -f -t
```

### Métriques et surveillance
```bash
# Statut des conteneurs
docker compose ps

# Utilisation des ressources
docker stats

# Espace disque
docker system df

# Nettoyage
docker system prune -f
```

## Résolution des Problèmes Courants

### Problèmes de ports
```bash
# Vérifier les ports occupés
sudo netstat -tulpn | grep :3000
sudo netstat -tulpn | grep :3001
sudo netstat -tulpn | grep :3002
sudo netstat -tulpn | grep :8080

# Libérer un port
sudo kill -9 $(sudo lsof -t -i:3000)
```

### Problèmes de permissions Docker
```bash
# Ajouter l'utilisateur au groupe docker
sudo usermod -aG docker $USER
newgrp docker

# Redémarrer le service Docker
sudo systemctl restart docker
```

### Problèmes de base de données
```bash
# Réinitialiser les données MongoDB
docker compose down -v
docker compose up -d

# Connexion à MongoDB pour debug
docker exec -it mongodb-auth mongo -u admin -p password
```

### Problèmes de certificats SSL
```bash
# Vérifier les permissions
ls -la ssl/
sudo chown -R $USER:$USER ssl/
sudo chmod 600 ssl/server.key
sudo chmod 644 ssl/server.crt

# Tester le certificat
openssl x509 -in ssl/server.crt -text -noout
```

## Performance et Optimisation

### Images Docker
- Utilisation d'images Alpine Linux (plus légères)
- Multi-stage builds pour réduire la taille finale
- .dockerignore optimisé pour exclure les fichiers inutiles
- Cache des layers Docker pour builds plus rapides

### Base de données
- Index MongoDB pour améliorer les performances
- Connection pooling configuré
- Limitation des connexions par service

### Frontend
- Build optimisé avec Vite
- Compression gzip activée
- Cache des assets statiques
- Lazy loading des composants

## Sécurité

### Authentification
- JWT avec expiration configurée
- Hachage bcrypt pour les mots de passe
- Protection CSRF activée
- Rate limiting sur les endpoints sensibles

### Container Security
- Utilisateurs non-root dans tous les conteneurs
- Secrets Docker pour les données sensibles
- Scan de sécurité automatique avec Trivy
- Images mises à jour régulièrement

### Network Security
- Réseau Docker isolé pour les services
- Ports exposés uniquement si nécessaire
- SSL/TLS en production
- Pare-feu configuré sur le serveur

## Support et Contact

- **Repository GitHub** : https://github.com/Savita2618/e-commerce-vue
- **Repository GitLab** : https://gitlab.com/Savita2618/e-commerce-docker-esgi
- **Projet ESGI** : M1 Systèmes, Réseaux et Cloud Computing
- **Année** : 2024-2025
