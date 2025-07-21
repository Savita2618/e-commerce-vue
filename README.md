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
│   ├── deploy.sh                    # Déploiement
│   ├── monitoring.sh                # Surveillance des services
│   └── init-products.sh             # Initialisation des données
├── monitoring/                       # Configuration monitoring
├── backup/                          # Sauvegardes
├── docker-compose.yml               # Configuration développement
├── docker-compose.prod.yml          # Configuration production (GITHUB)
├── docker-compose.prod.gitlab.yml   # Configuration production (GITLAB)
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
# - Configuration des variables d'environnement
# - Démarrage des services en production
# - Tests de santé des services
# - Affichage des logs et statuts

# Démarrage en production
docker compose -f docker-compose.prod.yml --env-file .env.prod up -d

# Vérification
docker compose -f docker-compose.prod.yml ps

# Monitoring
./scripts/monitoring.sh --env=prod
```


## Utilisation des Scripts


### deploy.sh - Déploiement automatisé
```bash
# Déploiement production avec script
./scripts/deploy.sh

# Le script gère automatiquement :
# - Configuration des variables d'environnement
# - Démarrage des services selon l'environnement
# - Vérification de la santé des services
# - Tests d'intégration automatiques
# - Affichage des informations de connexion

# Redémarrage des services
./scripts/deploy.sh --restart

# Utilisation avec registre spécifique
./scripts/deploy.sh github    # Utilise le registre GitHub
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


## Tests des Services

## Tests des Services

### Vérification des Logs et Conteneurs

#### Vérifier l'état des conteneurs
```bash
# Voir tous les conteneurs
docker ps -a
```

### Tests HTTP (Développement)

#### Auth Service (Port 3001)

**Health Check:**
```bash
curl http://localhost:3001/api/health
```

**Test Inscription:**
```bash
curl -X POST http://localhost:3001/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'
```

**Explication des paramètres curl :**
- `-X POST` : Utilise la méthode HTTP POST
- `-H "Content-Type: application/json"` : Indique que tu envoies du JSON
- `-d '{"email":"test@example.com","password":"password123"}'` : Corps de la requête en JSON
- `\` : Continuation de ligne pour lisibilité

**Test Connexion:**
```bash
curl -X POST http://localhost:3001/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'
```

**Sauvegarder le token pour les tests suivants:**
```bash
TOKEN=$(curl -s -X POST http://localhost:3001/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}' \
  | grep -o '"token":"[^"]*' | cut -d'"' -f4)

echo "Token sauvegardé: $TOKEN"
```

#### Product Service (Port 3000)

**Vérifier les logs:**
```bash
docker logs ecommerce-products | tail -10
```

**Test Health Check:**
```bash
curl http://localhost:3000/api/health
```

**Test Liste des Produits (vide au début):**
```bash
curl http://localhost:3000/api/products
```

**Créer un produit de test:**
```bash
curl -X POST http://localhost:3000/api/products \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer efrei_super_pass" \
  -d '{
    "name": "Produit Test",
    "price": 99.99,
    "description": "Description test",
    "stock": 10
  }'
```

**Vérifier que le produit est créé:**
```bash
curl http://localhost:3000/api/products
```

#### Tester le Panier

**Récupérer l'ID du produit créé:**
```bash
PRODUCT_ID=$(curl -s http://localhost:3000/api/products | grep -o '"_id":"[^"]*' | head -1 | cut -d'"' -f4)
echo "Product ID: $PRODUCT_ID"
```

**Ajouter au panier:**
```bash
curl -X POST http://localhost:3000/api/cart/add \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer efrei_super_pass" \
  -d '{
    "userId": "test-user-id",
    "productId": "'$PRODUCT_ID'",
    "quantity": 2
  }'
```

**Voir le panier:**
```bash
curl http://localhost:3000/api/cart \
  -H "Authorization: Bearer efrei_super_pass" \
  -H "userId: test-user-id"
```

#### Order Service (Port 3002)

**Vérifier les logs:**
```bash
docker logs ecommerce-orders | tail -10
```

**Test Health Check:**
```bash
curl http://localhost:3002/api/health
```

**Créer une commande (utiliser le token Auth et Product ID):**
```bash
curl -X POST http://localhost:3002/api/orders \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "products": [{
      "productId": "'$PRODUCT_ID'",
      "quantity": 1
    }],
    "shippingAddress": {
      "street": "123 Test Street",
      "city": "Test City",
      "postalCode": "12345"
    }
  }'
```

**Voir les commandes:**
```bash
curl http://localhost:3002/api/orders \
  -H "Authorization: Bearer $TOKEN"
```

#### Frontend (Port 8080)

**Vérifier les logs:**
```bash
docker logs ecommerce-frontend | tail -10
```

**Test accès frontend:**
```bash
curl -I http://localhost:8080
```

**Test accès frontend avec IP directe:**
```bash
curl -I http://172.18.0.6:8080/
```

### Tests HTTPS (Production)

#### Configuration SSL active avec IP 192.168.100.40

**Se connecter avec tes identifiants:**
```bash
TOKEN=$(curl -s -X POST http://192.168.100.40/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@email.com","password":"esgi123456"}' \
  | grep -o '"token":"[^"]*' | cut -d'"' -f4)
echo "Token récupéré: ${TOKEN:0:20}..."
```

**Voir toutes tes commandes:**
```bash
curl -s http://192.168.100.40/api/orders \
  -H "Authorization: Bearer $TOKEN" | jq '.'
```

**Dans la réponse JSON, l'ID complet de ta commande est :**
```json
"_id": "686e72fe49f64b39c85f5e24"
```

**Gestion des statuts de commande:**
```bash
# Utiliser l'ID complet de ta commande
ORDER_ID="686e72fe49f64b39c85f5e24"  # Remplace par l'ID réel si différent

# Confirmer la commande
curl -X PATCH http://192.168.100.40/api/orders/${ORDER_ID}/status \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"status": "confirmed"}'

# Marquer comme expédiée
curl -X PATCH http://192.168.100.40/api/orders/${ORDER_ID}/status \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"status": "shipped"}'

# Marquer comme livrée
curl -X PATCH http://192.168.100.40/api/orders/${ORDER_ID}/status \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"status": "delivered"}'
```

**Statuts possibles :**
- `pending` → En attente
- `confirmed` → Confirmée
- `shipped` → Expédiée
- `delivered` → Livrée
- `cancelled` → Annulée

#### Tests HTTPS sécurisés

**Health checks via HTTPS:**
```bash
curl -k https://192.168.100.40/api/auth/health
curl -k https://192.168.100.40/api/products/health
curl -k https://192.168.100.40/api/orders/health
```

**Test d'inscription via HTTPS:**
```bash
curl -k -X POST https://192.168.100.40/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'
```

**Test de connexion via HTTPS:**
```bash
TOKEN_HTTPS=$(curl -k -s -X POST https://192.168.100.40/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@email.com","password":"esgi123456"}' \
  | grep -o '"token":"[^"]*' | cut -d'"' -f4)
echo "Token HTTPS: ${TOKEN_HTTPS:0:20}..."
```

**Vérification du certificat SSL:**
```bash
openssl s_client -connect 192.168.100.40:443 -servername localhost
```

**Test de redirection HTTP vers HTTPS:**
```bash
curl -I http://192.168.100.40  # Devrait rediriger vers HTTPS
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
