#!/bin/bash
# Script de configuration automatique de n8n pour TechnicIA

# Couleurs pour les logs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Vérification des arguments
if [ $# -lt 1 ]; then
    echo -e "${RED}Usage: $0 <ip-ou-domaine> [use-https]${NC}"
    echo -e "  ip-ou-domaine : Adresse IP ou nom de domaine du serveur"
    echo -e "  use-https     : Utiliser HTTPS (yes/no, défaut: no)"
    exit 1
fi

SERVER_ADDRESS="$1"
USE_HTTPS="${2:-no}"
DEPLOY_DIR="/opt/technicia"
DOCKER_DIR="$DEPLOY_DIR/docker"
DOCKER_COMPOSE_FILE="$DOCKER_DIR/docker-compose.yml"
ENV_FILE="$DEPLOY_DIR/.env"

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

log "Configuration de n8n pour le serveur: $SERVER_ADDRESS"

# Configuration des variables d'environnement n8n dans docker-compose.yml
log "Mise à jour des variables d'environnement dans docker-compose.yml..."

# Déterminer le protocole à utiliser
PROTOCOL="http"
if [ "$USE_HTTPS" = "yes" ]; then
  PROTOCOL="https"
  log "Configuration pour HTTPS activée"
else
  log "Configuration pour HTTP (utilisation d'un proxy inverse possible ultérieurement)"
fi

# Mise à jour de l'hôte n8n
sed -i "s/N8N_HOST=your-vps-ip-or-domain/N8N_HOST=$SERVER_ADDRESS/" "$DOCKER_COMPOSE_FILE"

# Mise à jour du protocole n8n
sed -i "s/N8N_PROTOCOL=https/N8N_PROTOCOL=$PROTOCOL/" "$DOCKER_COMPOSE_FILE"

# Mise à jour de l'URL des webhooks
if [ "$USE_HTTPS" = "yes" ]; then
  sed -i "s|WEBHOOK_TUNNEL_URL=https://your-domain/webhook/|WEBHOOK_TUNNEL_URL=$PROTOCOL://$SERVER_ADDRESS/webhook/|" "$DOCKER_COMPOSE_FILE"
else
  sed -i "s|WEBHOOK_TUNNEL_URL=https://your-domain/webhook/|WEBHOOK_TUNNEL_URL=$PROTOCOL://$SERVER_ADDRESS:5678/webhook/|" "$DOCKER_COMPOSE_FILE"
fi

# Liaison du fichier .env pour Docker Compose
if [ -f "$ENV_FILE" ] && [ ! -f "$DOCKER_DIR/.env" ]; then
  ln -sf "$ENV_FILE" "$DOCKER_DIR/.env"
  log "Lien symbolique créé pour .env dans le répertoire Docker"
fi

# Redémarrage du conteneur n8n
if docker ps -a | grep -q "technicia-n8n"; then
  log "Redémarrage du conteneur n8n..."
  docker restart technicia-n8n
  
  if [ $? -eq 0 ]; then
    log "Conteneur n8n redémarré avec succès"
  else
    warn "Problème lors du redémarrage du conteneur n8n"
  fi
else
  warn "Le conteneur n8n n'est pas en cours d'exécution. Utilisez le script deploy.sh pour démarrer tous les services."
fi

log "Configuration de n8n terminée."
log "Accédez à l'interface n8n: ${PROTOCOL}://${SERVER_ADDRESS}:5678"
log "Lors de la première connexion, créez un compte administrateur."
log ""
log "Pour une configuration complète des workflows et credentials, consultez:"
log "1. Le guide détaillé: docs/n8n-config-guide.md"
log "2. Les fichiers workflow dans le répertoire: $DEPLOY_DIR/workflows/"
log ""
log "Pour importer et configurer automatiquement les workflows, utilisez le script setup-workflows.sh (à venir)"
