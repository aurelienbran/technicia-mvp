# Guide de Déploiement de TechnicIA

Ce guide détaille les étapes pour déployer TechnicIA sur un VPS OVH. Le déploiement utilise Docker et Docker Compose pour faciliter l'installation et la gestion des différents services.

## Prérequis

- VPS OVH avec Ubuntu Server 22.04 LTS (8+ Go RAM, 4+ vCPUs, 100+ Go SSD)
- Nom de domaine (optionnel mais recommandé)
- Accès SSH au serveur avec privilèges sudo
- Clés API pour les services suivants :
  - Google Cloud Platform (Document AI et Vision AI)
  - VoyageAI
  - Anthropic (Claude)
  - (Optionnel) OpenAI

## 1. Préparation du Serveur

### Mise à jour du système

```bash
# Mettre à jour les packages
sudo apt update && sudo apt upgrade -y

# Installer les packages essentiels
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common git
```

### Installation de Docker et Docker Compose

```bash
# Ajouter la clé GPG de Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Ajouter le dépôt Docker
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Mettre à jour et installer Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io

# Installer Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.18.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Ajouter l'utilisateur actuel au groupe docker
sudo usermod -aG docker ${USER}

# Appliquer les changements sans déconnexion
newgrp docker
```

### Configuration du Pare-feu

```bash
# Installer UFW si ce n'est pas déjà fait
sudo apt install -y ufw

# Configurer les règles de base
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Autoriser SSH
sudo ufw allow 22/tcp

# Autoriser HTTP/HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Autoriser n8n
sudo ufw allow 5678/tcp

# Autoriser Qdrant
sudo ufw allow 6333/tcp

# Autoriser les microservices Python (si exposés directement)
sudo ufw allow 8001:8003/tcp

# Activer le pare-feu
sudo ufw enable
```

## 2. Déploiement de la Stack Docker

### Création de la Structure

```bash
# Créer les répertoires nécessaires
mkdir -p ~/technicia-mvp/{qdrant_storage,n8n_data,document-processor,vision-classifier,vector-store}
cd ~/technicia-mvp
```

### Configuration des Variables d'Environnement

Créez un fichier `.env` à la racine du projet :

```bash
cat > .env << 'EOF'
# Configuration Générale
DOMAIN=votre-domaine.com

# Google Cloud
GOOGLE_APPLICATION_CREDENTIALS=/app/credentials.json
DOCUMENT_AI_PROJECT=votre-projet-gcp
DOCUMENT_AI_LOCATION=us-central1
DOCUMENT_AI_PROCESSOR_ID=votre-processor-id

# Qdrant
QDRANT_HOST=qdrant
QDRANT_PORT=6333
COLLECTION_NAME=technicia

# API Keys
VOYAGE_API_KEY=votre-voyage-api-key
ANTHROPIC_API_KEY=votre-anthropic-api-key

# N8N
N8N_ENCRYPTION_KEY=votre-cle-encryption-secrete
WEBHOOK_TUNNEL_URL=https://votre-domaine.com/webhook/
EOF
```

### Docker Compose Principal

Créez un fichier `docker-compose.yml` à la racine du projet :

```bash
cat > docker-compose.yml << 'EOF'
version: '3'

services:
  qdrant:
    image: qdrant/qdrant:latest
    container_name: technicia-qdrant
    ports:
      - "6333:6333"
      - "6334:6334"
    volumes:
      - ./qdrant_storage:/qdrant/storage
    environment:
      - QDRANT_ALLOW_CORS=true
      - QDRANT_LOG_LEVEL=INFO
      - QDRANT_TELEMETRY_DISABLED=true
    restart: always
    deploy:
      resources:
        limits:
          memory: 4G

  n8n:
    image: n8nio/n8n:latest
    container_name: technicia-n8n
    ports:
      - "5678:5678"
    volumes:
      - ./n8n_data:/home/node/.n8n
      - ${GOOGLE_APPLICATION_CREDENTIALS}:/home/node/.n8n/google-credentials.json:ro
    environment:
      - N8N_HOST=${DOMAIN}
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
      - WEBHOOK_TUNNEL_URL=${WEBHOOK_TUNNEL_URL}
      - N8N_LOG_LEVEL=info
      - VOYAGE_API_KEY=${VOYAGE_API_KEY}
      - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
      - GOOGLE_APPLICATION_CREDENTIALS=/home/node/.n8n/google-credentials.json
      - DOCUMENT_AI_PROJECT=${DOCUMENT_AI_PROJECT}
      - DOCUMENT_AI_LOCATION=${DOCUMENT_AI_LOCATION}
      - DOCUMENT_AI_PROCESSOR_ID=${DOCUMENT_AI_PROCESSOR_ID}
      - QDRANT_HOST=${QDRANT_HOST}
      - QDRANT_PORT=${QDRANT_PORT}
      - COLLECTION_NAME=${COLLECTION_NAME}
    restart: always
    depends_on:
      - qdrant
    
  document-processor:
    build: ./document-processor
    container_name: technicia-document-processor
    ports:
      - "8001:8000"
    volumes:
      - ${GOOGLE_APPLICATION_CREDENTIALS}:/app/credentials.json:ro
    environment:
      - GOOGLE_APPLICATION_CREDENTIALS=/app/credentials.json
      - DOCUMENT_AI_PROJECT=${DOCUMENT_AI_PROJECT}
      - DOCUMENT_AI_LOCATION=${DOCUMENT_AI_LOCATION}
      - DOCUMENT_AI_PROCESSOR_ID=${DOCUMENT_AI_PROCESSOR_ID}
    restart: always
    
  vision-classifier:
    build: ./vision-classifier
    container_name: technicia-vision-classifier
    ports:
      - "8002:8000"
    volumes:
      - ${GOOGLE_APPLICATION_CREDENTIALS}:/app/credentials.json:ro
    environment:
      - GOOGLE_APPLICATION_CREDENTIALS=/app/credentials.json
    restart: always
    
  vector-store:
    build: ./vector-store
    container_name: technicia-vector-store
    ports:
      - "8003:8000"
    environment:
      - QDRANT_HOST=${QDRANT_HOST}
      - QDRANT_PORT=${QDRANT_PORT}
      - COLLECTION_NAME=${COLLECTION_NAME}
      - VOYAGE_API_KEY=${VOYAGE_API_KEY}
    restart: always
    depends_on:
      - qdrant

  nginx:
    image: nginx:latest
    container_name: technicia-nginx
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d
      - ./nginx/ssl:/etc/nginx/ssl
      - ./nginx/www:/usr/share/nginx/html
    restart: always
    depends_on:
      - n8n
      - document-processor
      - vision-classifier
      - vector-store
EOF
```

### Configuration NGINX (Proxy Inverse et HTTPS)

```bash
# Créer les répertoires pour NGINX
mkdir -p ~/technicia-mvp/nginx/{conf.d,ssl,www}

# Créer le fichier de configuration par défaut
cat > ~/technicia-mvp/nginx/conf.d/default.conf << 'EOF'
server {
    listen 80;
    server_name _;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name _;

    ssl_certificate /etc/nginx/ssl/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;

    # n8n
    location / {
        proxy_pass http://n8n:5678;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Document Processor Service
    location /api/document-processor/ {
        proxy_pass http://document-processor:8000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Vision Classifier Service
    location /api/vision-classifier/ {
        proxy_pass http://vision-classifier:8000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Vector Store Service
    location /api/vector-store/ {
        proxy_pass http://vector-store:8000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF
```

## 3. Configuration des Microservices

### Préparation des fichiers Google Cloud

Avant de déployer, vous devez télécharger un fichier de clé de compte de service depuis Google Cloud et le placer dans le répertoire racine :

```bash
# Le fichier JSON de clé doit être téléchargé manuellement et transféré sur le serveur
scp votre-fichier-credentials.json user@votre-vps:/chemin/vers/technicia-mvp/google-credentials.json

# Ajuster la variable d'environnement
sed -i "s|GOOGLE_APPLICATION_CREDENTIALS=.*|GOOGLE_APPLICATION_CREDENTIALS=$(pwd)/google-credentials.json|" .env
```

### Obtention d'un Certificat SSL

Si vous avez un nom de domaine, configurez SSL avec Let's Encrypt :

```bash
sudo apt install -y certbot

# Obtenir un certificat
sudo certbot certonly --standalone -d votre-domaine.com

# Copier les certificats pour NGINX
sudo cp /etc/letsencrypt/live/votre-domaine.com/fullchain.pem ~/technicia-mvp/nginx/ssl/
sudo cp /etc/letsencrypt/live/votre-domaine.com/privkey.pem ~/technicia-mvp/nginx/ssl/
sudo chown $USER:$USER ~/technicia-mvp/nginx/ssl/*.pem
```

## 4. Initialisation et Démarrage

Lancez l'ensemble des services avec Docker Compose :

```bash
cd ~/technicia-mvp
docker-compose up -d
```

## 5. Configuration des Workflows n8n

Une fois les services démarrés, vous pouvez accéder à l'interface n8n à l'adresse `https://votre-domaine.com` ou `http://votre-ip:5678`.

Pour importer les workflows :

1. Accédez à l'interface n8n
2. Cliquez sur "Workflows" dans le menu de gauche
3. Cliquez sur "Import from File" ou "Import from URL"
4. Sélectionnez les fichiers JSON des workflows à partir du dossier `/workflows` de ce repository

## 6. Configuration de Qdrant

Initialisez la collection Qdrant :

```bash
# Installer le client Python de Qdrant
pip install qdrant-client

# Exécuter le script d'initialisation
python3 - << 'EOF'
from qdrant_client import QdrantClient
from qdrant_client.http import models

# Connexion au client Qdrant
client = QdrantClient(host="localhost", port=6333)

# Vérifier si la collection existe déjà
collections = client.get_collections().collections
collection_names = [c.name for c in collections]

# Nom de la collection
collection_name = "technicia"

# Créer la collection si elle n'existe pas
if collection_name not in collection_names:
    client.create_collection(
        collection_name=collection_name,
        vectors_config=models.VectorParams(
            size=1024,  # Taille des vecteurs Voyage AI
            distance=models.Distance.COSINE
        ),
        optimizers_config=models.OptimizersConfigDiff(
            indexing_threshold=20000
        )
    )
    
    # Créer des index sur les métadonnées
    client.create_payload_index(
        collection_name=collection_name,
        field_name="metadata.type",
        field_schema=models.PayloadSchemaType.KEYWORD
    )
    
    client.create_payload_index(
        collection_name=collection_name,
        field_name="metadata.schema_type",
        field_schema=models.PayloadSchemaType.KEYWORD
    )
    
    print(f"Collection '{collection_name}' créée avec succès!")
else:
    print(f"Collection '{collection_name}' existe déjà.")
EOF
```

## 7. Surveillance et Maintenance

### Logs Docker

Pour consulter les logs de chaque service :

```bash
# Tous les services
docker-compose logs -f

# Service spécifique
docker-compose logs -f n8n
docker-compose logs -f document-processor
docker-compose logs -f vision-classifier
docker-compose logs -f vector-store
```

### Mise à jour des Services

Pour mettre à jour les services :

```bash
# Récupérer les dernières images
docker-compose pull

# Redémarrer les services
docker-compose down
docker-compose up -d
```

### Sauvegardes

Pour sauvegarder les données importantes :

```bash
# Sauvegarde de Qdrant
tar -czf qdrant_backup_$(date +%Y%m%d).tar.gz ./qdrant_storage

# Sauvegarde de n8n
tar -czf n8n_backup_$(date +%Y%m%d).tar.gz ./n8n_data
```

## Résolution des Problèmes Courants

### Problèmes de connexion à Qdrant

Si les services ne peuvent pas se connecter à Qdrant :

```bash
# Vérifier que Qdrant est en cours d'exécution
docker-compose ps qdrant

# Vérifier les logs
docker-compose logs qdrant

# Redémarrer le service
docker-compose restart qdrant
```

### Problèmes d'authentification Google Cloud

Si les services ne peuvent pas s'authentifier auprès de Google Cloud :

```bash
# Vérifier que le fichier de clé est correctement monté
docker-compose exec document-processor ls -la /app/credentials.json

# Vérifier les variables d'environnement
docker-compose exec document-processor env | grep GOOGLE
```

### Problèmes de certificat SSL

Si NGINX ne démarre pas à cause d'erreurs de certificat :

```bash
# Vérifier les certificats
ls -la ~/technicia-mvp/nginx/ssl/

# Renouveler les certificats
sudo certbot renew
sudo cp /etc/letsencrypt/live/votre-domaine.com/fullchain.pem ~/technicia-mvp/nginx/ssl/
sudo cp /etc/letsencrypt/live/votre-domaine.com/privkey.pem ~/technicia-mvp/nginx/ssl/
sudo chown $USER:$USER ~/technicia-mvp/nginx/ssl/*.pem

# Redémarrer NGINX
docker-compose restart nginx
```
