# =============================================================================
# frontend/Dockerfile - Multi-stage build pour Vue.js
# =============================================================================

# Stage 1: Base pour le développement et la construction
FROM node:18-alpine AS base
WORKDIR /app

# Installation des dépendances système
RUN apk add --no-cache git

# Copie des fichiers de dépendances
COPY package*.json ./
RUN npm ci --only=production --silent && npm cache clean --force

# Stage 2: Développement avec hot-reload
FROM base AS development
WORKDIR /app

# Installation de toutes les dépendances (dev + prod)
RUN npm ci --silent

# Copie du code source
COPY . .

# Création d'un utilisateur non-root pour la sécurité
RUN addgroup -g 1001 -S nodejs && \
    adduser -S vuejs -u 1001 -G nodejs

# Changement des permissions
RUN chown -R vuejs:nodejs /app
USER vuejs

# Exposition du port de développement
EXPOSE 5173

# Commande de développement avec hot-reload
CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0"]

# Stage 3: Construction pour la production
FROM base AS builder
WORKDIR /app

# Installation des dépendances de développement nécessaires au build
RUN npm ci --silent

# Copie du code source
COPY . .

# Construction de l'application
RUN npm run build

# Stage 4: Production avec Nginx
FROM nginx:1.25-alpine AS production

# Installation de curl pour les health checks
RUN apk add --no-cache curl

# Copie de la configuration Nginx personnalisée
COPY nginx.conf /etc/nginx/nginx.conf

# Copie des fichiers construits depuis le stage builder
COPY --from=builder /app/dist /usr/share/nginx/html

# Création d'un utilisateur non-root
RUN addgroup -g 1001 -S nginx && \
    adduser -S nginx -u 1001 -G nginx

# Configuration des permissions
RUN chown -R nginx:nginx /usr/share/nginx/html && \
    chown -R nginx:nginx /var/cache/nginx && \
    chown -R nginx:nginx /var/log/nginx && \
    chown -R nginx:nginx /etc/nginx/conf.d
RUN touch /var/run/nginx.pid && \
    chown -R nginx:nginx /var/run/nginx.pid

# Changement vers l'utilisateur non-root
USER nginx

# Exposition du port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

# Commande de démarrage
CMD ["nginx", "-g", "daemon off;"]