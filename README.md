# TechnicIA - Assistant Intelligent de Maintenance Technique

![TechnicIA Logo](docs/images/logo.png)

TechnicIA est un assistant intelligent de maintenance technique qui aide les techniciens à accéder rapidement à l'information pertinente et à diagnostiquer efficacement les problèmes sur les équipements industriels.

## 🚀 Fonctionnalités du MVP

- **Ingestion intelligente de documentation technique**
  - Traitement de fichiers PDF (manuels, schémas, etc.)
  - Extraction précise de texte et d'images via Document AI
  - Classification automatique des schémas techniques

- **Base de connaissances vectorielle**
  - Vectorisation du contenu textuel et visuel
  - Recherche sémantique avancée
  - Organisation structurée des données

- **Assistant de diagnostic intelligent**
  - Compréhension des descriptions de pannes en langage naturel
  - Méthodologie de diagnostic systématique
  - Recommandations techniques basées sur la documentation

- **Interface intuitive**
  - Upload simple de documents
  - Interface conversationnelle
  - Visualisation contextuelle des schémas

## 📋 Prérequis

- Docker et Docker Compose
- Compte Google Cloud avec Document AI et Vision AI configurés
- Compte VoyageAI pour les embeddings (ou OpenAI comme alternative)
- 4 Go de RAM minimum pour exécuter les services

## ⚙️ Installation

1. **Cloner le dépôt**
   ```bash
   git clone https://github.com/aurelienbran/technicia-mvp.git
   cd technicia-mvp
   ```

2. **Configurer les variables d'environnement**
   ```bash
   cp .env.example .env
   # Modifiez le fichier .env avec vos propres valeurs
   ```

3. **Configurer les identifiants Google Cloud**
   - Téléchargez votre fichier de credentials JSON depuis Google Cloud
   - Placez-le dans `services/document-processor/google-credentials.json`
   - Placez une copie dans `services/schema-analyzer/google-credentials.json`

4. **Démarrer les services**
   ```bash
   docker-compose up -d
   ```

## 🔧 Architecture

L'architecture de TechnicIA est basée sur des microservices interconnectés:

```
┌───────────────┐      ┌─────────────────┐
│  Frontend     │<────>│  n8n            │
│  (Interface)  │      │  (Orchestration)│
└───────────────┘      └────────┬────────┘
                                │
       ┌──────────────┬─────────┼─────────┬─────────────┐
       │              │         │         │             │
┌──────▼─────┐ ┌──────▼─────┐ ┌─▼───────┐ ┌───────────┐ ┌───────────┐
│ Document   │ │ Schema     │ │ Vector  │ │ Qdrant    │ │ Diagnosis │
│ Processor  │ │ Analyzer   │ │ Engine  │ │ (Vector DB)│ │ Engine   │
└────────────┘ └────────────┘ └─────────┘ └───────────┘ └───────────┘
```

- **Document Processor**: Extraction du texte et des images des PDFs
- **Schema Analyzer**: Classification des schémas techniques
- **Vector Engine**: Vectorisation et indexation du contenu
- **Qdrant**: Base de données vectorielle
- **n8n**: Orchestration des workflows

## 🖥️ Utilisation

### Interface n8n

Après le démarrage, accédez à l'interface n8n:
- URL: http://localhost:5678
- Identifiants par défaut: admin / TechnicIA2025!

### Importer et activer le workflow d'ingestion

1. Dans n8n, allez dans "Workflows"
2. Cliquez sur "Import from File"
3. Sélectionnez le fichier `workflows/technicia-ingestion.json`
4. Une fois importé, activez le workflow avec le bouton "Active"

### Importer un PDF pour test

```bash
curl -X POST -F "file=@chemin/vers/votre/document.pdf" http://localhost:5678/webhook/upload
```

### Vérifier l'état du traitement

```bash
docker-compose logs -f document-processor
```

## 🔍 Workflows disponibles

### technicia-ingestion.json

Ce workflow gère l'ingestion des documents PDF:
1. Réception du PDF via webhook
2. Validation et écriture du fichier
3. Traitement par Document Processor
4. Analyse des schémas techniques par Schema Analyzer
5. Vectorisation et indexation par Vector Engine
6. Notification de fin de traitement

### question.json

Ce workflow permet de poser des questions sur les documents indexés:
1. Réception de la question via webhook
2. Recherche de contexte pertinent dans Qdrant
3. Génération de réponse avec Claude 3.5 ou GPT-4
4. Inclusion des schémas pertinents dans la réponse

## 🛠️ Maintenance

### Arrêter les services

```bash
docker-compose down
```

### Nettoyer et redémarrer

```bash
docker-compose down -v
docker-compose up -d --build
```

## 📊 Performances

Le MVP est conçu pour traiter des documents techniques avec les caractéristiques suivantes:
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
