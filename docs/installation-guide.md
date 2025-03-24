# Guide d'Installation et de Déploiement de TechnicIA MVP

Ce guide détaille les étapes nécessaires pour installer et déployer le MVP de TechnicIA sur un serveur VPS (Virtual Private Server).

## Table des matières

1. [Prérequis](#prérequis)
2. [Préparation du serveur](#préparation-du-serveur)
3. [Clonage du repository](#clonage-du-repository)
4. [Configuration](#configuration)
5. [Déploiement](#déploiement)
6. [Vérification](#vérification)
7. [Monitoring](#monitoring)
8. [Dépannage](#dépannage)
9. [Mise à jour](#mise-à-jour)

## Prérequis

- Un VPS sous Ubuntu Server 22.04 LTS avec au moins :
  - 8 Go de RAM
  - 4 vCPUs
  - 100 Go d'espace disque SSD
- Accès SSH au serveur
- Un nom de domaine (recommandé)
- Accès aux services suivants :
  - Google Cloud Platform (Document AI et Vision AI)
  - Anthropic API (Claude 3.5 Sonnet)
  - VoyageAI API (pour les embeddings)

## Préparation du serveur

### Mise à jour du système

```bash
# Mettre à jour les paquets
sudo apt update
sudo apt upgrade -y

# Installer les dépendances de base
sudo apt install -y git curl wget apt-transport-https ca-certificates gnupg-agent software-properties-common
```

### Installation de Docker et Docker Compose

```bash
# Installer Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io

# Ajouter l'utilisateur au groupe docker
sudo usermod -aG docker $USER
newgrp docker

# Installer Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

### Configuration du pare-feu

```bash
# Installer et configurer ufw
sudo apt install -y ufw

# Autoriser SSH (important pour ne pas se bloquer l'accès)
sudo ufw allow 22/tcp

# Autoriser HTTP et HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Autoriser les ports des services
sudo ufw allow 5678/tcp  # n8n
sudo ufw allow 6333/tcp  # Qdrant API (optionnel si n'est pas accessible de l'extérieur)

# Activer le pare-feu
sudo ufw enable
```

## Clonage du repository

```bash
# Créer le répertoire de déploiement
sudo mkdir -p /opt/technicia
sudo chown $USER:$USER /opt/technicia

# Cloner le repository
git clone https://github.com/aurelienbran/technicia-mvp.git /opt/technicia
cd /opt/technicia
```

## Configuration

### Fichier d'environnement

Créez un fichier `.env` à la racine du projet :

```bash
# Créer le fichier .env
cat > /opt/technicia/.env << EOF
# Configuration TechnicIA
N8N_ENCRYPTION_KEY=<votre-clé-chiffrement-n8n>
DOCUMENT_AI_PROJECT=<votre-projet-document-ai>
DOCUMENT_AI_LOCATION=<votre-région-document-ai>
DOCUMENT_AI_PROCESSOR_ID=<votre-processor-id>
VOYAGE_API_KEY=<votre-clé-voyage-ai>
EOF
```

Remplacez les valeurs `<votre-...>` par vos propres clés et identifiants.

### Configuration Google Cloud

Placez votre fichier d'identifiants Google Cloud dans le dossier approprié :

```bash
# Créer le répertoire des identifiants
mkdir -p /opt/technicia/docker/credentials

# Copiez votre fichier d'identifiants Google Cloud
# Exemple avec scp depuis votre machine locale:
# scp your-google-credentials.json user@your-server:/opt/technicia/docker/credentials/google-credentials.json
```

### Configuration Nginx pour HTTPS (optionnel mais recommandé)

Si vous avez un nom de domaine, configurez HTTPS avec Let's Encrypt :

```bash
# Installer Certbot
sudo apt install -y certbot python3-certbot-nginx

# Configurer Nginx (déjà inclus dans le docker-compose)
# Obtenir un certificat SSL
sudo certbot --nginx -d votre-domaine.com
```

## Déploiement

Utilisez le script de déploiement automatisé :

```bash
# Donner les permissions d'exécution au script
chmod +x /opt/technicia/scripts/deploy.sh

# Exécuter le script de déploiement
/opt/technicia/scripts/deploy.sh
```

Le script effectue les opérations suivantes :
1. Vérifie les prérequis
2. Sauvegarde l'environnement existant (si applicable)
3. Met à jour le code source
4. Configure l'environnement
5. Construit et démarre les services Docker
6. Vérifie que tous les services sont opérationnels

## Vérification

### Vérifier les services Docker

```bash
# Lister les conteneurs
docker ps

# Vérifier les logs de chaque service
docker logs technicia-n8n
docker logs technicia-qdrant
docker logs technicia-document-processor
docker logs technicia-vision-classifier
docker logs technicia-vector-store
docker logs technicia-frontend
```

### Accéder aux interfaces

- Interface utilisateur TechnicIA : http://votre-serveur (ou https://votre-domaine.com)
- Interface n8n : http://votre-serveur:5678 (ou https://votre-domaine.com:5678)

## Monitoring

Utilisez le script de surveillance pour monitorer les services :

```bash
# Donner les permissions d'exécution au script
chmod +x /opt/technicia/scripts/monitor.sh

# Exécuter une vérification ponctuelle
/opt/technicia/scripts/monitor.sh --check

# Ou exécuter en mode surveillance continue (toutes les 5 minutes)
/opt/technicia/scripts/monitor.sh --watch

# Pour personnaliser l'intervalle (par exemple, toutes les 2 minutes)
/opt/technicia/scripts/monitor.sh --watch --interval 120
```

### Configuration du monitoring automatique

Pour surveiller automatiquement les services, ajoutez une tâche cron :

```bash
# Éditer la crontab
crontab -e

# Ajouter cette ligne pour vérifier toutes les 15 minutes
*/15 * * * * /opt/technicia/scripts/monitor.sh --check
```

## Dépannage

### Problèmes de connexion aux services externes

Si vous rencontrez des problèmes de connexion aux services Google Cloud, Anthropic ou VoyageAI :

1. Vérifiez les fichiers de log :
   ```bash
   docker logs technicia-document-processor
   docker logs technicia-vision-classifier
   ```

2. Vérifiez que les identifiants sont correctement configurés dans le fichier `.env`

3. Vérifiez les quotas et les restrictions d'accès sur les services externes

### Problèmes de démarrage des conteneurs

Si certains conteneurs ne démarrent pas :

1. Vérifiez les logs du conteneur :
   ```bash
   docker logs <nom-du-conteneur>
   ```

2. Vérifiez que les ports ne sont pas utilisés par d'autres services :
   ```bash
   sudo netstat -tulpn | grep <numéro-de-port>
   ```

3. Reconstruisez et redémarrez les services :
   ```bash
   cd /opt/technicia/docker
   docker-compose down
   docker-compose up -d --build
   ```

## Mise à jour

Pour mettre à jour le système vers une nouvelle version :

```bash
# Utilisez le script de déploiement qui mettra à jour le code
/opt/technicia/scripts/deploy.sh
```

Si vous préférez une mise à jour manuelle :

```bash
cd /opt/technicia
git pull origin main
cd docker
docker-compose down
docker-compose up -d --build
```

## Sauvegarde et restauration

### Sauvegarde

```bash
# Créer un répertoire de sauvegarde
mkdir -p /opt/backups/technicia

# Sauvegarder les données de Qdrant
tar -czf /opt/backups/technicia/qdrant-$(date +%Y%m%d).tar.gz -C /opt/technicia/docker/qdrant storage

# Sauvegarder les workflows n8n
tar -czf /opt/backups/technicia/n8n-$(date +%Y%m%d).tar.gz -C /opt/technicia/docker/n8n data

# Sauvegarder la configuration
cp /opt/technicia/.env /opt/backups/technicia/.env.$(date +%Y%m%d)
cp /opt/technicia/docker/credentials/google-credentials.json /opt/backups/technicia/google-credentials.$(date +%Y%m%d).json
```

### Restauration

```bash
# Arrêter les services
cd /opt/technicia/docker
docker-compose down

# Restaurer les données de Qdrant
rm -rf /opt/technicia/docker/qdrant/storage
mkdir -p /opt/technicia/docker/qdrant
tar -xzf /opt/backups/technicia/qdrant-YYYYMMDD.tar.gz -C /opt/technicia/docker/qdrant

# Restaurer les workflows n8n
rm -rf /opt/technicia/docker/n8n/data
mkdir -p /opt/technicia/docker/n8n
tar -xzf /opt/backups/technicia/n8n-YYYYMMDD.tar.gz -C /opt/technicia/docker/n8n

# Restaurer la configuration
cp /opt/backups/technicia/.env.YYYYMMDD /opt/technicia/.env
mkdir -p /opt/technicia/docker/credentials
cp /opt/backups/technicia/google-credentials.YYYYMMDD.json /opt/technicia/docker/credentials/google-credentials.json

# Redémarrer les services
docker-compose up -d
```

## Conclusion

En suivant ce guide, vous devriez avoir un déploiement fonctionnel du MVP de TechnicIA sur votre serveur VPS. Si vous rencontrez des problèmes ou avez besoin d'assistance supplémentaire, consultez les ressources de dépannage ou contactez l'équipe de support.
