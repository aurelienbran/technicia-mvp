#!/bin/bash
# Script de diagnostic pour les problèmes d'upload dans TechnicIA
# Ce script ne modifie RIEN, il effectue uniquement des vérifications

# Couleurs pour les logs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction pour afficher les titres de section
section() {
  echo -e "\n${BLUE}======================================================${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}======================================================${NC}"
}

# Fonction pour afficher les logs
log() {
  echo -e "${GREEN}[INFO] $1${NC}"
}

warn() {
  echo -e "${YELLOW}[WARN] $1${NC}"
}

error() {
  echo -e "${RED}[ERROR] $1${NC}"
}

# Vérifier que les conteneurs sont en cours d'exécution
check_containers() {
  section "Vérification des conteneurs Docker"
  
  containers=("technicia-frontend" "technicia-n8n" "technicia-document-processor")
  
  for container in "${containers[@]}"; do
    if docker ps | grep -q "$container"; then
      log "✅ Conteneur $container : en cours d'exécution"
    else
      error "❌ Conteneur $container : NON TROUVÉ ou arrêté"
      if docker ps -a | grep -q "$container"; then
        warn "   Le conteneur existe mais n'est pas en cours d'exécution"
        log "   Dernières lignes de log pour $container:"
        docker logs --tail 10 "$container"
      else
        warn "   Le conteneur n'existe pas du tout"
      fi
    fi
  done
}

# Vérifier la configuration Nginx dans le frontend
check_nginx_config() {
  section "Vérification de la configuration Nginx du frontend"
  
  if docker ps | grep -q "technicia-frontend"; then
    log "Extraction de la configuration Nginx active:"
    echo "----------------------------------------"
    docker exec technicia-frontend cat /etc/nginx/conf.d/default.conf
    echo "----------------------------------------"
    
    # Vérifier la directive client_max_body_size
    if docker exec technicia-frontend grep -q "client_max_body_size" /etc/nginx/conf.d/default.conf; then
      size=$(docker exec technicia-frontend grep "client_max_body_size" /etc/nginx/conf.d/default.conf | head -1 | awk '{print $2}')
      log "✅ Directive client_max_body_size trouvée: $size"
    else
      error "❌ Directive client_max_body_size NON TROUVÉE dans la configuration Nginx"
      warn "   La taille maximale de téléversement est probablement limitée à 1M par défaut"
    fi
    
    # Vérifier les locations pour /api/upload
    if docker exec technicia-frontend grep -A 10 "location /api/upload" /etc/nginx/conf.d/default.conf; then
      log "✅ Configuration pour /api/upload trouvée"
    else
      warn "⚠️ Configuration spécifique pour /api/upload NON TROUVÉE"
    fi
  else
    error "❌ Impossible de vérifier la configuration Nginx - conteneur frontend non disponible"
  fi
}

# Vérifier la configuration n8n
check_n8n_config() {
  section "Vérification de la configuration n8n"
  
  if docker ps | grep -q "technicia-n8n"; then
    log "Variables d'environnement pour n8n:"
    echo "----------------------------------------"
    docker exec technicia-n8n env | grep -E "N8N_|NODE_" | sort
    echo "----------------------------------------"
    
    # Vérifier spécifiquement N8N_PAYLOAD_SIZE_MAX
    if docker exec technicia-n8n env | grep -q "N8N_PAYLOAD_SIZE_MAX"; then
      size=$(docker exec technicia-n8n env | grep "N8N_PAYLOAD_SIZE_MAX" | cut -d'=' -f2)
      log "✅ Variable N8N_PAYLOAD_SIZE_MAX configurée: $size"
    else
      error "❌ Variable N8N_PAYLOAD_SIZE_MAX NON CONFIGURÉE"
      warn "   La taille maximale des charges utiles est probablement limitée par défaut"
    fi
  else
    error "❌ Impossible de vérifier la configuration n8n - conteneur n8n non disponible"
  fi
}

# Vérifier les mappings du frontend
check_frontend_mappings() {
  section "Vérification des mappings dans le frontend"
  
  log "Recherche du point de terminaison d'upload dans le code frontend..."
  file_path="/opt/technicia/frontend/src/pages/DocumentUploadPage.js"
  
  if [ -f "$file_path" ]; then
    api_endpoint=$(grep -n "API_ENDPOINT" "$file_path" | head -1)
    log "Ligne trouvée: $api_endpoint"
    
    # Afficher le contexte autour de API_ENDPOINT
    line_number=$(echo "$api_endpoint" | cut -d':' -f1)
    if [ -n "$line_number" ]; then
      start=$((line_number - 3))
      end=$((line_number + 3))
      [ $start -lt 1 ] && start=1
      
      log "Contexte autour de la ligne API_ENDPOINT:"
      echo "----------------------------------------"
      sed -n "${start},${end}p" "$file_path"
      echo "----------------------------------------"
    fi
  else
    error "❌ Fichier frontend DocumentUploadPage.js non trouvé"
  fi
}

# Vérifier le workflow n8n
check_n8n_webhook() {
  section "Vérification du webhook n8n"
  
  if docker ps | grep -q "technicia-n8n"; then
    # Vérifier les webhooks actifs dans n8n
    log "Vérification des webhooks actifs..."
    docker exec technicia-n8n node -e "
      const fs = require('fs');
      const path = '/home/node/.n8n';
      const workflows = [];
      try {
        const files = fs.readdirSync(path);
        files.forEach(file => {
          if (file.endsWith('.json')) {
            try {
              const data = JSON.parse(fs.readFileSync(path + '/' + file, 'utf8'));
              const webhooks = [];
              if (data.nodes) {
                data.nodes.forEach(node => {
                  if (node.type === 'n8n-nodes-base.webhook') {
                    webhooks.push({
                      name: node.name,
                      path: node.parameters?.path,
                      method: node.parameters?.httpMethod,
                      webhookId: node.webhookId
                    });
                  }
                });
              }
              if (webhooks.length > 0) {
                workflows.push({
                  name: data.name,
                  webhooks
                });
              }
            } catch (e) {}
          }
        });
        console.log(JSON.stringify(workflows, null, 2));
      } catch (e) {
        console.log('Erreur lors de la lecture des workflows:', e);
      }
    "
  else
    error "❌ Impossible de vérifier les webhooks n8n - conteneur n8n non disponible"
  fi
}

# Tester les connexions réseau
test_network() {
  section "Test des connexions réseau entre les services"
  
  # Test depuis le frontend vers n8n
  if docker ps | grep -q "technicia-frontend"; then
    log "Test de connexion depuis frontend vers n8n..."
    docker exec technicia-frontend wget -q --spider --timeout=3 http://n8n:5678 && \
      log "✅ Connexion frontend → n8n: OK" || \
      error "❌ Connexion frontend → n8n: ÉCHEC"
  fi
  
  # Test direct vers le webhook depuis le serveur
  log "Test de connexion directe vers le webhook n8n..."
  curl -sS -o /dev/null -w "%{http_code}" -X POST -F "file=@/dev/null" http://localhost:5678/webhook/upload > /dev/null && \
    log "✅ Connexion directe vers webhook n8n: OK" || \
    error "❌ Connexion directe vers webhook n8n: ÉCHEC"
}

# Vérifier si le fichier .env existe et s'il contient N8N_PAYLOAD_SIZE_MAX
check_env_file() {
  section "Vérification du fichier .env"
  
  if [ -f "/opt/technicia/docker/.env" ]; then
    log "Fichier .env trouvé"
    
    # Vérifier si N8N_PAYLOAD_SIZE_MAX est présent
    if grep -q "N8N_PAYLOAD_SIZE_MAX" "/opt/technicia/docker/.env"; then
      value=$(grep "N8N_PAYLOAD_SIZE_MAX" "/opt/technicia/docker/.env" | cut -d'=' -f2)
      log "✅ N8N_PAYLOAD_SIZE_MAX est configuré avec la valeur: $value"
    else
      error "❌ N8N_PAYLOAD_SIZE_MAX n'est pas configuré dans le fichier .env"
    fi
  else
    error "❌ Fichier .env non trouvé dans /opt/technicia/docker/"
  fi
}

# Vérifier le proxy Nginx externe, s'il existe
check_external_nginx() {
  section "Vérification du proxy Nginx externe (si présent)"
  
  if command -v nginx >/dev/null 2>&1; then
    log "Nginx est installé sur le système hôte"
    nginx_version=$(nginx -v 2>&1)
    log "Version Nginx: $nginx_version"
    
    # Vérifier les fichiers de configuration
    log "Recherche des fichiers de configuration Nginx:"
    possible_configs=(
      "/etc/nginx/nginx.conf"
      "/etc/nginx/conf.d/default.conf"
      "/etc/nginx/sites-enabled/default"
    )
    
    for config in "${possible_configs[@]}"; do
      if [ -f "$config" ]; then
        log "Fichier trouvé: $config"
        if grep -q "client_max_body_size" "$config"; then
          size=$(grep "client_max_body_size" "$config" | head -1 | awk '{print $2}')
          log "✅ Directive client_max_body_size trouvée: $size"
        else
          warn "⚠️ Directive client_max_body_size NON TROUVÉE dans $config"
        fi
      fi
    done
  else
    log "Nginx n'est pas installé sur le système hôte"
  fi
}

# Exécuter toutes les vérifications
main() {
  section "Démarrage du diagnostic de téléversement TechnicIA"
  log "Date et heure: $(date)"
  log "Système: $(uname -a)"
  log "Version Docker: $(docker --version)"
  log "Version Docker Compose: $(docker-compose --version)"
  
  check_containers
  check_nginx_config
  check_n8n_config
  check_frontend_mappings
  check_n8n_webhook
  test_network
  check_env_file
  check_external_nginx
  
  section "Diagnostic terminé"
  log "Pour résoudre les problèmes détectés, veuillez consulter les parties marquées en rouge ❌ ou jaune ⚠️"
}

# Exécution du script
main
