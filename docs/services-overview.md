# Vue d'ensemble des services TechnicIA

Ce document fournit une description détaillée de chaque service dans l'architecture TechnicIA, leurs responsabilités, leurs interfaces et leurs interactions.

## Architecture globale

L'architecture de TechnicIA est composée de plusieurs microservices interconnectés:

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

## Description des services

### 1. Document Processor

**Responsabilité principale**: Traitement des PDF et extraction du contenu textuel et visuel.

**Fonctionnalités**:
- Réception et analyse des documents PDF
- Extraction du texte et des images via Google Document AI
- Segmentation du contenu en blocs structurés
- Extraction des métadonnées des documents

**API**:
- `POST /process` - Traite un document PDF et extrait son contenu
- `GET /health` - Vérifie l'état du service

**Port**: 8001

**Dépendances**:
- Google Document AI
- Stockage partagé pour les documents

### 2. Schema Analyzer

**Responsabilité principale**: Analyse et classification des schémas techniques.

**Fonctionnalités**:
- Classification des images (schéma technique vs image décorative)
- OCR sur les schémas pour extraire les annotations
- Détection des types de schémas (électrique, hydraulique, pneumatique, etc.)
- Localisation des composants dans les schémas

**API**:
- `POST /analyze` - Analyse et classifie une image
- `GET /health` - Vérifie l'état du service

**Port**: 8002

**Dépendances**:
- Google Vision AI
- Stockage partagé pour les images

### 3. Vector Engine

**Responsabilité principale**: Vectorisation et indexation du contenu.

**Fonctionnalités**:
- Chunking intelligent des documents
- Génération d'embeddings pour le texte via Voyage AI ou OpenAI
- Indexation des embeddings dans Qdrant
- Gestion des métadonnées associées aux chunks

**API**:
- `POST /api/process` - Traite et indexe le contenu d'un document
- `GET /api/document/{document_id}/status` - Vérifie l'état d'indexation d'un document
- `GET /health` - Vérifie l'état du service

**Port**: 8003

**Dépendances**:
- Qdrant
- Voyage AI / OpenAI

### 4. Vector Store

**Responsabilité principale**: Recherche sémantique dans la base vectorielle.

**Fonctionnalités**:
- API simplifiée pour la recherche dans Qdrant
- Génération d'embeddings pour les requêtes
- Filtrage et tri des résultats
- Formatage des réponses pour le workflow de questions

**API**:
- `POST /search` - Recherche des éléments similaires à la requête
- `POST /embed-text` - Crée un embedding à partir d'un texte
- `POST /embed-image` - Crée un embedding à partir d'une image
- `GET /health` - Vérifie l'état du service

**Port**: 8000

**Dépendances**:
- Qdrant
- Vector Engine (pour les fonctionnalités de recherche avancées)
- Voyage AI / OpenAI

### 5. Claude Service

**Responsabilité principale**: Interface robuste avec l'API Claude d'Anthropic.

**Fonctionnalités**:
- Génération de réponses via Claude 3.5
- Formatage des prompts contextuels
- Gestion des erreurs et retries
- Métriques de performance

**API**:
- `POST /v1/question` - Génère une réponse à une question avec contexte
- `POST /v1/diagnostic-plan` - Génère un plan de diagnostic structuré
- `POST /v1/diagnosis-report` - Génère un rapport de diagnostic
- `POST /v1/complete` - Interface générique vers l'API Claude
- `GET /health` - Vérifie l'état du service

**Port**: 8004

**Dépendances**:
- API Anthropic Claude

### 6. Qdrant

**Responsabilité principale**: Stockage et recherche vectorielle.

**Fonctionnalités**:
- Stockage des vecteurs d'embeddings
- Recherche par similarité
- Filtrage basé sur les métadonnées
- Scaling et performance pour grands volumes de données

**API**:
- API native Qdrant (utilisée par Vector Engine et Vector Store)

**Ports**: 6333, 6334

**Dépendances**:
- Aucune (service autonome)

### 7. n8n (Orchestration)

**Responsabilité principale**: Orchestration des workflows entre services.

**Fonctionnalités**:
- Coordination des appels entre services
- Gestion des webhooks pour les entrées utilisateurs
- Traitement et transformation des données
- Interface graphique pour la conception des workflows

**Workflows principaux**:
- Workflow d'ingestion - Traitement des documents
- Workflow de question - Recherche et génération de réponses
- Workflow de diagnostic - Diagnostic guidé pas à pas

**Port**: 5678

**Dépendances**:
- Tous les autres services

## Interactions entre services

### Workflow d'ingestion

1. L'utilisateur upload un PDF via n8n (webhook)
2. n8n envoie le PDF au Document Processor
3. Document Processor extrait le texte et les images
4. Les images sont envoyées au Schema Analyzer pour classification
5. Le contenu structuré est envoyé au Vector Engine
6. Vector Engine génère les embeddings et les stocke dans Qdrant

### Workflow de question

1. L'utilisateur pose une question via n8n (webhook)
2. n8n envoie la question au Vector Store pour recherche vectorielle
3. Vector Store retourne les contextes pertinents
4. n8n prépare le prompt avec le contexte
5. Le prompt est envoyé au Claude Service
6. Claude Service génère une réponse
7. n8n formate et retourne la réponse à l'utilisateur

### Workflow de diagnostic

1. L'utilisateur démarre un diagnostic via n8n (webhook)
2. n8n recherche le contexte initial via Vector Store
3. n8n envoie le contexte et les symptômes au Claude Service pour générer un plan
4. n8n présente les étapes une par une à l'utilisateur
5. Les réponses sont collectées à chaque étape
6. À la fin, n8n demande au Claude Service de générer un rapport complet

## Paramètres de configuration

Tous les services sont configurables via des variables d'environnement définies dans le fichier `.env`. Les principaux paramètres sont:

- `DOCUMENT_AI_*` - Configuration de Google Document AI
- `VOYAGE_API_KEY` / `OPENAI_API_KEY` - Clés API pour les embeddings
- `ANTHROPIC_API_KEY` - Clé API pour Claude
- `QDRANT_COLLECTION` - Nom de la collection Qdrant
- `*_PORT` - Ports pour chaque service

## Diagnostic et dépannage

En cas de problème, les éléments suivants peuvent être vérifiés:

1. **Logs des services** - `docker-compose logs [service]`
2. **Statut des services** - `./scripts/start-technicia.sh --status`
3. **Health checks** - Endpoint `/health` sur chaque service
4. **Exécutions de workflows n8n** - Interface n8n (Executions)

## Points d'extension

L'architecture est conçue pour permettre des extensions futures:

1. **Nouveaux endpoints Claude** - Ajouter de nouveaux endpoints au Claude Service
2. **Nouveaux analyseurs d'images** - Étendre Schema Analyzer
3. **Sources de données supplémentaires** - Ajouter des connecteurs à Document Processor
4. **Workflows personnalisés** - Créer des workflows spécialisés dans n8n
