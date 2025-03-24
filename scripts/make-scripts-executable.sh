#!/bin/bash
# Script pour rendre exécutables tous les scripts dans le répertoire scripts

# Répertoire de base
BASE_DIR="/opt/technicia"
SCRIPTS_DIR="$BASE_DIR/scripts"

# Couleurs pour les logs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

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

# Vérifier que le répertoire des scripts existe
if [ ! -d "$SCRIPTS_DIR" ]; then
  error "Le répertoire $SCRIPTS_DIR n'existe pas."
  exit 1
fi

# Rendre exécutables tous les scripts .sh
log "Recherche de scripts dans $SCRIPTS_DIR..."
count=0

for script in "$SCRIPTS_DIR"/*.sh; do
  if [ -f "$script" ]; then
    chmod +x "$script"
    log "Script rendu exécutable: $(basename "$script")"
    ((count++))
  fi
done

if [ $count -eq 0 ]; then
  warn "Aucun script .sh trouvé dans $SCRIPTS_DIR."
else
  log "$count scripts rendus exécutables avec succès."
fi