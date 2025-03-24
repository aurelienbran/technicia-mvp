#!/bin/bash
# Script d'installation initiale pour TechnicIA

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

# Installation des prérequis
install_prerequisites() {
  log "Installation des prérequis..."
  
  # Mise à jour du système
  log "Mise à jour du système..."
  sudo apt update && sudo apt upgrade -y || { error "Échec de la mise à jour du système"; exit 1; }
  
  # Installer les dépendances de base
  log "Installation des dépendances de base..."
  sudo apt install -y git curl wget ca-certificates gnupg lsb-release || { error "Échec de l'installation des dépendances"; exit 1; }
  
  log "Prérequis installés avec succès"
}

# Installation de Docker et Docker Compose
install_docker() {
  log "Installation de Docker..."
  
  # Désinstaller les anciens packages Docker si nécessaire
  sudo apt-get remove docker docker-engine docker.io containerd runc

  # Installer les packages requis
  sudo apt-get install -y ca-certificates curl gnupg || { error "Échec de l'installation des packages prérequis"; exit 1; }

  # Créer le répertoire pour les clés
  sudo install -m 0755 -d /etc/apt/keyrings

  # Télécharger et installer la clé GPG de Docker
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg

  # Configurer le repository Docker
  echo \
    "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  # Mettre à jour l'index des paquets et installer Docker
  sudo apt-get update || { error "Échec de la mise à jour des sources"; exit 1; }
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || { error "Échec de l'installation de Docker"; exit 1; }
  
  # Ajouter l'utilisateur courant au groupe Docker
  sudo usermod -aG docker "$USER" || warn "Impossible d'ajouter l'utilisateur au groupe docker"
  
  log "Docker installé avec succès. Vous devrez vous déconnecter et vous reconnecter pour que les modifications de groupe prennent effet."
}

# Installation et Configuration de Certbot (HTTPS)
install_certbot() {
  log "Installation de Certbot pour la configuration HTTPS..."
  
  sudo apt-get install -y certbot python3-certbot-nginx || { error "Échec de l'installation de Certbot"; exit 1; }
  
  log "Certbot installé avec succès"
}

# Configuration du pare-feu (UFW)
configure_firewall() {
  log "Configuration du pare-feu UFW..."
  
  # Installation de UFW si besoin
  sudo apt install -y ufw || { error "Échec de l'installation de UFW"; exit 1; }
  
  # Configuration des règles
  sudo ufw default deny incoming
  sudo ufw default allow outgoing
  sudo ufw allow ssh
  sudo ufw allow http
  sudo ufw allow https
  
  # Port pour n8n
  sudo ufw allow 5678/tcp
  
  # Activer le pare-feu
  echo "y" | sudo ufw enable || warn "Problème lors de l'activation du pare-feu"
  
  log "Pare-feu configuré avec succès"
}

# Fonction principale
main() {
  log "Démarrage de l'installation de TechnicIA..."
  
  install_prerequisites
  install_docker
  install_certbot
  configure_firewall
  
  log "Installation terminée avec succès!"
  log "Vous pouvez maintenant utiliser le script deploy.sh pour déployer TechnicIA"
  log "Documentation disponible dans le dossier docs/"
  
  # Notifier l'utilisateur qu'il doit se déconnecter et reconnecter
  warn "IMPORTANT: Vous devez vous déconnecter et vous reconnecter pour utiliser Docker sans sudo"
}

# Exécution du script
main
