# ===================================
# Dockerfile Frontend - Version Ultra Simple
# ===================================

FROM node:18-alpine AS build

ARG VITE_AUTH_SERVICE_URL=/api/auth
ARG VITE_PRODUCT_SERVICE_URL=/api/products  
ARG VITE_ORDER_SERVICE_URL=/api/orders

WORKDIR /app

# Copier les fichiers de dépendances
COPY package*.json ./

# Installer toutes les dépendances (dev + prod)
RUN npm ci

# Copier tout le code source
COPY . .

# Variables d'environnement pour le build
ENV VITE_AUTH_SERVICE_URL=${VITE_AUTH_SERVICE_URL}
ENV VITE_PRODUCT_SERVICE_URL=${VITE_PRODUCT_SERVICE_URL}
ENV VITE_ORDER_SERVICE_URL=${VITE_ORDER_SERVICE_URL}

# Build
RUN npm run build

# Production
FROM nginx:alpine

COPY --from=build /app/dist /usr/share/nginx/html

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]