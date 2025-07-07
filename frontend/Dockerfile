# ===================================
# Dockerfile - Frontend Vue.js CORRIGÉ
# Multi-stage build : Dev et Production
# ===================================

# Stage 1: Build stage
FROM node:18-alpine AS build-stage

# Définir les arguments de build
ARG NODE_ENV=production
ARG VITE_AUTH_SERVICE_URL=/api/auth
ARG VITE_PRODUCT_SERVICE_URL=/api/products
ARG VITE_ORDER_SERVICE_URL=/api/orders

# Définir le répertoire de travail
WORKDIR /app

# Copier les fichiers de configuration des dépendances
COPY package*.json ./

# 🔧 CORRECTION: Installer TOUTES les dépendances (dev + prod) pour le build
RUN npm ci && npm cache clean --force

# Copier les fichiers de configuration Vite
COPY vite.config.js ./
COPY vitest.config.js ./
COPY index.html ./

# Copier le code source
COPY src/ ./src/
COPY public/ ./public/

# Construire l'application avec les variables d'environnement
ENV VITE_AUTH_SERVICE_URL=${VITE_AUTH_SERVICE_URL}
ENV VITE_PRODUCT_SERVICE_URL=${VITE_PRODUCT_SERVICE_URL}
ENV VITE_ORDER_SERVICE_URL=${VITE_ORDER_SERVICE_URL}

RUN npm run build

# ===================================
# Stage 2: Development stage
# ===================================
FROM node:18-alpine AS development

# Installer des outils de debug
RUN apk add --no-cache curl

WORKDIR /app

# Copier les fichiers de configuration
COPY package*.json ./
COPY vite.config.js ./
COPY vitest.config.js ./
COPY index.html ./

# Installer toutes les dépendances (dev + prod)
RUN npm ci && npm cache clean --force

# Copier le code source
COPY . .

# Exposer le port
EXPOSE 8080

# Configuration Vite pour accepter les connexions externes
ENV HOST=0.0.0.0
ENV PORT=8080

# Healthcheck
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:8080 || exit 1

# Commande pour le développement
CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0", "--port", "8080"]

# ===================================
# Stage 3: Production stage (Nginx simple)
# ===================================
FROM nginx:alpine AS production

# Copier les fichiers construits depuis le build stage
COPY --from=build-stage /app/dist /usr/share/nginx/html

# Créer une configuration nginx simple
RUN echo 'server { \
    listen 8080; \
    server_name localhost; \
    root /usr/share/nginx/html; \
    index index.html; \
    location / { \
        try_files $uri $uri/ /index.html; \
    } \
    location /api/ { \
        proxy_pass http://nginx-proxy:80; \
        proxy_set_header Host $host; \
        proxy_set_header X-Real-IP $remote_addr; \
    } \
}' > /etc/nginx/conf.d/default.conf

# Exposer le port
EXPOSE 8080

# Healthcheck
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080 || exit 1

# Commande pour la production
CMD ["nginx", "-g", "daemon off;"]