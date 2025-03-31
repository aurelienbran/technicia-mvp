# Guide d'installation complet de TechnicIA MVP v1

Ce guide vous accompagne étape par étape dans l'installation et la configuration de TechnicIA, assistant intelligent de maintenance technique basé sur l'IA.

## Prérequis

- **Système d'exploitation**: Linux (recommandé), macOS, ou Windows avec WSL2
- **Docker** et **Docker Compose** installés
- **Git** installé
- Minimum 4 Go de RAM disponible
- 10 Go d'espace disque libre
- Connexion Internet pour télécharger les images

### Comptes de services requis

1. **Google Cloud Platform**
   - Compte actif avec Document AI et Vision AI activés
   - Fichier de credentials JSON

2. **VoyageAI** (ou alternative)
   - Clé API pour les embeddings
   - Ou compte OpenAI comme alternative

## Étape 1: Cloner le dépôt

```bash
# Cloner le dépôt
git clone https://github.com/aurelienbran/technicia-mvp.git

# Accéder au dossier du projet
cd technicia-mvp

# Basculer sur la branche mvp-v1 (version améliorée)
git checkout mvp-v1
```

## Étape 2: Configurer les variables d'environnement

```bash
# Copier le fichier d'exemple
cp .env.example .env

# Éditer le fichier avec vos propres valeurs
nano .env
```

Votre fichier `.env` doit contenir:

```env
# Paramètres d'authentification n8n
N8N_USER=admin
N8N_PASSWORD=VotreMotDePasseSecurisé

# Configurations Google Cloud pour Document AI et Vision
DOCUMENT_AI_PROJECT=votre-projet-id
DOCUMENT_AI_LOCATION=eu
DOCUMENT_AI_PROCESSOR_ID=votre-processor-id

# Configurations pour les embeddings
VOYAGE_API_KEY=votre-voyage-api-key
# OU: OPENAI_API_KEY=votre-openai-api-key

# Configurations Qdrant
QDRANT_COLLECTION=technicia
```

## Étape 3: Configurer les identifiants Google Cloud

Téléchargez votre fichier de credentials JSON depuis la console Google Cloud et placez-le dans ces emplacements:

```bash
# Créer les dossiers si nécessaires
mkdir -p services/document-processor
mkdir -p services/schema-analyzer

# Copier le fichier de credentials
cp chemin/vers/votre-fichier-credentials.json services/document-processor/google-credentials.json
cp chemin/vers/votre-fichier-credentials.json services/schema-analyzer/google-credentials.json
```

## Étape 4: Rendre les scripts exécutables

```bash
# Rendre les scripts exécutables
chmod +x scripts/start-technicia.sh
chmod +x scripts/test-services.sh
chmod +x scripts/migrate-technicia.sh
```

## Étape 5: Démarrer les services

```bash
# Vérifier que Docker est en cours d'exécution
docker info

# Démarrer tous les services avec construction des images
./scripts/start-technicia.sh --build
```

Ce script va:
1. Vérifier les prérequis
2. Construire toutes les images Docker
3. Démarrer tous les services
4. Afficher les URLs d'accès

## Étape 6: Importer et activer le workflow n8n

1. Accédez à l'interface n8n via http://localhost:5678 (utilisez les identifiants définis dans le fichier .env)
2. Allez dans l'onglet "Workflows"
3. Cliquez sur "Import from File"
4. Sélectionnez le fichier `workflows/technicia-ingestion-pure-microservices-fixed.json`
5. Une fois importé, cliquez sur le bouton "Active" pour activer le workflow

## Étape 7: Tester l'installation

### Test des services individuels

```bash
# Tester tous les services
./scripts/test-services.sh --all

# Ou tester des services spécifiques
./scripts/test-services.sh --document-processor
./scripts/test-services.sh --schema-analyzer
./scripts/test-services.sh --vector-engine
./scripts/test-services.sh --qdrant
```

### Test du workflow d'ingestion

```bash
# Importez un document PDF de test
./scripts/start-technicia.sh --import chemin/vers/votre/document.pdf

# Ou avec curl
curl -X POST -F "file=@chemin/vers/votre/document.pdf" http://localhost:5678/webhook/upload
```

## Problèmes courants et solutions

### Les services ne démarrent pas

Vérifiez les logs:
```bash
docker-compose logs
# Ou pour un service spécifique
docker-compose logs document-processor
```

### Problèmes de permissions avec les volumes Docker

```bash
# Arrêter les services
./scripts/start-technicia.sh --stop

# Fixer les permissions
sudo chown -R $USER:$USER /tmp/technicia-docs

# Redémarrer
./scripts/start-technicia.sh
```

### Erreurs liées aux API Cloud

Vérifiez que:
1. Vos credentials sont valides et placés aux bons endroits
2. Les APIs sont activées dans votre projet Google Cloud
3. Les variables d'environnement sont correctement configurées

## Commandes utiles pour la maintenance

### Vérifier l'état des services

```bash
./scripts/start-technicia.sh --status
```

### Voir les logs en temps réel

```bash
./scripts/start-technicia.sh --logs
```

### Arrêter tous les services

```bash
./scripts/start-technicia.sh --stop
```

### Nettoyer et redémarrer

```bash
./scripts/start-technicia.sh --clean
```

## Accès aux interfaces

- **n8n**: http://localhost:5678
- **Qdrant**: http://localhost:6333/dashboard
- **Frontend**: http://localhost:3000

## Sécurisation pour la production

Si vous déployez en production, assurez-vous de:

1. Utiliser HTTPS pour toutes les interfaces
2. Changer les mots de passe par défaut
3. Limiter l'accès réseau aux services sensibles
4. Configurer des sauvegardes régulières pour Qdrant

## Support et assistance

Si vous rencontrez des problèmes:

1. Consultez la documentation détaillée dans le dossier `docs/`
2. Exécutez les scripts de diagnostic: `./scripts/test-services.sh --all`
3. Vérifiez les logs avec `docker-compose logs`
