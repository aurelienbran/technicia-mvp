# Guide d'Installation et de Déploiement de TechnicIA MVP

Ce guide détaille les étapes nécessaires pour installer et déployer le MVP de TechnicIA sur un serveur VPS (Virtual Private Server).

## Table des matières

1. [Prérequis](#prérequis)
2. [Préparation du serveur](#préparation-du-serveur)
3. [Clonage du repository](#clonage-du-repository)
4. [Configuration](#configuration)
5. [Déploiement](#déploiement)
6. [Configuration de n8n](#configuration-de-n8n)
7. [Vérification](#vérification)
8. [Monitoring](#monitoring)
9. [Dépannage](#dépannage)
10. [Mise à jour](#mise-à-jour)

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

## Configuration de n8n

n8n est le moteur d'orchestration central de TechnicIA, responsable de coordonner les workflows entre les différents services. Cette section explique comment configurer et utiliser n8n dans le cadre de TechnicIA.

### Génération de la clé de chiffrement

La variable d'environnement `N8N_ENCRYPTION_KEY` est nécessaire pour sécuriser les credentials stockés dans n8n. Pour générer une clé forte:

```bash
# Générer une clé de chiffrement aléatoire
openssl rand -hex 24
```

Copiez la clé générée dans votre fichier `.env` pour la variable `N8N_ENCRYPTION_KEY`.

### Configuration des variables d'environnement n8n

Modifiez le fichier `/opt/technicia/docker/docker-compose.yml` pour ajuster les variables d'environnement de n8n:

```bash
# Remplacez "your-vps-ip-or-domain" par l'adresse IP de votre serveur ou votre nom de domaine
sed -i 's/N8N_HOST=your-vps-ip-or-domain/N8N_HOST=votre-ip-ou-domaine/' /opt/technicia/docker/docker-compose.yml

# Si vous utilisez un nom de domaine, configurez également l'URL des webhooks
sed -i 's/WEBHOOK_TUNNEL_URL=https:\/\/your-domain\/webhook\//WEBHOOK_TUNNEL_URL=https:\/\/votre-domaine.com\/webhook\//' /opt/technicia/docker/docker-compose.yml
```

### Configuration HTTPS pour n8n

Pour sécuriser n8n avec HTTPS, vous avez deux options:

1. **Configuration intégrée**:
   ```bash
   mkdir -p /opt/technicia/docker/n8n/ssl
   
   # Copier les certificats SSL (si vous utilisez Certbot)
   sudo cp /etc/letsencrypt/live/votre-domaine.com/fullchain.pem /opt/technicia/docker/n8n/ssl/
   sudo cp /etc/letsencrypt/live/votre-domaine.com/privkey.pem /opt/technicia/docker/n8n/ssl/
   sudo chown -R $USER:$USER /opt/technicia/docker/n8n/ssl/
   
   # Ajouter la configuration SSL au docker-compose.yml
   cat >> /opt/technicia/docker/docker-compose.yml << 'EOF'
     volumes:
       - ./n8n/ssl:/home/node/.n8n/ssl
     environment:
       - N8N_PROTOCOL=https
       - N8N_SSL_KEY=/home/node/.n8n/ssl/privkey.pem
       - N8N_SSL_CERT=/home/node/.n8n/ssl/fullchain.pem
   EOF
   ```

2. **Utilisation d'un proxy inverse** (recommandé pour les environnements de production):
   - Utilisez Nginx comme proxy inverse pour n8n
   - Modifiez la configuration dans le service frontend pour qu'il fasse suivre les requêtes vers n8n

### Importation des workflows TechnicIA

TechnicIA utilise plusieurs workflows n8n prédéfinis pour ses fonctionnalités:

1. **Workflow d'ingestion de documents**: Traite les PDF téléchargés avec Document AI et Vision AI
2. **Workflow de traitement des questions**: Gère les questions des utilisateurs et récupère les informations pertinentes
3. **Workflow de diagnostic guidé**: Pilote le processus de diagnostic pas à pas

Pour importer ces workflows:

```bash
# Accédez à l'interface n8n: http://votre-ip-ou-domaine:5678
# Créez un compte administrateur lors de la première connexion

# Importez les workflows depuis le répertoire workflows
cd /opt/technicia/workflows
```

Procédure d'importation dans l'interface n8n:
1. Connectez-vous à l'interface n8n
2. Cliquez sur "Workflows" dans le menu de gauche
3. Cliquez sur "Import from File"
4. Sélectionnez les fichiers de workflow (*.json) depuis le répertoire `/opt/technicia/workflows`
5. Activez chaque workflow importé en cliquant sur le bouton "Active" dans l'interface

### Configuration des credentials dans n8n

Pour que les workflows fonctionnent correctement, vous devez configurer les credentials pour les services externes:

1. Dans l'interface n8n, cliquez sur "Credentials" dans le menu de gauche
2. Ajoutez les credentials suivants:

   a. **Google Cloud Service Account**:
   - Nom: `google-cloud`
   - Upload du fichier JSON: `/opt/technicia/docker/credentials/google-credentials.json`

   b. **Anthropic API**:
   - Nom: `anthropic-api`
   - API Key: Votre clé API Anthropic (pour Claude 3.5)

   c. **Voyage AI**:
   - Nom: `voyage-api`
   - API Key: La même clé que dans votre fichier `.env` pour `VOYAGE_API_KEY`

   d. **HTTP Basic Auth** (pour les microservices):
   - Nom: `techncia-services`
   - User: `admin` (ou celui configuré dans vos microservices)
   - Password: `password` (ou celui configuré dans vos microservices)

### Test des workflows n8n

Après avoir importé et configuré les workflows, testez-les individuellement:

1. Ouvrez chaque workflow dans l'interface n8n
2. Cliquez sur "Execute Workflow" pour exécuter manuellement le workflow
3. Vérifiez les logs d'exécution pour vous assurer que chaque étape s'exécute correctement
4. Pour le workflow d'ingestion, testez avec un petit PDF d'exemple

### Dépannage des workflows n8n

Si vous rencontrez des problèmes avec les workflows n8n:

- Vérifiez que tous les credentials sont correctement configurés
- Assurez-vous que les services externes (Document AI, Vision AI, etc.) sont accessibles
- Examinez les logs n8n en exécutant `docker logs technicia-n8n`
- Vérifiez que les microservices sont accessibles depuis n8n

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

### Problèmes spécifiques à n8n

Si vous rencontrez des problèmes avec n8n:

1. **Workflows non déclenchés**:
   - Vérifiez que les webhooks sont correctement configurés
   - Assurez-vous que les workflows sont activés
   - Vérifiez les logs pour les erreurs d'exécution

2. **Erreurs de connexion aux services**:
   - Vérifiez les credentials dans n8n
   - Assurez-vous que les services sont accessibles depuis le conteneur n8n

3. **Problèmes de performance**:
   - Augmentez les ressources allouées au conteneur n8n dans le docker-compose.yml
   - Vérifiez la charge système sur le serveur

4. **Perte de données**:
   - Vérifiez que le volume de données n8n est correctement monté
   - Restaurez à partir d'une sauvegarde si nécessaire

```bash
# Vérifier l'état du volume n8n
ls -la /opt/technicia/docker/n8n/data

# Redémarrer n8n en cas de problème
docker restart technicia-n8n
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
