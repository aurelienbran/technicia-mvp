#!/bin/bash
# Script pour corriger les problèmes de permissions de n8n
# Ce script est appelé après le déploiement pour s'assurer que n8n a les bonnes permissions

# Couleurs pour les logs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
DEPLOY_DIR="/opt/technicia"
N8N_DATA_DIR="${DEPLOY_DIR}/docker/n8n/data"
N8N_CONFIG_DIR="${N8N_DATA_DIR}/.n8n"
DOCKER_COMPOSE_FILE="${DEPLOY_DIR}/docker/docker-compose.yml"
ENV_FILE="${DEPLOY_DIR}/.env"

# Fonction pour afficher les logs
log() {
  echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
  echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ATTENTION: $1${NC}"
}

error() {
  echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERREUR: $1${NC}"
}

# Vérifier si le répertoire de déploiement existe
if [ ! -d "$DEPLOY_DIR" ]; then
  error "Le répertoire de déploiement $DEPLOY_DIR n'existe pas."
  exit 1
fi

log "Début de la correction des permissions pour n8n..."

# 1. Arrêter les conteneurs n8n si nécessaire
if docker ps | grep -q "technicia-n8n"; then
  log "Arrêt du conteneur n8n..."
  cd "$DEPLOY_DIR/docker" && docker-compose stop n8n
fi

# 2. Créer les répertoires nécessaires s'ils n'existent pas
log "Création des répertoires de données pour n8n..."
mkdir -p "$N8N_CONFIG_DIR"

# 3. Corriger les permissions des répertoires
log "Correction des permissions des répertoires..."
# 1000:1000 correspond généralement à l'utilisateur 'node' dans le conteneur n8n
chown -R 1000:1000 "$N8N_DATA_DIR"
chmod -R 755 "$N8N_DATA_DIR"

# 4. Vérifier et corriger la configuration du volume dans docker-compose.yml
log "Vérification de la configuration du volume dans docker-compose.yml..."
if [ -f "$DOCKER_COMPOSE_FILE" ]; then
  # Vérifier si la configuration actuelle est incorrecte
  if grep -q "- ./n8n/data:/home/node$" "$DOCKER_COMPOSE_FILE"; then
    log "Correction du montage de volume dans docker-compose.yml..."
    sed -i 's#- ./n8n/data:/home/node$#- ./n8n/data:/home/node/.n8n#g' "$DOCKER_COMPOSE_FILE"
  elif ! grep -q "- ./n8n/data:/home/node/.n8n" "$DOCKER_COMPOSE_FILE"; then
    warn "Configuration de volume n8n non standard, vérifiez manuellement."
  else
    log "Configuration de volume n8n correcte."
  fi
else
  error "Fichier docker-compose.yml non trouvé à $DOCKER_COMPOSE_FILE"
fi

# 5. Ajouter les variables d'environnement pour n8n si elles n'existent pas déjà
log "Mise à jour des variables d'environnement pour n8n..."
if [ -f "$ENV_FILE" ]; then
  # Vérifier et ajouter N8N_HOST
  if ! grep -q "^N8N_HOST=" "$ENV_FILE"; then
    echo "N8N_HOST=0.0.0.0" >> "$ENV_FILE"
    log "Variable N8N_HOST ajoutée"
  fi
  
  # Vérifier et ajouter N8N_PORT
  if ! grep -q "^N8N_PORT=" "$ENV_FILE"; then
    echo "N8N_PORT=5678" >> "$ENV_FILE"
    log "Variable N8N_PORT ajoutée"
  fi
  
  # Vérifier et ajouter N8N_PROTOCOL
  if ! grep -q "^N8N_PROTOCOL=" "$ENV_FILE"; then
    echo "N8N_PROTOCOL=http" >> "$ENV_FILE"
    log "Variable N8N_PROTOCOL ajoutée"
  fi
else
  warn "Fichier .env non trouvé à $ENV_FILE, création d'un fichier minimal..."
  cat > "$ENV_FILE" << EOF
# Configuration de base pour n8n
N8N_HOST=0.0.0.0
N8N_PORT=5678
N8N_PROTOCOL=http
EOF
fi

# 6. Redémarrer n8n si nécessaire
log "Redémarrage de n8n..."
cd "$DEPLOY_DIR/docker" && docker-compose up -d n8n

# 7. Vérifier si n8n est maintenant accessible
log "Vérification si n8n est accessible..."
sleep 5  # Attendre que le service démarre
if curl -s "http://localhost:5678" > /dev/null; then
  log "✅ n8n est maintenant accessible localement."
else
  warn "⚠️ n8n n'est pas accessible localement, vérification supplémentaire nécessaire."
  # Afficher les logs pour le diagnostic
  docker logs technicia-n8n --tail 20
fi

log "Correction des permissions terminée."
log "Si n8n n'est toujours pas accessible depuis l'extérieur, vérifiez votre pare-feu avec:"
log "sudo ufw status | grep 5678"
log "Si nécessaire, ouvrez le port avec: sudo ufw allow 5678/tcp"

exit 0
