# Guide Complet de Déploiement de TechnicIA MVP

Ce guide détaille les étapes nécessaires pour installer et déployer le MVP de TechnicIA sur un serveur VPS (Virtual Private Server).

## Table des matières

1. [Introduction](#introduction)
2. [Prérequis](#prérequis)
3. [Préparation du serveur](#préparation-du-serveur)
4. [Clonage du repository](#clonage-du-repository)
5. [Configuration](#configuration)
6. [Déploiement](#déploiement)
   - [Méthode automatisée (recommandée)](#méthode-automatisée-recommandée)
   - [Méthode manuelle](#méthode-manuelle)
7. [Scripts de configuration automatique](#scripts-de-configuration-automatique)
   - [Configuration de n8n](#configuration-de-n8n)
   - [Configuration HTTPS](#configuration-https)
   - [Configuration de Qdrant](#configuration-de-qdrant)
   - [Configuration des workflows](#configuration-des-workflows)
8. [Vérification](#vérification)
9. [Monitoring](#monitoring)
10. [Sauvegarde et restauration](#sauvegarde-et-restauration)
11. [Dépannage](#dépannage)
12. [Mise à jour](#mise-à-jour)

## Introduction

TechnicIA est un assistant intelligent de maintenance technique qui aide les techniciens à accéder rapidement à l'information pertinente et à diagnostiquer efficacement les problèmes sur les équipements industriels. Ce guide détaille l'ensemble du processus de déploiement et de configuration sur un serveur VPS.

## Prérequis

- Un VPS sous Ubuntu Server 22.04 LTS avec au moins :
  - 8 Go de RAM
  - 4 vCPUs
  - 100 Go d'espace disque SSD
- Accès SSH au serveur avec privilèges sudo
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

Pour installer Docker de manière moderne et sécurisée :

```bash
# Désinstaller les anciens packages Docker si nécessaire
sudo apt-get remove docker docker-engine docker.io containerd runc

# Installer les packages requis
sudo apt-get install -y ca-certificates curl gnupg

# Créer le répertoire pour les clés
sudo install -m 0755 -d /etc/apt/keyrings

# Télécharger et installer la clé GPG de Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Ajouter le repository Docker
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Mettre à jour les paquets et installer Docker
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Ajouter l'utilisateur au groupe docker
sudo usermod -aG docker $USER
newgrp docker

# Installer Docker Compose v2
sudo apt-get install -y docker-compose-plugin
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
ANTHROPIC_API_KEY=<votre-clé-anthropic>
EOF
```

Remplacez les valeurs `<votre-...>` par vos propres clés et identifiants.

### Génération de la clé de chiffrement n8n

Pour générer une clé forte pour la variable d'environnement `N8N_ENCRYPTION_KEY` :

```bash
# Générer une clé de chiffrement aléatoire
openssl rand -hex 24
```

Copiez la clé générée dans votre fichier `.env` pour la variable `N8N_ENCRYPTION_KEY`.

### Configuration Google Cloud

Placez votre fichier d'identifiants Google Cloud dans le dossier approprié :

```bash
# Créer le répertoire des identifiants
mkdir -p /opt/technicia/docker/credentials

# Copiez votre fichier d'identifiants Google Cloud
# Exemple avec scp depuis votre machine locale:
# scp your-google-credentials.json user@your-server:/opt/technicia/docker/credentials/google-credentials.json
```

## Déploiement

### Méthode automatisée (recommandée)

TechnicIA fournit un script de déploiement automatisé qui configure tous les services nécessaires et applique des correctifs pour éviter les problèmes connus :

```bash
# Donner les permissions d'exécution au script
chmod +x /opt/technicia/scripts/deploy.sh

# Exécuter le script de déploiement
/opt/technicia/scripts/deploy.sh
```

Le script effectue les opérations suivantes :
1. Vérifie les prérequis
2. Sauvegarde l'environnement existant (si applicable)
3. Met à jour le code source tout en préservant les modifications locales importantes
4. Configure l'environnement et applique automatiquement les correctifs nécessaires
5. Construit et démarre les services Docker
6. Vérifie que tous les services sont opérationnels

Les correctifs automatiques incluent :
- Correction du Dockerfile frontend (utilisation de `npm install` au lieu de `npm ci`) 
- Création de la structure minimale pour le frontend (répertoire `public` et fichiers requis)
- Optimisation du chargement des variables d'environnement

### Méthode manuelle

Si vous préférez une approche manuelle, vous pouvez déployer les services étape par étape :

```bash
# Configurer l'environnement
cp /opt/technicia/.env /opt/technicia/docker/.env

# Construire et démarrer les services
cd /opt/technicia/docker
docker compose up -d
```

## Scripts de configuration automatique

TechnicIA inclut plusieurs scripts de configuration automatique qui facilitent le déploiement et la configuration des différents services :

### Configuration de n8n

Pour configurer n8n avec votre adresse IP ou nom de domaine:

```bash
# Donner les permissions d'exécution au script
chmod +x /opt/technicia/scripts/configure-n8n.sh

# Configurer n8n avec votre IP ou domaine
/opt/technicia/scripts/configure-n8n.sh votre-ip-ou-domaine

# Si vous prévoyez d'utiliser HTTPS
/opt/technicia/scripts/configure-n8n.sh votre-domaine yes
```

Le script configure automatiquement:
- L'hôte n8n dans le docker-compose.yml
- Le protocole (HTTP ou HTTPS)
- L'URL des webhooks
- Et redémarre le conteneur n8n pour appliquer les changements

### Configuration HTTPS

Si vous avez un nom de domaine, vous pouvez configurer HTTPS automatiquement :

```bash
# Donner les permissions d'exécution au script
chmod +x /opt/technicia/scripts/configure-https.sh

# Configurer HTTPS (Let's Encrypt + Nginx)
/opt/technicia/scripts/configure-https.sh votre-domaine votre-email@example.com
```

Le script effectue automatiquement :
1. Installation de Certbot
2. Obtention d'un certificat SSL pour votre domaine
3. Configuration de Nginx comme proxy inverse
4. Configuration de n8n pour utiliser HTTPS
5. Configuration du renouvellement automatique des certificats

### Configuration de Qdrant

Pour initialiser et configurer la base de données vectorielle Qdrant :

```bash
# Donner les permissions d'exécution au script
chmod +x /opt/technicia/scripts/setup-qdrant.sh

# Initialiser Qdrant avec la collection par défaut
/opt/technicia/scripts/setup-qdrant.sh

# Ou avec un nom de collection personnalisé
/opt/technicia/scripts/setup-qdrant.sh nom-collection-personnalisee
```

Le script :
1. Vérifie si Qdrant est en cours d'exécution
2. Crée la collection si elle n'existe pas déjà
3. Configure les index nécessaires pour les métadonnées
4. Vérifie l'accessibilité de l'API Qdrant

### Configuration des workflows

Pour configurer les workflows n8n (importation et configuration des credentials) :

```bash
# Donner les permissions d'exécution au script
chmod +x /opt/technicia/scripts/setup-workflows.sh

# Lancer le script avec l'URL de n8n
/opt/technicia/scripts/setup-workflows.sh http://votre-ip:5678
```

**Note**: Actuellement ce script fournit des instructions pour l'importation manuelle des workflows. L'importation automatique sera disponible dans une version future.

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

### Tests fonctionnels

1. **Test d'ingestion de document**: 
   - Téléchargez un PDF de test sur l'interface
   - Vérifiez que le workflow d'ingestion s'exécute correctement
   - Confirmez que le document est traité et indexé dans Qdrant

2. **Test de question-réponse**:
   - Posez une question relative au document téléchargé
   - Vérifiez que le système récupère et affiche les bonnes informations

3. **Test du diagnostic guidé**:
   - Lancez un processus de diagnostic
   - Suivez les étapes et vérifiez que les recommandations sont cohérentes

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

### Journalisation (Logging)

Pour consulter les logs de chaque service :

```bash
# Tous les services
cd /opt/technicia/docker
docker compose logs -f

# Service spécifique
docker compose logs -f n8n
docker compose logs -f document-processor
docker compose logs -f vision-classifier
docker compose logs -f vector-store
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
docker compose down

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
docker compose up -d
```

## Dépannage

### Problèmes connus et solutions

Le script `deploy.sh` inclut des correctifs automatiques pour les problèmes connus suivants :

1. **Problème avec le Dockerfile du frontend**
   - **Symptôme** : Erreur `npm ERR! Couldn't find npm-shrinkwrap.json or package-lock.json` lors de la construction
   - **Solution** : Le script remplace automatiquement `npm ci` par `npm install` dans le Dockerfile

2. **Structure incomplète du frontend**
   - **Symptôme** : Erreur de construction du frontend indiquant que le fichier `public/index.html` est manquant
   - **Solution** : Le script crée automatiquement la structure minimale requise

3. **Variables d'environnement non chargées**
   - **Symptôme** : Docker Compose affiche des avertissements sur les variables d'environnement non définies
   - **Solution** : Le script crée un lien symbolique du fichier `.env` vers le répertoire Docker et exporte les variables

### Problèmes avec les webhooks n8n

Si vous rencontrez des problèmes avec le téléversement de fichiers PDF ou d'autres fonctionnalités basées sur les webhooks :

1. Consultez le guide de dépannage des webhooks pour des instructions spécifiques : [webhook-troubleshooting.md](webhook-troubleshooting.md)

2. Vérifiez que les webhooks dans n8n sont correctement configurés :
   - Méthode HTTP correcte (POST pour les téléversements de fichiers)
   - Options de traitement des données binaires activées
   - Chemin d'accès correct

3. Testez les webhooks avec des outils comme Postman ou curl avant d'utiliser l'interface utilisateur

Pour plus de détails sur ces problèmes et d'autres, consultez le fichier [deployment-issues.md](deployment-issues.md).

### Problèmes de connexion aux services externes

Si vous rencontrez des problèmes de connexion aux services Google Cloud, Anthropic ou VoyageAI :

1. Vérifiez les fichiers de log :
   ```bash
   docker logs technicia-document-processor
   docker logs technicia-vision-classifier
   ```

2. Vérifiez que les identifiants sont correctement configurés dans le fichier `.env`

3. Vérifiez les quotas et les restrictions d'accès sur les services externes

### Problèmes spécifiques à n8n

Si vous rencontrez des problèmes avec n8n (workflows non déclenchés, erreurs d'API, etc.), consultez la section [Dépannage du guide de configuration n8n](n8n-config-guide.md#dépannage) pour des solutions détaillées.

## Mise à jour

Pour mettre à jour le système vers une nouvelle version :

```bash
# Utilisez le script de déploiement amélioré qui préserve les configurations locales
/opt/technicia/scripts/deploy.sh
```

Si vous préférez une mise à jour manuelle :

```bash
cd /opt/technicia
git pull origin main
cd docker
docker compose down
docker compose up -d --build
```

### Mise à jour des images Docker uniquement

Si vous souhaitez uniquement mettre à jour les images Docker sans toucher à la configuration :

```bash
cd /opt/technicia/docker
docker compose pull
docker compose down
docker compose up -d
```

## Résumé des scripts disponibles

TechnicIA inclut plusieurs scripts pour faciliter le déploiement et la configuration :

| Script | Description | Utilisation |
|--------|-------------|-------------|
| `deploy.sh` | Script principal de déploiement | `/opt/technicia/scripts/deploy.sh` |
| `configure-n8n.sh` | Configuration de n8n | `/opt/technicia/scripts/configure-n8n.sh votre-ip-ou-domaine [use-https]` |
| `configure-https.sh` | Configuration HTTPS | `/opt/technicia/scripts/configure-https.sh votre-domaine [email]` |
| `setup-qdrant.sh` | Initialisation de Qdrant | `/opt/technicia/scripts/setup-qdrant.sh [nom-collection]` |
| `setup-workflows.sh` | Configuration des workflows n8n | `/opt/technicia/scripts/setup-workflows.sh [n8n-url]` |
| `monitor.sh` | Surveillance des services | `/opt/technicia/scripts/monitor.sh --check` |

## Conclusion

En suivant ce guide, vous devriez avoir un déploiement fonctionnel du MVP de TechnicIA sur votre serveur VPS. Les scripts automatisés simplifient considérablement le processus de déploiement et de configuration.

Pour une documentation détaillée sur la configuration de n8n, consultez le [Guide de Configuration n8n](n8n-config-guide.md) dédié.

Pour résoudre les problèmes liés aux webhooks, notamment pour le téléversement de fichiers, consultez le [Guide de dépannage des webhooks](webhook-troubleshooting.md).

Si vous rencontrez des problèmes, consultez les fichiers de documentation spécifiques ou contactez l'équipe de support.

Assurez-vous de surveiller régulièrement les performances et l'état des services, et de mettre à jour le système lorsque de nouvelles versions sont disponibles. Effectuez également des sauvegardes périodiques pour éviter toute perte de données.
