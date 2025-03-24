#!/bin/bash
# Script pour configurer n8n pour TechnicIA

# Couleurs pour les logs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
N8N_HOST="localhost"
N8N_PORT="5678"
N8N_USER="admin"
N8N_PASSWORD="password123"  # À modifier ou à configurer via une variable d'environnement
N8N_ENCRYPTION_KEY="votre-clé-de-chiffrement"  # À modifier ou à configurer via une variable d'environnement
WORKFLOWS_DIR="./n8n-workflows"

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

# Attendre que n8n soit disponible
wait_for_n8n() {
  log "Attente du démarrage de n8n..."
  for i in {1..60}; do
    if curl -s "http://${N8N_HOST}:${N8N_PORT}/healthz" &> /dev/null; then
      log "n8n est disponible"
      return 0
    fi
    echo -n "."
    sleep 2
  done
  
  error "Timeout en attendant que n8n démarre"
  return 1
}

# Configurer les credentials n8n
configure_credentials() {
  log "Configuration des credentials n8n..."
  
  # À implémenter en fonction de vos besoins spécifiques
  # n8n CLI ou API peut être utilisé pour configurer les credentials
  
  warn "La configuration automatique des credentials n'est pas encore implémentée"
  warn "Veuillez configurer les credentials manuellement via l'interface web n8n"
  
  log "Credentials qui doivent être configurés:"
  log "1. Google Cloud API (pour Document AI et Vision AI)"
  log "2. Anthropic API (pour Claude 3.5)"
  log "3. Voyage AI API (pour les embeddings)"
  log "4. HTTP Basic Auth (pour les services TechnicIA)"
}

# Importer les workflows n8n
import_workflows() {
  log "Importation des workflows n8n..."
  
  # Vérifier si le répertoire de workflows existe
  if [ ! -d "$WORKFLOWS_DIR" ]; then
    warn "Le répertoire $WORKFLOWS_DIR n'existe pas"
    return 1
  fi
  
  # Parcourir les fichiers JSON de workflow
  for workflow_file in "$WORKFLOWS_DIR"/*.json; do
    if [ -f "$workflow_file" ]; then
      workflow_name=$(basename "$workflow_file" .json)
      log "Importation du workflow: $workflow_name"
      
      # À implémenter: utiliser n8n CLI ou API pour importer le workflow
      # Par exemple avec n8n CLI: n8n import:workflow --file "$workflow_file"
      
      warn "L'importation automatique des workflows n'est pas encore implémentée"
      warn "Veuillez importer les workflows manuellement via l'interface web n8n"
    fi
  done
  
  log "Workflows à importer:"
  log "1. document-ingestion-workflow.json (ingestion et traitement des documents)"
  log "2. chat-workflow.json (traitement des questions et génération des réponses)"
  log "3. diagnostic-workflow.json (assistance au diagnostic pas à pas)"
}

# Configurer les webhooks n8n
configure_webhooks() {
  log "Configuration des webhooks n8n..."
  
  # À implémenter: configuration des webhooks pour les appels depuis le frontend
  # Cela dépend de votre implémentation spécifique et de la configuration de votre domaine
  
  warn "La configuration automatique des webhooks n'est pas encore implémentée"
  warn "Veuillez configurer les webhooks manuellement via l'interface web n8n"
  
  log "Webhooks à configurer:"
  log "1. /webhook/upload (pour déclencher le workflow d'ingestion de documents)"
  log "2. /webhook/chat (pour déclencher le workflow de chat)"
  log "3. /webhook/diagnostic (pour déclencher le workflow de diagnostic)"
}

# Vérifier la configuration
check_configuration() {
  log "Vérification de la configuration n8n..."
  
  # Vérifier que n8n est toujours en cours d'exécution
  if ! curl -s "http://${N8N_HOST}:${N8N_PORT}/healthz" &> /dev/null; then
    error "n8n n'est pas accessible"
    return 1
  fi
  
  log "n8n est correctement configuré et accessible"
  return 0
}

# Fonction principale
main() {
  log "Démarrage de la configuration de n8n pour TechnicIA..."
  
  wait_for_n8n || exit 1
  configure_credentials
  import_workflows
  configure_webhooks
  check_configuration || warn "Problèmes détectés dans la configuration de n8n"
  
  log "Configuration de n8n terminée!"
  log "URL d'accès à n8n: http://${N8N_HOST}:${N8N_PORT}"
  log "Utilisateur: $N8N_USER"
  warn "Pensez à modifier le mot de passe par défaut via l'interface web n8n!"
}

# Exécution du script
main
