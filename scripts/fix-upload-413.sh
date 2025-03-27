#!/bin/bash
# Script pour résoudre l'erreur 413 Request Entity Too Large

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

# Fonction pour vérifier si on est root
check_root() {
  if [ "$EUID" -ne 0 ]; then
    error "Ce script doit être exécuté en tant que root ou avec sudo"
    exit 1
  fi
}

# Fonction pour appliquer la nouvelle config Nginx
apply_new_nginx_config() {
  log "Application de la nouvelle configuration Nginx..."
  
  # Sauvegarde de l'ancienne configuration
  if [ -f "/etc/nginx/nginx.conf" ]; then
    cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
    log "Sauvegarde de la configuration Nginx créée dans /etc/nginx/nginx.conf.bak"
  fi
  
  # Modification de la configuration principale de Nginx
  if grep -q "client_max_body_size" /etc/nginx/nginx.conf; then
    # Si la directive existe déjà, l'augmenter
    sed -i 's/client_max_body_size [0-9]*[mMkKgG]\?;/client_max_body_size 200M;/g' /etc/nginx/nginx.conf
    log "Directive client_max_body_size mise à jour à 200M dans nginx.conf"
  else
    # Sinon l'ajouter dans le bloc http
    sed -i '/http {/a \    client_max_body_size 200M;' /etc/nginx/nginx.conf
    log "Directive client_max_body_size ajoutée dans le bloc http"
  fi
  
  # Vérifier les fichiers de configuration supplémentaires
  if [ -d "/etc/nginx/conf.d" ]; then
    for conf in /etc/nginx/conf.d/*.conf; do
      if [ -f "$conf" ]; then
        if grep -q "client_max_body_size" "$conf"; then
          sed -i 's/client_max_body_size [0-9]*[mMkKgG]\?;/client_max_body_size 200M;/g' "$conf"
          log "Directive client_max_body_size mise à jour à 200M dans $conf"
        else
          if grep -q "server {" "$conf"; then
            sed -i '/server {/a \    client_max_body_size 200M;' "$conf"
            log "Directive client_max_body_size ajoutée dans $conf"
          fi
        fi
      fi
    done
  fi
  
  # Mettre à jour la configuration dans les conteneurs Docker
  log "Mise à jour de la configuration dans les conteneurs Docker..."
  
  # Mettre à jour l'image frontend avec la nouvelle configuration
  if [ -f "/opt/technicia/frontend/nginx/new-nginx.conf" ]; then
    cp /opt/technicia/frontend/nginx/new-nginx.conf /opt/technicia/frontend/nginx/nginx.conf
    log "Configuration Nginx du frontend mise à jour"
  else
    warn "Fichier /opt/technicia/frontend/nginx/new-nginx.conf non trouvé"
  fi
  
  # Redémarrer Nginx
  log "Redémarrage de Nginx..."
  systemctl restart nginx
  if [ $? -eq 0 ]; then
    log "Nginx redémarré avec succès"
  else
    error "Erreur lors du redémarrage de Nginx"
  fi
  
  # Redémarrer les conteneurs Docker
  log "Redémarrage des conteneurs Docker..."
  cd /opt/technicia/docker
  
  # Mise à jour de la variable d'environnement n8n
  if grep -q "N8N_PAYLOAD_SIZE_MAX" .env; then
    sed -i 's/N8N_PAYLOAD_SIZE_MAX=.*/N8N_PAYLOAD_SIZE_MAX=200MB/' .env
    log "Variable N8N_PAYLOAD_SIZE_MAX mise à jour dans .env"
  else
    echo "N8N_PAYLOAD_SIZE_MAX=200MB" >> .env
    log "Variable N8N_PAYLOAD_SIZE_MAX ajoutée dans .env"
  fi
  
  # Redémarrer les conteneurs
  docker-compose down
  docker-compose up -d
  
  log "Services redémarrés"
}

# Fonction principale
main() {
  log "======================================================"
  log "Correction de l'erreur 413 Request Entity Too Large"
  log "======================================================"
  
  check_root
  apply_new_nginx_config
  
  log "======================================================"
  log "Correction terminée!"
  log "Veuillez tester le téléversement d'un fichier PDF."
  log "Si le problème persiste, exécutez la commande suivante"
  log "pour vérifier les logs Nginx:"
  log "sudo tail -f /var/log/nginx/error.log"
  log "======================================================"
}

# Exécution du script
main
