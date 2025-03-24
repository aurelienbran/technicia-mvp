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
    
    # Sauvegarder le fichier .env
    if [ -f "$DEPLOY_DIR/$ENV_FILE" ]; then
      cp "$DEPLOY_DIR/$ENV_FILE" "$BACKUP_DIR/$ENV_FILE.$DATE_TAG"
      log "Fichier .env sauvegardé dans $BACKUP_DIR/$ENV_FILE.$DATE_TAG"
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
    
    # Sauvegarde des fichiers personnalisés avant mise à jour
    if [ -f "$DEPLOY_DIR/frontend/Dockerfile" ]; then
      cp "$DEPLOY_DIR/frontend/Dockerfile" "$DEPLOY_DIR/frontend/Dockerfile.backup"
    fi
    
    if [ -f "$DEPLOY_DIR/$ENV_FILE" ]; then
      cp "$DEPLOY_DIR/$ENV_FILE" "$DEPLOY_DIR/$ENV_FILE.pre-update"
    fi
    
    # Mise à jour du code (plus conservative)
    if git status | grep -q "Changes not staged for commit"; then
      warn "Des modifications locales détectées. Tentative de préservation..."
      git stash save "Auto-backup before update $DATE_TAG"
      git pull --rebase || git pull
      git stash pop || warn "Impossible de restaurer certaines modifications locales."
    else
      git pull
    fi
    
    log "Code mis à jour depuis le dépôt git"
  else
    # Clonage initial
    mkdir -p "$DEPLOY_DIR"
    git clone "$REPO_URL" "$DEPLOY_DIR"
    log "Dépôt cloné avec succès dans $DEPLOY_DIR"
  fi
}

# Correction du Dockerfile du frontend
fix_frontend_dockerfile() {
  local dockerfile="$DEPLOY_DIR/frontend/Dockerfile"
  
  if [ ! -f "$dockerfile" ]; then
    warn "Dockerfile du frontend non trouvé: $dockerfile"
    return
  }
  
  log "Vérification et correction du Dockerfile frontend..."
  
  # Si une sauvegarde existe, restaurer d'abord
  if [ -f "$dockerfile.backup" ]; then
    cp "$dockerfile.backup" "$dockerfile"
    rm "$dockerfile.backup"
  fi
  
  # Remplacer npm ci par npm install pour éviter l'erreur avec package-lock.json
  if grep -q "npm ci" "$dockerfile"; then
    sed -i 's/RUN npm ci/RUN npm install/' "$dockerfile"
    log "Dockerfile frontend corrigé: npm ci → npm install"
  fi
}

# Création de la structure minimale pour le frontend
fix_frontend_structure() {
  local public_dir="$DEPLOY_DIR/frontend/public"
  local index_html="$public_dir/index.html"
  local manifest_json="$public_dir/manifest.json"
  
  log "Vérification de la structure du frontend..."
  
  # Créer le répertoire public s'il n'existe pas
  if [ ! -d "$public_dir" ]; then
    mkdir -p "$public_dir"
    log "Création du répertoire public pour le frontend"
    
    # Créer index.html
    cat > "$index_html" << 'EOF'
<!DOCTYPE html>
<html lang="fr">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="theme-color" content="#000000" />
    <meta
      name="description"
      content="TechnicIA - Assistant intelligent de maintenance technique"
    />
    <link rel="manifest" href="%PUBLIC_URL%/manifest.json" />
    <title>TechnicIA - Assistant de maintenance</title>
  </head>
  <body>
    <noscript>Vous devez activer JavaScript pour exécuter cette application.</noscript>
    <div id="root"></div>
  </body>
</html>
EOF
    log "Création du fichier index.html"
  
    # Créer manifest.json
    cat > "$manifest_json" << 'EOF'
{
  "short_name": "TechnicIA",
  "name": "TechnicIA - Assistant de maintenance technique",
  "icons": [
    {
      "src": "favicon.ico",
      "sizes": "64x64 32x32 24x24 16x16",
      "type": "image/x-icon"
    }
  ],
  "start_url": ".",
  "display": "standalone",
  "theme_color": "#000000",
  "background_color": "#ffffff"
}
EOF
    log "Création du fichier manifest.json"
  else
    log "Structure du frontend déjà en place"
  fi
}

# Configuration de l'environnement
setup_environment() {
  log "Configuration de l'environnement..."
  
  # Restaurer le fichier .env s'il existe en backup
  if [ -f "$DEPLOY_DIR/$ENV_FILE.pre-update" ]; then
    mv "$DEPLOY_DIR/$ENV_FILE.pre-update" "$DEPLOY_DIR/$ENV_FILE"
    log "Fichier .env restauré"
  elif [ -f "$BACKUP_DIR/$ENV_FILE.$DATE_TAG" ]; then
    cp "$BACKUP_DIR/$ENV_FILE.$DATE_TAG" "$DEPLOY_DIR/$ENV_FILE"
    log "Fichier .env restauré depuis la sauvegarde récente"
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
  
  # Corriger le format du fichier .env si nécessaire
  if [ -f "$DEPLOY_DIR/$ENV_FILE" ]; then
    # Supprimer les espaces autour des signes '='
    sed -i 's/ = /=/g' "$DEPLOY_DIR/$ENV_FILE"
    # S'assurer que le fichier se termine par une ligne vide
    echo "" >> "$DEPLOY_DIR/$ENV_FILE"
  fi
  
  # Créer le répertoire des identifiants si nécessaire
  mkdir -p "$DEPLOY_DIR/docker/credentials"
  
  # Vérifier le fichier d'identifiants Google Cloud
  if [ ! -f "$DEPLOY_DIR/docker/credentials/google-credentials.json" ]; then
    warn "Le fichier d'identifiants Google Cloud n'existe pas."
    warn "Veuillez créer le fichier docker/credentials/google-credentials.json avec vos identifiants Google Cloud."
  fi
  
  # Appliquer les corrections
  fix_frontend_dockerfile
  fix_frontend_structure
  
  # S'assurer que les scripts sont exécutables
  find "$DEPLOY_DIR/scripts" -name "*.sh" -exec chmod +x {} \;
  log "Tous les scripts rendus exécutables"
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
  
  # Exporter les variables d'environnement pour Docker Compose
  if [ -f "$DEPLOY_DIR/$ENV_FILE" ]; then
    log "Chargement des variables d'environnement..."
    export $(grep -v '^#' "$DEPLOY_DIR/$ENV_FILE" | xargs) || warn "Problème lors du chargement des variables d'environnement"
  fi
  
  # Construire les images
  log "Construction des images Docker..."
  docker-compose build || { error "Échec de la construction des images Docker"; exit 1; }
  
  # Démarrer les services
  log "Démarrage des conteneurs..."
  docker-compose up -d || { error "Échec du démarrage des services"; exit 1; }
  
  log "Services démarrés avec succès"
}

# Vérification des services
check_services() {
  log "Vérification des services..."
  
  # Attendre que les services démarrent
  log "Attente du démarrage des services (10 secondes)..."
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
  log "==========================================================="
  log "Déploiement de TechnicIA MVP - Version améliorée"
  log "==========================================================="
  
  check_prerequisites
  backup_existing
  update_code
  setup_environment
  start_services
  check_services
  
  log "==========================================================="
  log "Déploiement terminé avec succès!"
  log "TechnicIA est accessible à l'adresse: http://localhost"
  log "Interface n8n accessible à l'adresse: http://localhost:5678"
  log "==========================================================="
}

# Exécution du script
main