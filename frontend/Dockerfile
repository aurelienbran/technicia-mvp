# Stage de construction
FROM node:18-alpine as build

WORKDIR /app

# Copie des fichiers package.json et package-lock.json (si disponible)
COPY package*.json ./

# Installation des dépendances avec npm install (plus tolérant que npm ci)
RUN npm install

# Copie du code source
COPY . ./

# Construction de l'application
RUN npm run build

# Stage de production
FROM nginx:alpine

# Copie des fichiers de build vers le dossier de Nginx
COPY --from=build /app/build /usr/share/nginx/html

# Copie de la configuration de Nginx
COPY nginx/nginx.conf /etc/nginx/conf.d/default.conf

# Exposition du port 80
EXPOSE 80

# Démarrage de Nginx
CMD ["nginx", "-g", "daemon off;"]