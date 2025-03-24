#!/bin/bash
# Script de déploiement de TechnicIA MVP sur VPS OVH

# Couleurs pour les logs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
REPO_URL="https://github.com/aurelienbran/technicia-mvp.git"
DEPLOY_DIR="/opt/technicia"
BACKUP_DIR="/opt/technicia-backups"
ENV_FILE=".env"
DATE_TAG=$(date +%Y%m%d%H%M%S)

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

# Vérification des prérequis
check_prerequisites() {
  log "Vérification des prérequis..."
  
  # Vérifier Docker et Docker Compose
  if ! command -v docker &> /dev/null; then
    error "Docker n'est pas installé. Veuillez installer Docker."
    exit 1
  fi
  
  if ! command -v docker-compose &> /dev/null; then
    error "Docker Compose n'est pas installé. Veuillez installer Docker Compose."
    exit 1
  fi
  
  # Vérifier Git
  if ! command -v git &> /dev/null; then
    error "Git n'est pas installé. Veuillez installer Git."
    exit 1
  }
  
  log "Tous les prérequis sont satisfaits."
}

# Sauvegarder l'environnement existant (si disponible)
backup_existing() {
  if [ -d "$DEPLOY_DIR" ]; then
    log "Sauvegarde de l'environnement existant..."
    
    # Créer le répertoire de sauvegarde si nécessaire
    mkdir -p "$BACKUP_DIR"
    
    # Sauvegarder le fichier .env
    if [ -f "$DEPLOY_DIR/$ENV_FILE" ]; then
      cp "$DEPLOY_DIR/$ENV_FILE" "$DEPLOY_DIR/$ENV_FILE.backup"
    fi
    
    # Sauvegarder les volumes Docker si nécessaire
    if [ -d "$DEPLOY_DIR/docker" ]; then
      log "Sauvegarde des volumes Docker..."
      
      # Arrêter les conteneurs avant la sauvegarde
      cd "$DEPLOY_DIR/docker" && docker-compose down || warn "Problème lors de l'arrêt des conteneurs"
      
      # Créer une archive des données Qdrant et n8n
      if [ -d "$DEPLOY_DIR/docker/qdrant/storage" ]; then
        tar -czf "$BACKUP_DIR/qdrant-storage-$DATE_TAG.tar.gz" -C "$DEPLOY_DIR/docker/qdrant" storage
        log "Sauvegarde des données Qdrant effectuée"
      fi
      
      if [ -d "$DEPLOY_DIR/docker/n8n/data" ]; then
        tar -czf "$BACKUP_DIR/n8n-data-$DATE_TAG.tar.gz" -C "$DEPLOY_DIR/docker/n8n" data
        log "Sauvegarde des données n8n effectuée"
      fi
    fi
    
    log "Sauvegarde terminée dans $BACKUP_DIR"
  else
    log "Aucun déploiement existant à sauvegarder."
  fi
}

# Cloner ou mettre à jour le code source
update_code() {
  log "Mise à jour du code source..."
  
  if [ -d "$DEPLOY_DIR/.git" ]; then
    # Le répertoire existe déjà, mise à jour
    cd "$DEPLOY_DIR"
    git fetch
    git reset --hard origin/main
    log "Code mis à jour depuis le dépôt git"
  else
    # Clonage initial
    mkdir -p "$DEPLOY_DIR"
    git clone "$REPO_URL" "$DEPLOY_DIR"
    log "Dépôt cloné avec succès dans $DEPLOY_DIR"
  fi
}

# Configuration de l'environnement
setup_environment() {
  log "Configuration de l'environnement..."
  
  # Restaurer le fichier .env s'il existe en backup
  if [ -f "$DEPLOY_DIR/$ENV_FILE.backup" ]; then
    cp "$DEPLOY_DIR/$ENV_FILE.backup" "$DEPLOY_DIR/$ENV_FILE"
    log "Fichier .env restauré depuis la sauvegarde"
  else
    # Créer un fichier .env par défaut si nécessaire
    if [ ! -f "$DEPLOY_DIR/$ENV_FILE" ]; then
      cat > "$DEPLOY_DIR/$ENV_FILE" << EOF
# Configuration de TechnicIA
N8N_ENCRYPTION_KEY=votre-clé-chiffrement-n8n
DOCUMENT_AI_PROJECT=votre-projet-document-ai
DOCUMENT_AI_LOCATION=votre-région-document-ai
DOCUMENT_AI_PROCESSOR_ID=votre-processor-id
VOYAGE_API_KEY=votre-clé-voyage-ai
EOF
      warn "Un fichier .env par défaut a été créé. Veuillez le modifier avec vos propres clés d'API."
    fi
  fi
  
  # Créer le répertoire des identifiants si nécessaire
  mkdir -p "$DEPLOY_DIR/docker/credentials"
  
  # Vérifier le fichier d'identifiants Google Cloud
  if [ ! -f "$DEPLOY_DIR/docker/credentials/google-credentials.json" ]; then
    warn "Le fichier d'identifiants Google Cloud n'existe pas."
    warn "Veuillez créer le fichier docker/credentials/google-credentials.json avec vos identifiants Google Cloud."
  fi
}

# Construire et démarrer les conteneurs
start_services() {
  log "Démarrage des services..."
  
  cd "$DEPLOY_DIR/docker"
  
  # Construire les images
  docker-compose build || { error "Échec de la construction des images Docker"; exit 1; }
  
  # Démarrer les services
  docker-compose up -d || { error "Échec du démarrage des services"; exit 1; }
  
  log "Services démarrés avec succès"
}

# Vérification des services
check_services() {
  log "Vérification des services..."
  
  # Attendre que les services démarrent
  sleep 10
  
  # Vérifier que tous les conteneurs sont en cours d'exécution
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
    fi
  done
  
  # Vérifier que Qdrant est accessible
  if curl -s "http://localhost:6333/collections" > /dev/null; then
    log "✅ API Qdrant accessible"
  else
    warn "⚠️ API Qdrant non accessible"
  fi
  
  # Vérifier que le frontend est accessible
  if curl -s "http://localhost:80" > /dev/null; then
    log "✅ Frontend accessible"
  else
    warn "⚠️ Frontend non accessible"
  fi
}

# Exécution principale
main() {
  log "Démarrage du déploiement de TechnicIA MVP"
  
  check_prerequisites
  backup_existing
  update_code
  setup_environment
  start_services
  check_services
  
  log "Déploiement terminé avec succès!"
  log "TechnicIA est accessible à l'adresse: http://localhost"
  log "Interface n8n accessible à l'adresse: http://localhost:5678"
}

# Exécution du script
main
