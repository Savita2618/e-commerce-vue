# ===================================
# Dockerfile Frontend - Version Finale Corrigée
# Multi-stage : Build + Development + Production
# ===================================

# Stage 1: Build stage
FROM node:18-alpine AS build

# Arguments de build (reçus des secrets GitHub)
ARG VITE_AUTH_SERVICE_URL=/api/auth
ARG VITE_PRODUCT_SERVICE_URL=/api/products  
ARG VITE_ORDER_SERVICE_URL=/api/orders

WORKDIR /app

# Copier les fichiers de dépendances
COPY package*.json ./

# Installer toutes les dépendances (dev + prod pour Vite)
RUN npm ci && npm cache clean --force

# Copier tout le code source
COPY . .

# Variables d'environnement pour le build
ENV VITE_AUTH_SERVICE_URL=${VITE_AUTH_SERVICE_URL}
ENV VITE_PRODUCT_SERVICE_URL=${VITE_PRODUCT_SERVICE_URL}
ENV VITE_ORDER_SERVICE_URL=${VITE_ORDER_SERVICE_URL}

# Build l'application
RUN npm run build

# ===================================
# Stage 2: Development stage
# ===================================
FROM node:18-alpine AS development

# Installer curl pour healthcheck
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

# Variables d'environnement pour le développement
ENV HOST=0.0.0.0
ENV PORT=8080
ENV NODE_ENV=development

# Healthcheck
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:8080 || exit 1

# Commande pour le développement avec hot reload
CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0", "--port", "8080"]

# ===================================
# Stage 3: Production stage (NOMMÉ "production" !)
# ===================================
FROM nginx:alpine AS production

# Installer wget pour healthcheck
RUN apk add --no-cache wget

# Copier les fichiers buildés depuis le stage build
COPY --from=build /app/dist /usr/share/nginx/html

# Configuration nginx optimisée
RUN echo 'server { \
    listen 8080; \
    server_name localhost; \
    root /usr/share/nginx/html; \
    index index.html; \
    \
    # Gestion des routes SPA \
    location / { \
        try_files $uri $uri/ /index.html; \
    } \
    \
    # Cache pour les assets statiques \
    location ~* \.(css|js|jpg|jpeg|png|gif|ico|svg|woff|woff2|ttf|eot)$ { \
        expires 1y; \
        add_header Cache-Control "public, immutable"; \
    } \
    \
    # Headers de sécurité \
    add_header X-Frame-Options "SAMEORIGIN" always; \
    add_header X-Content-Type-Options "nosniff" always; \
    add_header X-XSS-Protection "1; mode=block" always; \
    \
    # Compression \
    gzip on; \
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml; \
}' > /etc/nginx/conf.d/default.conf

# Exposer le port
EXPOSE 8080

# Healthcheck
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080 || exit 1

# Commande pour la production
CMD ["nginx", "-g", "daemon off;"]