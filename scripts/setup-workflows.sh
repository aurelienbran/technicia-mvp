#!/bin/bash
# Script de configuration automatique des workflows n8n pour TechnicIA

# Couleurs pour les logs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Variables de configuration
N8N_URL="${1:-http://localhost:5678}"
N8N_USER="${2:-admin@example.com}"
N8N_PASSWORD="${3:-password}"
DEPLOY_DIR="/opt/technicia"
WORKFLOWS_DIR="$DEPLOY_DIR/workflows"

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

# Vérification des outils nécessaires
check_prerequisites() {
  log "Vérification des prérequis..."
  
  if ! command -v curl &> /dev/null; then
    error "curl n'est pas installé. Veuillez l'installer avec 'apt-get install curl'."
    exit 1
  fi
  
  if ! command -v jq &> /dev/null; then
    log "Installation de jq..."
    sudo apt-get update && sudo apt-get install -y jq
    if [ $? -ne 0 ]; then
      error "Impossible d'installer jq. Les workflows devront être importés manuellement."
      error "Suivez le guide dans docs/n8n-config-guide.md"
      exit 1
    fi
  fi
  
  log "Prérequis satisfaits."
}

# Vérification de l'accès à n8n
check_n8n_access() {
  log "Vérification de l'accès à n8n à $N8N_URL..."
  
  # Essai 1 : méthode principale avec timeout augmenté
  if curl -s --connect-timeout 10 --max-time 15 "$N8N_URL/healthz" | grep -q "ok"; then
    log "n8n est accessible via l'endpoint healthz."
    return 0
  fi
  
  # Essai 2 : méthode alternative - vérifier juste si le serveur répond
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 15 "$N8N_URL")
  if [[ "$HTTP_STATUS" == "200" || "$HTTP_STATUS" == "301" || "$HTTP_STATUS" == "302" || "$HTTP_STATUS" == "401" || "$HTTP_STATUS" == "403" ]]; then
    log "n8n est accessible (code HTTP: $HTTP_STATUS)."
    return 0
  fi
  
  # Essai 3 : vérifier si le port est ouvert
  if nc -z -w 10 $(echo "$N8N_URL" | sed -E 's|https?://([^/:]+)(:[0-9]+)?.*|\1 \2|' | sed 's/:/ /') 2>/dev/null; then
    warn "Le port n8n semble ouvert, mais l'API n'est pas accessible. On continue malgré tout."
    return 0
  fi
  
  # Si toutes les vérifications échouent, demander à l'utilisateur
  warn "Impossible de vérifier l'accessibilité de n8n automatiquement."
  warn "Pouvez-vous accéder à l'interface n8n à $N8N_URL dans votre navigateur? (y/n)"
  read -r -p "[y/n]: " response
  
  if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    log "Accès confirmé par l'utilisateur. Poursuite du script..."
    return 0
  else
    error "Impossible d'accéder à n8n à $N8N_URL."
    error "Assurez-vous que n8n est en cours d'exécution et accessible."
    exit 1
  fi
}

# Importation des workflows
import_workflows() {
  log "Importation des workflows..."
  
  # Vérifier si le répertoire des workflows existe
  if [ ! -d "$WORKFLOWS_DIR" ]; then
    error "Le répertoire $WORKFLOWS_DIR n'existe pas."
    exit 1
  fi
  
  # Vérifier s'il y a des fichiers de workflow
  WORKFLOW_FILES=("$WORKFLOWS_DIR"/*.json)
  if [ ${#WORKFLOW_FILES[@]} -eq 0 ] || [ ! -f "${WORKFLOW_FILES[0]}" ]; then
    error "Aucun fichier de workflow trouvé dans $WORKFLOWS_DIR."
    exit 1
  fi
  
  log "Déploiement des workflow n8n"
  warn "Note: Cette fonctionnalité d'importation automatique n'est pas encore disponible."
  warn "Pour importer les workflows n8n, suivez ces étapes manuelles:"
  warn "1. Accédez à l'interface n8n: $N8N_URL"
  warn "2. Créez un compte ou connectez-vous"
  warn "3. Cliquez sur 'Workflows' dans le menu latéral"
  warn "4. Cliquez sur '+ Create Workflow'"
  warn "5. Dans le menu déroulant, sélectionnez 'Import from File'"
  warn "6. Importez les fichiers suivants:"
  
  for workflow_file in "${WORKFLOW_FILES[@]}"; do
    if [ -f "$workflow_file" ]; then
      warn "   - $(basename "$workflow_file")"
    fi
  done
  
  log "Pour des instructions détaillées, consultez: docs/n8n-config-guide.md"
  
  # Note: En raison des limitations de l'API n8n et de la nécessité d'authentification,
  # l'importation automatique des workflows nécessiterait une implémentation plus complexe
  # avec gestion des tokens, création de compte, etc.
}

# Configuration des credentials de base
setup_credentials() {
  log "Configuration des credentials"
  warn "Note: La configuration automatique des credentials n'est pas encore disponible."
  warn "Pour configurer les credentials n8n, suivez ces étapes manuelles:"
  warn "1. Accédez à l'interface n8n: $N8N_URL"
  warn "2. Cliquez sur 'Credentials' dans le menu latéral"
  warn "3. Configurez les credentials suivants:"
  warn "   - Google Cloud Service Account (google-cloud)"
  warn "   - HTTP Header Auth pour Anthropic API (anthropic-api)"
  warn "   - HTTP Header Auth pour Voyage AI (voyage-api)"
  warn "   - HTTP Basic Auth pour les microservices (technicia-services)"
  
  log "Pour des instructions détaillées, consultez: docs/n8n-config-guide.md"
}

# Afficher les instructions finales
show_instructions() {
  log ""
  log "Instructions pour finaliser la configuration n8n:"
  log "------------------------------------------------"
  log "1. Accédez à l'interface n8n: $N8N_URL"
  log "2. Créez un compte administrateur (lors de la première connexion)"
  log "3. Importez les workflows depuis: $WORKFLOWS_DIR"
  log "4. Configurez les credentials nécessaires pour chaque service externe"
  log "5. Activez les workflows importés"
  log ""
  log "Consultez le guide détaillé: docs/n8n-config-guide.md"
}

# Exécution principale
main() {
  log "Configuration des workflows n8n pour TechnicIA"
  
  check_prerequisites
  check_n8n_access
  import_workflows
  setup_credentials
  show_instructions
  
  log "Configuration terminée. Veuillez suivre les instructions ci-dessus pour finaliser la configuration."
}

# Exécuter le script
main