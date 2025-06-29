# ===================================
# Dockerfile - Frontend Vue.js
# Multi-stage build : Dev et Production
# ===================================

# Stage 1: Build stage
FROM node:18-alpine AS build-stage

# Définir les arguments de build
ARG NODE_ENV=production
ARG VITE_AUTH_SERVICE_URL
ARG VITE_PRODUCT_SERVICE_URL  
ARG VITE_ORDER_SERVICE_URL

# Créer un utilisateur non-root
RUN addgroup -g 1001 -S nodegroup && \
    adduser -S nodeuser -u 1001 -G nodegroup

# Définir le répertoire de travail
WORKDIR /app

# Copier les fichiers de configuration des dépendances
COPY package*.json ./
COPY vitest.config.js ./
COPY vite.config.js ./

# Installer les dépendances
RUN npm ci --only=production && \
    npm cache clean --force

# Copier le code source
COPY --chown=nodeuser:nodegroup . .

# Construire l'application
RUN npm run build

# Stage 2: Development stage  
FROM node:18-alpine AS development

# Créer un utilisateur non-root
RUN addgroup -g 1001 -S nodegroup && \
    adduser -S nodeuser -u 1001 -G nodegroup

WORKDIR /app

# Copier les fichiers de configuration
COPY package*.json ./
COPY vitest.config.js ./
COPY vite.config.js ./

# Installer toutes les dépendances (dev + prod)
RUN npm ci && npm cache clean --force

# Copier le code source
COPY --chown=nodeuser:nodegroup . .

# Changer vers l'utilisateur non-root
USER nodeuser

# Exposer le port
EXPOSE 8080

# Commande pour le développement
CMD ["npm", "run", "dev"]

# Stage 3: Production stage
FROM nginx:alpine AS production

# Installer Node.js pour le serveur proxy
RUN apk add --no-cache nodejs npm

# Créer un utilisateur non-root
RUN addgroup -g 1001 -S appgroup && \
    adduser -S appuser -u 1001 -G appgroup

# Copier les fichiers construits depuis le build stage
COPY --from=build-stage /app/dist /usr/share/nginx/html

# Copier le serveur proxy pour la production
COPY --from=build-stage /app/server.cjs /app/server.cjs
COPY --from=build-stage /app/package*.json /app/

# Installer les dépendances du serveur
WORKDIR /app
RUN npm ci --only=production && npm cache clean --force

# Copier la configuration nginx personnalisée
COPY nginx.conf /etc/nginx/nginx.conf

# Créer les répertoires nécessaires avec les bonnes permissions
RUN mkdir -p /var/cache/nginx /var/run && \
    chown -R appuser:appgroup /var/cache/nginx /var/run /usr/share/nginx/html /app

# Changer vers l'utilisateur non-root
USER appuser

# Exposer le port
EXPOSE 8080

# Commande pour la production (serveur Node.js avec proxy)
CMD ["node", "server.cjs"]