# ===================================
# Dockerfile - Auth Service
# Multi-stage build : Dev et Production
# ===================================

# Stage 1: Base stage
FROM node:18-alpine AS base

# Créer un utilisateur non-root
RUN addgroup -g 1001 -S nodegroup && \
    adduser -S nodeuser -u 1001 -G nodegroup

# Installer les dépendances système nécessaires
RUN apk add --no-cache \
    dumb-init \
    tini

# Définir le répertoire de travail
WORKDIR /app

# Copier les fichiers de configuration des dépendances
COPY package*.json ./

# Stage 2: Dependencies stage
FROM base AS dependencies

# Installer toutes les dépendances
RUN npm ci && npm cache clean --force

# Stage 3: Development stage
FROM dependencies AS development

# Copier le code source
COPY --chown=nodeuser:nodegroup . .

# Changer vers l'utilisateur non-root
USER nodeuser

# Exposer le port
EXPOSE 3001

# Variables d'environnement pour le développement
ENV NODE_ENV=development
ENV PORT=3001

# Commande pour le développement avec nodemon
CMD ["npm", "run", "dev"]

# Stage 4: Production build stage
FROM dependencies AS build

# Copier le code source
COPY --chown=nodeuser:nodegroup . .

# Installer uniquement les dépendances de production
RUN npm ci --only=production && npm cache clean --force

# Stage 5: Production stage
FROM node:18-alpine AS production

# Installer tini pour une gestion propre des signaux
RUN apk add --no-cache tini

# Créer un utilisateur non-root
RUN addgroup -g 1001 -S nodegroup && \
    adduser -S nodeuser -u 1001 -G nodegroup

WORKDIR /app

# Copier les dépendances et le code depuis le build stage
COPY --from=build --chown=nodeuser:nodegroup /app/node_modules ./node_modules
COPY --from=build --chown=nodeuser:nodegroup /app/src ./src
COPY --from=build --chown=nodeuser:nodegroup /app/package*.json ./

# Changer vers l'utilisateur non-root
USER nodeuser

# Exposer le port
EXPOSE 3001

# Variables d'environnement pour la production
ENV NODE_ENV=production
ENV PORT=3001

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3001/api/health', (res) => { process.exit(res.statusCode === 200 ? 0 : 1) })" || exit 1

# Utiliser tini comme point d'entrée
ENTRYPOINT ["/sbin/tini", "--"]

# Commande pour la production
CMD ["npm", "start"]