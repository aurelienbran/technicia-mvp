#!/bin/bash
# Script de surveillance des services TechnicIA

# Couleurs pour les logs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
DEPLOY_DIR="/opt/technicia"
LOG_FILE="/var/log/technicia-monitor.log"
ALERT_EMAIL=${ALERT_EMAIL:-"admin@example.com"}
CHECK_INTERVAL=${CHECK_INTERVAL:-300} # Vérification toutes les 5 minutes par défaut

# Fonction pour afficher et enregistrer les logs
log() {
  echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOG_FILE"
}

error() {
  echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERREUR: $1${NC}" | tee -a "$LOG_FILE"
}

warn() {
  echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ATTENTION: $1${NC}" | tee -a "$LOG_FILE"
}

# Vérification des services Docker
check_docker_services() {
  log "Vérification des services Docker..."
  
  # Liste des services attendus
  EXPECTED_SERVICES=(
    "technicia-qdrant"
    "technicia-n8n"
    "technicia-document-processor"
    "technicia-vision-classifier"
    "technicia-vector-store"
    "technicia-frontend"
  )
  
  FAILED_SERVICES=()
  
  for service in "${EXPECTED_SERVICES[@]}"; do
    if ! docker ps --format '{{.Names}}' | grep -q "$service"; then
      FAILED_SERVICES+=("$service")
      error "Service $service n'est pas en cours d'exécution"
    else
      log "Service $service en cours d'exécution"
    fi
  done
  
  return ${#FAILED_SERVICES[@]}
}

# Vérification des API et endpoints
check_endpoints() {
  log "Vérification des endpoints..."
  
  ENDPOINTS=(
    "http://localhost:80|Frontend"
    "http://localhost:5678|n8n"
    "http://localhost:6333/collections|Qdrant API"
    "http://localhost:8001/health|Document Processor API"
    "http://localhost:8002/health|Vision Classifier API"
    "http://localhost:8003/health|Vector Store API"
  )
  
  FAILED_ENDPOINTS=()
  
  for endpoint_info in "${ENDPOINTS[@]}"; do
    IFS='|' read -r endpoint name <<< "$endpoint_info"
    
    # Tentative d'accès à l'endpoint
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$endpoint")
    
    if [[ "$HTTP_CODE" == "200" ]]; then
      log "Endpoint $name ($endpoint) accessible"
    else
      FAILED_ENDPOINTS+=("$name ($endpoint): HTTP $HTTP_CODE")
      error "Endpoint $name ($endpoint) non accessible (HTTP $HTTP_CODE)"
    fi
  done
  
  return ${#FAILED_ENDPOINTS[@]}
}

# Vérification de l'utilisation des ressources
check_resources() {
  log "Vérification de l'utilisation des ressources..."
  
  # Espace disque
  DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
  if [ "$DISK_USAGE" -gt 90 ]; then
    error "Utilisation du disque critique: ${DISK_USAGE}%"
    return 1
  elif [ "$DISK_USAGE" -gt 80 ]; then
    warn "Utilisation du disque élevée: ${DISK_USAGE}%"
  else
    log "Utilisation du disque normale: ${DISK_USAGE}%"
  fi
  
  # Utilisation de la RAM
  MEM_AVAILABLE=$(free -m | awk 'NR==2 {print $7}')
  if [ "$MEM_AVAILABLE" -lt 512 ]; then
    error "Mémoire disponible critique: ${MEM_AVAILABLE}MB"
    return 1
  elif [ "$MEM_AVAILABLE" -lt 1024 ]; then
    warn "Mémoire disponible faible: ${MEM_AVAILABLE}MB"
  else
    log "Mémoire disponible normale: ${MEM_AVAILABLE}MB"
  fi
  
  # Charge système
  LOAD=$(uptime | awk -F'[a-z]:' '{ print $2}' | awk -F',' '{ print $1}' | tr -d ' ')
  CORES=$(nproc)
  LOAD_PER_CORE=$(echo "$LOAD / $CORES" | bc -l)
  
  if (( $(echo "$LOAD_PER_CORE > 1.5" | bc -l) )); then
    error "Charge système critique: $LOAD sur $CORES cœurs"
    return 1
  elif (( $(echo "$LOAD_PER_CORE > 1.0" | bc -l) )); then
    warn "Charge système élevée: $LOAD sur $CORES cœurs"
  else
    log "Charge système normale: $LOAD sur $CORES cœurs"
  fi
  
  return 0
}

# Fonction pour envoyer une alerte
send_alert() {
  local subject="$1"
  local message="$2"
  
  if command -v mail &> /dev/null; then
    echo "$message" | mail -s "$subject" "$ALERT_EMAIL"
    log "Alerte envoyée à $ALERT_EMAIL: $subject"
  else
    error "Impossible d'envoyer l'alerte: commande 'mail' non trouvée"
  fi
}

# Fonction de vérification complète
check_all() {
  log "Démarrage de la vérification complète..."
  
  local docker_status=0
  local endpoints_status=0
  local resources_status=0
  
  check_docker_services
  docker_status=$?
  
  check_endpoints
  endpoints_status=$?
  
  check_resources
  resources_status=$?
  
  # Si au moins un problème a été détecté, envoyer une alerte
  if [ $docker_status -gt 0 ] || [ $endpoints_status -gt 0 ] || [ $resources_status -gt 0 ]; then
    local alert_message="Problèmes détectés sur TechnicIA:\n"
    
    if [ $docker_status -gt 0 ]; then
      alert_message+="- $docker_status services Docker arrêtés\n"
    fi
    
    if [ $endpoints_status -gt 0 ]; then
      alert_message+="- $endpoints_status endpoints inaccessibles\n"
    fi
    
    if [ $resources_status -gt 0 ]; then
      alert_message+="- Problèmes d'utilisation des ressources\n"
    fi
    
    alert_message+="\nVérifiez les logs pour plus de détails."
    
    send_alert "ALERTE: Problèmes détectés sur TechnicIA" "$alert_message"
    return 1
  else
    log "Tous les services fonctionnent correctement"
    return 0
  fi
}

# Fonction d'aide
show_help() {
  echo "Utilisation: $0 [option]"
  echo
  echo "Options:"
  echo "  -c, --check       Exécuter une vérification ponctuelle"
  echo "  -w, --watch       Exécuter en mode surveillance"
  echo "  -i, --interval N  Définir l'intervalle de vérification à N secondes (défaut: 300)"
  echo "  -h, --help        Afficher cette aide"
  echo
  echo "Exemple:"
  echo "  $0 --watch --interval 60"
}

# Point d'entrée principal
main() {
  # Créer le fichier de log s'il n'existe pas
  touch "$LOG_FILE" 2>/dev/null || {
    echo "Impossible de créer le fichier de log $LOG_FILE. Utilisation de la sortie standard uniquement."
    LOG_FILE=/dev/null
  }
  
  # Traitement des options
  case "$1" in
    -c|--check)
      log "Mode vérification ponctuelle"
      check_all
      exit $?
      ;;
    -w|--watch)
      log "Mode surveillance continue (Ctrl+C pour arrêter)"
      
      # Vérifier si l'intervalle a été spécifié
      if [[ "$2" == "-i" || "$2" == "--interval" ]] && [[ -n "$3" && "$3" =~ ^[0-9]+$ ]]; then
        CHECK_INTERVAL=$3
        log "Intervalle de vérification: $CHECK_INTERVAL secondes"
      fi
      
      while true; do
        check_all
        log "Prochaine vérification dans $CHECK_INTERVAL secondes..."
        sleep "$CHECK_INTERVAL"
      done
      ;;
    -i|--interval)
      if [[ -n "$2" && "$2" =~ ^[0-9]+$ ]]; then
        CHECK_INTERVAL=$2
        log "Mode surveillance continue avec intervalle $CHECK_INTERVAL secondes"
        while true; do
          check_all
          log "Prochaine vérification dans $CHECK_INTERVAL secondes..."
          sleep "$CHECK_INTERVAL"
        done
      else
        error "L'intervalle doit être un nombre entier"
        show_help
        exit 1
      fi
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      # Par défaut, exécuter une vérification ponctuelle
      log "Mode vérification ponctuelle (défaut)"
      check_all
      exit $?
      ;;
  esac
}

# Exécuter le script
main "$@"
