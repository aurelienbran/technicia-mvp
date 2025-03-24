#!/bin/bash
# Script de configuration HTTPS automatique pour TechnicIA

# Couleurs pour les logs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Vérification des arguments
if [ $# -lt 1 ]; then
    echo -e "${RED}Usage: $0 <domaine> [email]${NC}"
    echo -e "  domaine : Nom de domaine pour le certificat SSL"
    echo -e "  email   : Email pour Let's Encrypt (optionnel)"
    exit 1
fi

DOMAIN="$1"
EMAIL="${2:-webmaster@$DOMAIN}"
DEPLOY_DIR="/opt/technicia"
DOCKER_DIR="$DEPLOY_DIR/docker"
NGINX_DIR="$DOCKER_DIR/nginx"
DOCKER_COMPOSE_FILE="$DOCKER_DIR/docker-compose.yml"

# Fonction pour afficher les logs
log() {
  echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
  echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERREUR: $1${NC}"
}

warn() {
  echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ATTENTION: $1${NC}"
}

# Vérification des répertoires et fichiers nécessaires
if [ ! -f "$DOCKER_COMPOSE_FILE" ]; then
  error "Le fichier $DOCKER_COMPOSE_FILE n'existe pas. Veuillez d'abord déployer TechnicIA."
  exit 1
fi

log "Configuration HTTPS pour le domaine: $DOMAIN"

# Installation de Certbot
log "Installation de Certbot..."
if ! command -v certbot &> /dev/null; then
    sudo apt-get update
    sudo apt-get install -y certbot python3-certbot-nginx
    
    if [ $? -ne 0 ]; then
        error "Echec de l'installation de Certbot"
        exit 1
    fi
    log "Certbot installé avec succès"
else
    log "Certbot déjà installé"
fi

# Arrêt temporaire des services pour libérer le port 80
log "Arrêt temporaire des services pour l'obtention du certificat..."
cd "$DOCKER_DIR" && docker-compose down || warn "Problème lors de l'arrêt des services"

# Obtention du certificat SSL avec Certbot en mode standalone
log "Obtention du certificat SSL pour $DOMAIN..."
sudo certbot certonly --standalone --non-interactive --agree-tos --email "$EMAIL" -d "$DOMAIN"

if [ $? -ne 0 ]; then
    error "Echec de l'obtention du certificat SSL"
    # Redémarrer les services même en cas d'échec
    cd "$DOCKER_DIR" && docker-compose up -d
    exit 1
fi

log "Certificat SSL obtenu avec succès"

# Création des répertoires pour Nginx
log "Configuration de Nginx..."
mkdir -p "$NGINX_DIR/conf.d"
mkdir -p "$NGINX_DIR/ssl"
mkdir -p "$NGINX_DIR/www"

# Copie des certificats SSL pour Nginx
log "Copie des certificats SSL..."
sudo cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem "$NGINX_DIR/ssl/"
sudo cp /etc/letsencrypt/live/$DOMAIN/privkey.pem "$NGINX_DIR/ssl/"
sudo chown -R $USER:$USER "$NGINX_DIR/ssl/"

# Création de la configuration Nginx
log "Création de la configuration Nginx..."
cat > "$NGINX_DIR/conf.d/default.conf" << EOF
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name $DOMAIN;

    ssl_certificate /etc/nginx/ssl/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;

    # n8n
    location / {
        proxy_pass http://n8n:5678;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Document Processor Service
    location /api/document-processor/ {
        proxy_pass http://document-processor:8000/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Vision Classifier Service
    location /api/vision-classifier/ {
        proxy_pass http://vision-classifier:8000/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Vector Store Service
    location /api/vector-store/ {
        proxy_pass http://vector-store:8000/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Configuration de n8n pour utiliser HTTPS
log "Configuration de n8n pour HTTPS..."
if [ -f "$DEPLOY_DIR/scripts/configure-n8n.sh" ]; then
    "$DEPLOY_DIR/scripts/configure-n8n.sh" "$DOMAIN" "yes"
else
    warn "Le script configure-n8n.sh n'existe pas. Veuillez configurer n8n manuellement."
    
    # Configuration manuelle de n8n
    sed -i "s/N8N_HOST=your-vps-ip-or-domain/N8N_HOST=$DOMAIN/" "$DOCKER_COMPOSE_FILE"
    sed -i "s/N8N_PROTOCOL=http/N8N_PROTOCOL=https/" "$DOCKER_COMPOSE_FILE"
    sed -i "s|WEBHOOK_TUNNEL_URL=https://your-domain/webhook/|WEBHOOK_TUNNEL_URL=https://$DOMAIN/webhook/|" "$DOCKER_COMPOSE_FILE"
fi

# Redémarrage des services
log "Redémarrage des services..."
cd "$DOCKER_DIR" && docker-compose up -d

if [ $? -ne 0 ]; then
    error "Problème lors du redémarrage des services"
    exit 1
fi

# Configuration de la tâche cron pour le renouvellement automatique des certificats
log "Configuration du renouvellement automatique des certificats..."
CRON_JOB="0 0 * * * certbot renew --quiet --post-hook \"cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem $NGINX_DIR/ssl/ && cp /etc/letsencrypt/live/$DOMAIN/privkey.pem $NGINX_DIR/ssl/ && docker restart technicia-frontend\""

# Vérifier si la tâche existe déjà
if ! (crontab -l 2>/dev/null | grep -q "certbot renew.*$DOMAIN"); then
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
    log "Tâche cron ajoutée pour le renouvellement automatique des certificats"
else
    log "Tâche cron pour le renouvellement déjà configurée"
fi

log "Configuration HTTPS terminée avec succès!"
log "Vous pouvez maintenant accéder à TechnicIA via: https://$DOMAIN"
log "L'interface n8n est accessible à: https://$DOMAIN"
log ""
log "Vos certificats seront automatiquement renouvelés avant leur expiration."
