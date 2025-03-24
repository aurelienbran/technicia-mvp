#!/bin/bash
# Script pour appliquer automatiquement les correctifs nécessaires
# après le déploiement du code source de TechnicIA

# Couleurs pour les logs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Répertoire de base
BASE_DIR="/opt/technicia"

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

# Vérifier que le répertoire de base existe
if [ ! -d "$BASE_DIR" ]; then
  error "Le répertoire $BASE_DIR n'existe pas, impossible d'appliquer les correctifs."
  exit 1
fi

# Fonction pour appliquer un correctif
apply_patch() {
  local description="$1"
  local status=0
  
  log "Application du correctif: $description"
  shift
  
  # Exécuter la fonction de correctif
  "$@" || status=$?
  
  if [ $status -eq 0 ]; then
    log "✅ Correctif appliqué avec succès: $description"
  else
    error "❌ Échec de l'application du correctif: $description"
  fi
  
  return $status
}

# Correctif 1: Correction du Dockerfile du frontend pour utiliser npm install
fix_frontend_dockerfile() {
  local dockerfile="$BASE_DIR/frontend/Dockerfile"
  
  if [ ! -f "$dockerfile" ]; then
    error "Dockerfile du frontend non trouvé: $dockerfile"
    return 1
  fi
  
  # Remplacer npm ci par npm install
  sed -i 's/RUN npm ci/RUN npm install/' "$dockerfile"
  
  # Vérifier que le remplacement a été effectué
  if grep -q "npm install" "$dockerfile"; then
    return 0
  else
    return 1
  fi
}

# Correctif 2: Créer structure minimale pour le frontend
fix_frontend_structure() {
  local public_dir="$BASE_DIR/frontend/public"
  local index_html="$public_dir/index.html"
  local manifest_json="$public_dir/manifest.json"
  
  # Créer le répertoire public s'il n'existe pas
  mkdir -p "$public_dir"
  
  # Créer index.html s'il n'existe pas
  if [ ! -f "$index_html" ]; then
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
  fi
  
  # Créer manifest.json s'il n'existe pas
  if [ ! -f "$manifest_json" ]; then
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
  fi
  
  # Vérifier que les fichiers ont été créés
  if [ -f "$index_html" ] && [ -f "$manifest_json" ]; then
    return 0
  else
    return 1
  fi
}

# Correctif 3: Assurer que les variables d'environnement sont correctement chargées
fix_env_loading() {
  local env_file="$BASE_DIR/.env"
  local docker_compose="$BASE_DIR/docker/docker-compose.yml"
  
  # Vérifier que le fichier .env existe
  if [ ! -f "$env_file" ]; then
    warn "Fichier .env non trouvé, impossible de vérifier les variables d'environnement."
    return 0
  fi
  
  # Vérifier le format du fichier .env
  local env_issues=0
  
  # Vérifier qu'il n'y a pas d'espaces autour des '='
  if grep -q " = " "$env_file"; then
    warn "Le fichier .env contient des espaces autour des signes '=', cela peut causer des problèmes de chargement."
    sed -i 's/ = /=/g' "$env_file"
    env_issues=1
  fi
  
  # Vérifier que chaque ligne se termine correctement
  if grep -q "=\s*$" "$env_file"; then
    warn "Le fichier .env contient des variables sans valeur."
    env_issues=1
  fi
  
  # Créer un lien symbolique du fichier .env vers le répertoire docker si nécessaire
  if [ ! -f "$BASE_DIR/docker/.env" ]; then
    ln -sf "$env_file" "$BASE_DIR/docker/.env"
    log "Lien symbolique créé pour le fichier .env dans le répertoire docker."
  fi
  
  if [ $env_issues -eq 1 ]; then
    warn "Des problèmes ont été détectés dans le fichier .env et ont été corrigés automatiquement."
  fi
  
  return 0
}

# Application des correctifs
log "Démarrage de l'application des correctifs pour TechnicIA..."

apply_patch "Correction du Dockerfile du frontend" fix_frontend_dockerfile
apply_patch "Création de la structure minimale pour le frontend" fix_frontend_structure
apply_patch "Vérification du chargement des variables d'environnement" fix_env_loading

log "Application des correctifs terminée."

# Rappel pour redémarrer les services après les correctifs
log "N'oubliez pas de reconstruire et redémarrer les services Docker :"
log "cd $BASE_DIR/docker && docker-compose down && docker-compose up -d --build"