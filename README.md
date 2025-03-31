# TechnicIA - Assistant Intelligent de Maintenance Technique (MVP v1)

![TechnicIA Logo](docs/images/logo.png)

TechnicIA est un assistant intelligent de maintenance technique qui aide les techniciens à accéder rapidement à l'information pertinente et à diagnostiquer efficacement les problèmes sur les équipements industriels.

## 🚀 Fonctionnalités du MVP v1

- **Ingestion intelligente de documentation technique**
  - Traitement de fichiers PDF (manuels, schémas, etc.)
  - Extraction précise de texte et d'images via Document AI
  - Classification automatique des schémas techniques
  - Support pour documents jusqu'à 150 Mo

- **Base de connaissances vectorielle**
  - Vectorisation du contenu textuel et visuel
  - Recherche sémantique avancée
  - Organisation structurée des données
  - Métadonnées riches pour chaque élément indexé

- **Assistant de diagnostic intelligent**
  - Compréhension des descriptions de pannes en langage naturel
  - Méthodologie de diagnostic systématique
  - Recommandations techniques basées sur la documentation
  - Visualisation des composants concernés sur les schémas

- **Interface intuitive**
  - Upload simple de documents
  - Interface conversationnelle
  - Visualisation contextuelle des schémas
  - Module de diagnostic guidé

## 📋 Prérequis

- Docker et Docker Compose v2.x ou supérieur
- Compte Google Cloud avec Document AI et Vision AI configurés
- Compte VoyageAI pour les embeddings (ou OpenAI comme alternative)
- Compte Anthropic pour utiliser Claude 3.5 Sonnet
- 4 Go de RAM minimum pour exécuter les services
- 10 Go d'espace disque disponible

## ⚙️ Installation

### 1. Cloner le dépôt et accéder à la branche MVP v1

```bash
git clone https://github.com/aurelienbran/technicia-mvp.git
cd technicia-mvp
git checkout mvp-v1
```

### 2. Configurer les variables d'environnement

```bash
cp .env.example .env
```

Éditez le fichier `.env` avec vos propres valeurs. Configuration minimale requise:

```
# Google Cloud
DOCUMENT_AI_PROJECT=votre-projet-gcp
DOCUMENT_AI_LOCATION=votre-région-gcp
DOCUMENT_AI_PROCESSOR_ID=votre-processor-id

# Embeddings (choisir l'un ou l'autre)
VOYAGE_API_KEY=votre-clé-voyage-ai
# OU
OPENAI_API_KEY=votre-clé-openai

# Anthropic API pour Claude
ANTHROPIC_API_KEY=votre-clé-anthropic
ANTHROPIC_MODEL=claude-3-5-sonnet-20240620

# n8n (ne pas modifier)
N8N_USER=admin
N8N_PASSWORD=TechnicIA2025!
```

### 3. Configurer les identifiants Google Cloud

- Téléchargez votre fichier de credentials JSON depuis Google Cloud Console
- Placez-le dans les emplacements suivants:
  ```bash
  mkdir -p services/document-processor/
  mkdir -p services/schema-analyzer/
  cp votre-fichier-credentials.json services/document-processor/google-credentials.json
  cp votre-fichier-credentials.json services/schema-analyzer/google-credentials.json
  ```

### 4. Démarrer les services

```bash
# Rendre le script exécutable
chmod +x scripts/start-technicia.sh

# Démarrer les services avec construction des images
./scripts/start-technicia.sh --build
```

## 🔧 Architecture du MVP v1

L'architecture de TechnicIA MVP v1 est basée sur des microservices interconnectés:

```
┌───────────────┐      ┌─────────────────┐
│  Frontend     │<────>│  n8n            │
│  (Interface)  │      │  (Orchestration)│
└───────────────┘      └────────┬────────┘
                                │
┌─────────────┬─────────────┬───▼────────┬───────────┬───────────┐
│             │             │            │           │           │
│  Document   │  Schema     │  Vector    │  Vector   │  Claude   │
│  Processor  │  Analyzer   │  Engine    │  Store    │  Service  │
└──────┬──────┘└──────┬─────┘└─────┬─────┘└─────┬────┘└─────┬────┘
       │              │           │            │           │
       │              │           │            │           │
       └──────────────┴───────────┴────────────┴───────────┘
                                  │
                                  ▼
                            ┌────────────┐
                            │  Qdrant    │
                            │ (Vector DB)│
                            └────────────┘
```

### Rôles des microservices

- **Document Processor**: Traitement des PDF et extraction du contenu textuel et visuel via Google Document AI.
- **Schema Analyzer**: Classification des images techniques et extraction de contenu via Google Vision AI.
- **Vector Engine**: Gestion des embeddings et indexation, incluant le chunking de texte et la création de vecteurs d'embeddings.
- **Vector Store**: Service dédié à la recherche vectorielle qui offre une API simplifiée pour interagir avec Qdrant.
- **Claude Service**: Interface robuste avec l'API Claude d'Anthropic, gérant les prompts, le contexte et les mécanismes de retry.
- **Qdrant**: Base de données vectorielle pour le stockage et la recherche efficace des embeddings.
- **n8n**: Orchestrateur de workflows qui coordonne les interactions entre les services.

## 🖥️ Utilisation

### Interface n8n

Après le démarrage, accédez à l'interface n8n:
- URL: http://localhost:5678
- Identifiants par défaut: admin / TechnicIA2025!

### Configuration des credentials pour Claude dans n8n

1. Après vous être connecté à l'interface n8n, cliquez sur **Settings** (⚙️) dans le menu latéral
2. Sélectionnez **Credentials** dans le menu déroulant
3. Cliquez sur le bouton **+ Add Credential**
4. Choisissez le type **HTTP Header Auth** 
5. Complétez les champs suivants:
   - **Name**: Claude API Authentication
   - **Name**: x-api-key 
   - **Value**: Votre clé API Anthropic (la même que dans votre fichier .env)
6. Cliquez sur **Save**

Ce credential sera automatiquement utilisé par les workflows de question et de diagnostic pour communiquer avec l'API Claude.

### Importer et activer les workflows

1. Dans n8n, allez dans "Workflows"
2. Cliquez sur "Import from File"
3. Importez les fichiers dans l'ordre suivant:
   - `workflows/technicia-ingestion-pure-microservices-fixed.json`
   - `workflows/question.json`
   - `workflows/diagnosis.json`
4. Pour chaque workflow importé, activez-le avec le bouton "Active"

### Importer un PDF pour test

```bash
# Utilisez le script d'importation
./scripts/start-technicia.sh --import chemin/vers/votre/document.pdf

# Ou utilisez curl directement
curl -X POST -F "file=@chemin/vers/votre/document.pdf" http://localhost:5678/webhook/upload
```

### Vérifier l'état du traitement

```bash
# Voir les journaux de tous les services
./scripts/start-technicia.sh --logs

# Ou vérifier un service spécifique
docker-compose logs -f document-processor
```

## 🔍 Workflows disponibles

### Workflow d'ingestion

Ce workflow gère l'ingestion des documents PDF:
1. Réception du PDF via webhook
2. Validation et écriture du fichier
3. Traitement par Document Processor
4. Analyse des schémas techniques par Schema Analyzer
5. Vectorisation et indexation par Vector Engine
6. Notification de fin de traitement

### Workflow de question-réponse

Ce workflow permet de poser des questions sur les documents indexés:
1. Réception de la question via webhook
2. Recherche de contexte pertinent via Vector Store dans Qdrant
3. Génération de réponse avec Claude Service
4. Inclusion des schémas pertinents dans la réponse

### Workflow de diagnostic guidé

Ce workflow permet un diagnostic pas à pas:
1. Démarrage avec symptômes initiaux via webhook
2. Recherche de contexte initial via Vector Store
3. Génération d'un plan de diagnostic structuré via Claude Service
4. Présentation séquentielle des étapes de diagnostic
5. Collecte des résultats des tests à chaque étape
6. Génération d'un rapport final de diagnostic via Claude Service

## 🛠️ Maintenance

### Arrêter les services

```bash
./scripts/start-technicia.sh --stop
```

### Nettoyer et redémarrer

```bash
./scripts/start-technicia.sh --clean
```

### Vérifier l'état des services

```bash
./scripts/start-technicia.sh --status
```

## 🧪 Tests

Pour tester les microservices individuellement:

```bash
# Utiliser le script de test
./scripts/test-services.sh --all

# Ou tester un service spécifique
./scripts/test-services.sh --document-processor
./scripts/test-services.sh --schema-analyzer
./scripts/test-services.sh --vector-engine
./scripts/test-services.sh --vector-store
./scripts/test-services.sh --claude-service
```

## 📊 Performances du MVP v1

Le MVP v1 est conçu pour traiter des documents techniques avec les caractéristiques suivantes:
- Taille de fichier: jusqu'à 150 Mo
- Types de documents: PDF (manuels techniques, schémas, guides)
- Temps de traitement moyen: ~1-2 min pour un document de 50 pages
- Temps de réponse aux requêtes: < 3 secondes

## 🧩 Perspectives d'évolution

- Intégration vocale pour l'interaction mains-libres sur le terrain
- Application mobile dédiée pour les techniciens
- Identification automatique de composants par photo
- Génération de procédures de maintenance préventive
- Amélioration du moteur de diagnostic par apprentissage actif

## 👨‍💻 Contribution

Les contributions sont les bienvenues! Veuillez:
1. Fork le projet
2. Créer une branche pour votre fonctionnalité (`git checkout -b feature/amazing-feature`)
3. Commit vos changements (`git commit -m 'Add some amazing feature'`)
4. Push vers la branche (`git push origin feature/amazing-feature`)
5. Ouvrir une Pull Request

## 📄 Licence

Ce projet est sous licence [MIT](LICENSE).

## 🙏 Remerciements

- Google Cloud pour Document AI et Vision AI
- VoyageAI pour les embeddings multimodaux
- Qdrant pour la recherche vectorielle performante
- n8n pour l'orchestration des workflows
- Anthropic/OpenAI pour les modèles d'IA de dialogue
