#!/bin/bash
# Système de vérification pour TechnicIA
# Ce script vérifie l'état des différents composants de TechnicIA

# Couleurs pour le formatage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction pour afficher les messages
print_header() {
  echo -e "\n${BLUE}=== $1 ===${NC}\n"
}

print_success() {
  echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
  echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
  echo -e "${RED}✗ $1${NC}"
}

print_info() {
  echo -e "  $1"
}

# Fonction pour vérifier si un conteneur est en cours d'exécution
check_container() {
  local container_name="technicia-$1"
  
  if docker ps | grep -q "$container_name"; then
    print_success "$1 est en cours d'exécution"
    return 0
  else
    if docker ps -a | grep -q "$container_name"; then
      print_error "$1 existe mais n'est pas en cours d'exécution"
      print_info "Pour le démarrer: docker start $container_name"
    else
      print_error "$1 n'existe pas"
      print_info "Le déploiement pourrait être incomplet"
    fi
    return 1
  fi
}

# Fonction pour vérifier l'état de santé d'un service
check_health() {
  local service=$1
  local port=$2
  
  # Skip if container is not running
  if ! docker ps | grep -q "technicia-$service"; then
    return 1
  fi
  
  # Try to get health endpoint
  local response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$port/health 2>/dev/null)
  
  if [ "$response" == "200" ]; then
    print_success "$service indique qu'il est en bonne santé"
    return 0
  else
    print_warning "$service n'a pas répondu correctement (code: $response)"
    print_info "Vérifiez les logs: docker logs technicia-$service"
    return 1
  fi
}

# Fonction pour vérifier la connectivité entre les services
check_connectivity() {
  local source=$1
  local target=$2
  
  # Skip if source container is not running
  if ! docker ps | grep -q "technicia-$source"; then
    return 1
  fi
  
  # Test connectivity by pinging from source to target
  if docker exec "technicia-$source" ping -c 1 -W 1 "$target" >/dev/null 2>&1; then
    print_success "$source peut communiquer avec $target"
    return 0
  else
    print_error "$source ne peut pas communiquer avec $target"
    print_info "Vérifiez la configuration réseau Docker"
    return 1
  fi
}

# Fonction pour vérifier les variables d'environnement
check_env_var() {
  local service=$1
  local var_name=$2
  
  # Skip if container is not running
  if ! docker ps | grep -q "technicia-$service"; then
    return 1
  fi
  
  # Check if the environment variable is set
  if docker exec "technicia-$service" bash -c "env | grep -q '^${var_name}='" >/dev/null 2>&1; then
    print_success "$service a la variable $var_name configurée"
    return 0
  else
    print_error "$service n'a pas la variable $var_name configurée"
    print_info "Cette variable est requise pour le bon fonctionnement"
    return 1
  fi
}

# Fonction pour vérifier les logs d'erreurs récentes
check_recent_errors() {
  local service=$1
  local error_count=$(docker logs --since=1h "technicia-$service" 2>&1 | grep -i "error\|exception\|fail" | wc -l)
  
  if [ "$error_count" -eq 0 ]; then
    print_success "Aucune erreur récente dans les logs de $service"
    return 0
  else
    print_warning "$error_count erreurs/exceptions récentes dans les logs de $service"
    print_info "Commande pour voir les erreurs: docker logs --since=1h technicia-$service 2>&1 | grep -i 'error\|exception\|fail'"
    return 1
  fi
}

# Vérification des services Docker
print_header "VÉRIFICATION DES CONTENEURS DOCKER"
check_container "n8n"
check_container "document-processor"
check_container "vision-classifier"
check_container "vector-store"
check_container "qdrant"
check_container "frontend"

# Vérification de l'état de santé des services
print_header "VÉRIFICATION DE L'ÉTAT DE SANTÉ DES SERVICES"
check_health "document-processor" 8001
check_health "vision-classifier" 8002
check_health "vector-store" 8003
check_health "n8n" 5678

# Vérification de la connectivité entre les services
print_header "VÉRIFICATION DE LA CONNECTIVITÉ"
check_connectivity "n8n" "document-processor"
check_connectivity "n8n" "vision-classifier"
check_connectivity "n8n" "vector-store"
check_connectivity "document-processor" "vector-store"
check_connectivity "vector-store" "qdrant"

# Vérification des variables d'environnement critiques
print_header "VÉRIFICATION DES VARIABLES D'ENVIRONNEMENT"
check_env_var "document-processor" "DOCUMENT_AI_PROJECT"
check_env_var "document-processor" "DOCUMENT_AI_PROCESSOR_ID"
check_env_var "document-processor" "GOOGLE_APPLICATION_CREDENTIALS"
check_env_var "vision-classifier" "GOOGLE_APPLICATION_CREDENTIALS"
check_env_var "vector-store" "VOYAGE_API_KEY"

# Vérification des erreurs récentes dans les logs
print_header "VÉRIFICATION DES ERREURS RÉCENTES"
check_recent_errors "document-processor"
check_recent_errors "vision-classifier"
check_recent_errors "vector-store"
check_recent_errors "n8n"

# Vérification des workflows n8n
print_header "VÉRIFICATION DES WORKFLOWS N8N"

# Check if n8n container is running before attempting to check workflows
if docker ps | grep -q "technicia-n8n"; then
  # Use n8n CLI to list workflows and their status
  workflows=$(docker exec technicia-n8n n8n list workflows 2>/dev/null)
  
  if [ $? -eq 0 ]; then
    echo "$workflows" | while read -r line; do
      if [[ $line == *"active"* ]]; then
        print_success "$(echo $line | awk '{print $2}')"
      elif [[ $line == *"inactive"* ]]; then
        print_warning "$(echo $line | awk '{print $2}') (inactif)"
      fi
    done
  else
    print_error "Impossible d'obtenir l'état des workflows n8n"
    print_info "Vérifiez l'interface n8n à http://localhost:5678"
  fi
else
  print_error "Le conteneur n8n n'est pas en cours d'exécution"
fi

# Résumé
print_header "RÉSUMÉ ET ACTIONS SUGGÉRÉES"

# Check recent execution errors in n8n
if docker ps | grep -q "technicia-n8n"; then
  failed_executions=$(docker exec technicia-n8n n8n list executions --status=error --limit=5 2>/dev/null)
  
  if [ $? -eq 0 ] && [ -n "$failed_executions" ]; then
    print_warning "Exécutions récentes en erreur détectées dans n8n"
    print_info "Consultez l'interface n8n pour plus de détails"
  fi
fi

# Check disk space
disk_usage=$(df -h /var/lib/docker | awk 'NR==2 {print $5}' | cut -d'%' -f1)
if [ -n "$disk_usage" ] && [ "$disk_usage" -gt 85 ]; then
  print_warning "L'espace disque est à $disk_usage% d'utilisation"
  print_info "Envisagez de nettoyer les images et volumes Docker inutilisés"
fi

# Check memory usage
mem_usage=$(free | grep Mem | awk '{print int($3/$2 * 100)}')
if [ -n "$mem_usage" ] && [ "$mem_usage" -gt 90 ]; then
  print_warning "L'utilisation de la RAM est à $mem_usage%"
  print_info "Envisagez de redémarrer certains services ou d'augmenter la RAM"
fi

# Final message
echo -e "\n${BLUE}Vérification du système terminée.${NC}"
echo -e "Pour un dépannage plus détaillé, consultez:"
echo -e "  - docs/microservices-debugging.md"
echo -e "  - docs/pdf-processing-issues.md"
echo -e "  - docs/log-management.md"
