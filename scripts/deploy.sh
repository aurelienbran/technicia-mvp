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
  fi
  
  log "Tous les prérequis sont satisfaits."
}

# Sauvegarder l'environnement existant (si disponible)
backup_existing() {
  if [ -d "$DEPLOY_DIR" ]; then
    log "Sauvegarde de l'environnement existant..."
    
    # Créer le répertoire de sauvegarde si nécessaire
    mkdir -p "$BACKUP_DIR"
    
    # Sauvegarder les fichiers importants et les modifications locales
    log "Sauvegarde des fichiers importants..."
    
    # Sauvegarder le fichier .env
    if [ -f "$DEPLOY_DIR/$ENV_FILE" ]; then
      cp "$DEPLOY_DIR/$ENV_FILE" "$BACKUP_DIR/$ENV_FILE.$DATE_TAG"
      log "Fichier .env sauvegardé"
    fi
    
    # Sauvegarder les fichiers modifiés localement
    if [ -d "$DEPLOY_DIR/.git" ]; then
      cd "$DEPLOY_DIR"
      # Créer un patch des modifications locales
      if git diff --quiet; then
        log "Aucune modification locale à sauvegarder"
      else
        git diff > "$BACKUP_DIR/local_changes.$DATE_TAG.patch"
        log "Modifications locales sauvegardées dans $BACKUP_DIR/local_changes.$DATE_TAG.patch"
      fi
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
    
    # Sauvegarder la liste des fichiers personnalisés avant la mise à jour
    local modified_files=$(git ls-files -m)
    
    # Récupérer les dernières modifications sans écraser les modifications locales
    git stash save "Sauvegarde automatique avant mise à jour - $DATE_TAG"
    git fetch
    
    # Utiliser un rebase au lieu d'un reset hard pour préserver les modifications locales
    git rebase origin/main || {
      warn "Rebase échoué, tentative de merge..."
      git merge origin/main || {
        error "Impossible de mettre à jour le code source."
        git stash pop
        exit 1
      }
    }
    
    # Restaurer les modifications locales si possible
    if git stash list | grep -q "Sauvegarde automatique avant mise à jour"; then
      git stash pop || warn "Impossible de restaurer certaines modifications locales. Résolvez les conflits manuellement."
    fi
    
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
  if [ -f "$BACKUP_DIR/$ENV_FILE.$DATE_TAG" ]; then
    cp "$BACKUP_DIR/$ENV_FILE.$DATE_TAG" "$DEPLOY_DIR/$ENV_FILE"
    log "Fichier .env restauré depuis la sauvegarde récente"
  elif [ -f "$DEPLOY_DIR/$ENV_FILE.backup" ]; then
    cp "$DEPLOY_DIR/$ENV_FILE.backup" "$DEPLOY_DIR/$ENV_FILE"
    log "Fichier .env restauré depuis la sauvegarde précédente"
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
ANTHROPIC_API_KEY=votre-clé-anthropic
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
  
  # Appliquer les correctifs automatiques
  log "Application des correctifs automatiques..."
  if [ -f "$DEPLOY_DIR/scripts/apply-patches.sh" ]; then
    chmod +x "$DEPLOY_DIR/scripts/apply-patches.sh"
    "$DEPLOY_DIR/scripts/apply-patches.sh" || warn "Problème lors de l'application des correctifs"
  else
    warn "Script de correctifs introuvable. Les correctifs ne seront pas appliqués."
  fi
}

# Construire et démarrer les conteneurs
start_services() {
  log "Démarrage des services..."
  
  cd "$DEPLOY_DIR/docker"
  
  # S'assurer que .env est accessible aux services Docker
  if [ -f "$DEPLOY_DIR/$ENV_FILE" ] && [ ! -f "$DEPLOY_DIR/docker/.env" ]; then
    ln -sf "$DEPLOY_DIR/$ENV_FILE" "$DEPLOY_DIR/docker/.env"
    log "Lien symbolique créé pour le fichier .env dans le répertoire docker"
  fi
  
  # Vérifier si les variables d'environnement sont chargées
  if ! env | grep -q "N8N_ENCRYPTION_KEY"; then
    warn "Les variables d'environnement ne semblent pas être chargées."
    warn "Chargement manuel du fichier .env..."
    export $(grep -v '^#' "$DEPLOY_DIR/$ENV_FILE" | xargs)
  fi
  
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