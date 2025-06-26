FROM node:18-alpine AS base

# Installation des dépendances système nécessaires
RUN apk add --no-cache \
    dumb-init \
    curl \
    && rm -rf /var/cache/apk/*

# Création du répertoire de travail
WORKDIR /app

# Création d'un utilisateur non-root
RUN addgroup -g 1001 -S nodejs && \
    adduser -S orderuser -u 1001 -G nodejs

# Stage: Development
FROM base AS development

# Installation de nodemon pour le hot-reload
RUN npm install -g nodemon

# Copie des fichiers de dépendances
COPY package*.json ./

# Installation des dépendances (dev + prod)
RUN npm ci --silent

# Copie du code source
COPY . .

# Changement des permissions
RUN chown -R orderuser:nodejs /app
USER orderuser

# Exposition du port
EXPOSE 3002

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3002/api/health || exit 1

# Commande de développement
CMD ["dumb-init", "nodemon", "src/server.js"]

# Stage: Production
FROM base AS production

# Copie des fichiers de dépendances
COPY package*.json ./

# Installation des dépendances de production uniquement
RUN npm ci --only=production --silent && \
    npm cache clean --force

# Copie du code source
COPY . .

# Changement des permissions
RUN chown -R orderuser:nodejs /app
USER orderuser

# Exposition du port
EXPOSE 3002

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3002/api/health || exit 1

# Commande de production
CMD ["dumb-init", "node", "src/server.js"]