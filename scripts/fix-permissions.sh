#!/bin/bash
# Script pour corriger les problèmes de permissions de tous les services TechnicIA
# Ce script est appelé après le déploiement pour s'assurer que tous les services ont les bonnes permissions

# Couleurs pour les logs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
DEPLOY_DIR="/opt/technicia"
DOCKER_DIR="${DEPLOY_DIR}/docker"
N8N_DATA_DIR="${DOCKER_DIR}/n8n/data"
N8N_CONFIG_DIR="${N8N_DATA_DIR}/.n8n"
QDRANT_STORAGE_DIR="${DOCKER_DIR}/qdrant/storage"
CREDENTIALS_DIR="${DOCKER_DIR}/credentials"
SSL_DIR="${DOCKER_DIR}/ssl"
DOCKER_COMPOSE_FILE="${DOCKER_DIR}/docker-compose.yml"
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

log "Début de la correction des permissions pour tous les services..."

# 1. Arrêter les conteneurs si nécessaire
if docker ps | grep -q "technicia-"; then
  log "Arrêt des conteneurs en cours d'exécution..."
  cd "$DOCKER_DIR" && docker-compose down
fi

# 2. Créer et corriger les répertoires pour n8n
log "Configuration des permissions pour n8n..."
mkdir -p "$N8N_CONFIG_DIR"
# 1000:1000 correspond généralement à l'utilisateur 'node' dans le conteneur n8n
chown -R 1000:1000 "$N8N_DATA_DIR"
chmod -R 755 "$N8N_DATA_DIR"

# 3. Créer et corriger les répertoires pour Qdrant
log "Configuration des permissions pour Qdrant..."
mkdir -p "$QDRANT_STORAGE_DIR"
chmod -R 755 "$QDRANT_STORAGE_DIR"

# 4. Créer et corriger les répertoires pour les credentials
log "Configuration des permissions pour les credentials..."
mkdir -p "$CREDENTIALS_DIR"
chmod -R 755 "$CREDENTIALS_DIR"
# S'assurer que les fichiers JSON sont lisibles par les conteneurs
if [ -f "${CREDENTIALS_DIR}/google-credentials.json" ]; then
  chmod 644 "${CREDENTIALS_DIR}/google-credentials.json"
fi

# 5. Créer et corriger les répertoires pour SSL
log "Configuration des permissions pour SSL..."
mkdir -p "$SSL_DIR"
chmod -R 755 "$SSL_DIR"

# 6. S'assurer que les répertoires des services existent
log "Vérification des répertoires des services..."
mkdir -p "${DEPLOY_DIR}/services/document-processor"
mkdir -p "${DEPLOY_DIR}/services/vision-classifier"
mkdir -p "${DEPLOY_DIR}/services/vector-store"
mkdir -p "${DEPLOY_DIR}/frontend"
chmod -R 755 "${DEPLOY_DIR}/services"
chmod -R 755 "${DEPLOY_DIR}/frontend"

# 7. Vérifier et corriger la configuration du volume dans docker-compose.yml
log "Vérification de la configuration des volumes dans docker-compose.yml..."
if [ -f "$DOCKER_COMPOSE_FILE" ]; then
  # Vérifier si la configuration n8n est incorrecte
  if grep -q "- ./n8n/data:/home/node$" "$DOCKER_COMPOSE_FILE"; then
    log "Correction du montage de volume n8n dans docker-compose.yml..."
    sed -i 's#- ./n8n/data:/home/node$#- ./n8n/data:/home/node/.n8n#g' "$DOCKER_COMPOSE_FILE"
  fi
else
  error "Fichier docker-compose.yml non trouvé à $DOCKER_COMPOSE_FILE"
fi

# 8. Ajouter les variables d'environnement pour n8n si elles n'existent pas déjà
log "Mise à jour des variables d'environnement pour les services..."
if [ -f "$ENV_FILE" ]; then
  # Configuration n8n
  if ! grep -q "^N8N_HOST=" "$ENV_FILE"; then
    echo -e "\n# Configuration n8n pour accepter les connexions externes" >> "$ENV_FILE"
    echo "N8N_HOST=0.0.0.0" >> "$ENV_FILE"
    echo "N8N_PORT=5678" >> "$ENV_FILE"
    echo "N8N_PROTOCOL=http" >> "$ENV_FILE"
    log "Variables de configuration n8n ajoutées"
  fi
  
  # Vérifier les variables de base nécessaires
  MISSING_VARS=""
  if ! grep -q "^N8N_ENCRYPTION_KEY=" "$ENV_FILE"; then
    MISSING_VARS="${MISSING_VARS}N8N_ENCRYPTION_KEY, "
  fi
  if ! grep -q "^DOCUMENT_AI_PROJECT=" "$ENV_FILE"; then
    MISSING_VARS="${MISSING_VARS}DOCUMENT_AI_PROJECT, "
  fi
  if ! grep -q "^DOCUMENT_AI_LOCATION=" "$ENV_FILE"; then
    MISSING_VARS="${MISSING_VARS}DOCUMENT_AI_LOCATION, "
  fi
  if ! grep -q "^DOCUMENT_AI_PROCESSOR_ID=" "$ENV_FILE"; then
    MISSING_VARS="${MISSING_VARS}DOCUMENT_AI_PROCESSOR_ID, "
  fi
  if ! grep -q "^VOYAGE_API_KEY=" "$ENV_FILE"; then
    MISSING_VARS="${MISSING_VARS}VOYAGE_API_KEY, "
  fi
  if ! grep -q "^ANTHROPIC_API_KEY=" "$ENV_FILE"; then
    MISSING_VARS="${MISSING_VARS}ANTHROPIC_API_KEY, "
  fi
  
  if [ ! -z "$MISSING_VARS" ]; then
    warn "Variables manquantes dans le fichier .env: ${MISSING_VARS}. Veuillez les configurer."
  fi
else
  warn "Fichier .env non trouvé à $ENV_FILE, création d'un fichier minimal..."
  cat > "$ENV_FILE" << EOF
# Configuration de TechnicIA
N8N_ENCRYPTION_KEY=votre-clé-chiffrement-n8n
DOCUMENT_AI_PROJECT=votre-projet-document-ai
DOCUMENT_AI_LOCATION=votre-région-document-ai
DOCUMENT_AI_PROCESSOR_ID=votre-processor-id
VOYAGE_API_KEY=votre-clé-voyage-ai
ANTHROPIC_API_KEY=votre-clé-anthropic

# Configuration n8n pour accepter les connexions externes
N8N_HOST=0.0.0.0
N8N_PORT=5678
N8N_PROTOCOL=http
EOF
  warn "Fichier .env créé avec des valeurs par défaut. Veuillez le mettre à jour avec vos propres clés."
fi

# 9. Vérifier si le pare-feu est configuré
if command -v ufw &> /dev/null; then
  log "Vérification de la configuration du pare-feu UFW..."
  if ! ufw status | grep -q "5678/tcp"; then
    warn "Le port 5678 (n8n) n'est pas ouvert dans le pare-feu."
    warn "Exécutez 'sudo ufw allow 5678/tcp' pour permettre l'accès à n8n."
  fi
  if ! ufw status | grep -q "80/tcp"; then
    warn "Le port 80 (HTTP) n'est pas ouvert dans le pare-feu."
    warn "Exécutez 'sudo ufw allow 80/tcp' pour permettre l'accès au frontend."
  fi
  if ! ufw status | grep -q "443/tcp"; then
    warn "Le port 443 (HTTPS) n'est pas ouvert dans le pare-feu."
    warn "Exécutez 'sudo ufw allow 443/tcp' pour permettre l'accès sécurisé."
  fi
fi

# 10. Redémarrer les services
log "Redémarrage des services..."
cd "$DOCKER_DIR" && docker-compose up -d

# 11. Vérifier l'état des services
log "Vérification de l'état des services..."
sleep 10  # Attendre que les services démarrent

# Vérifier les conteneurs
CONTAINERS=(
  "technicia-qdrant"
  "technicia-n8n"
  "technicia-document-processor"
  "technicia-vision-classifier"
  "technicia-vector-store"
  "technicia-frontend"
)

for container in "${CONTAINERS[@]}"; do
  if docker ps | grep -q "$container"; then
    log "✅ Service $container en cours d'exécution"
  else
    warn "⚠️ Service $container non démarré ou problème"
    # Afficher les logs pour le diagnostic
    echo -e "\nLogs pour $container:"
    docker logs $container --tail 10
  fi
done

# 12. Vérifier l'accessibilité des services
log "Vérification de l'accessibilité des services..."

# Vérifier Qdrant
if curl -s "http://localhost:6333/collections" > /dev/null; then
  log "✅ API Qdrant accessible"
else
  warn "⚠️ API Qdrant non accessible"
fi

# Vérifier n8n
if curl -s "http://localhost:5678" > /dev/null; then
  log "✅ Interface n8n accessible"
else
  warn "⚠️ Interface n8n non accessible"
fi

# Vérifier le frontend
if curl -s "http://localhost:80" > /dev/null; then
  log "✅ Frontend accessible"
else
  warn "⚠️ Frontend non accessible"
fi

# Vérifier document-processor
if curl -s "http://localhost:8001/health" > /dev/null; then
  log "✅ Service Document Processor accessible"
else
  warn "⚠️ Service Document Processor non accessible ou endpoint /health non implémenté"
fi

# Vérifier vision-classifier
if curl -s "http://localhost:8002/health" > /dev/null; then
  log "✅ Service Vision Classifier accessible"
else
  warn "⚠️ Service Vision Classifier non accessible ou endpoint /health non implémenté"
fi

# Vérifier vector-store
if curl -s "http://localhost:8003/health" > /dev/null; then
  log "✅ Service Vector Store accessible"
else
  warn "⚠️ Service Vector Store non accessible ou endpoint /health non implémenté"
fi

log "========================================================================"
log "Correction des permissions terminée. Services accessibles aux adresses:"
log "- TechnicIA Frontend: http://$(hostname -I | awk '{print $1}')"
log "- Interface n8n: http://$(hostname -I | awk '{print $1}'):5678"
log "- API Qdrant: http://$(hostname -I | awk '{print $1}'):6333"
log "========================================================================"

exit 0
