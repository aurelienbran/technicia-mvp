# TechnicIA - MVP

TechnicIA est un assistant intelligent de maintenance technique qui aide les techniciens à accéder rapidement à l'information pertinente et à diagnostiquer efficacement les problèmes sur les équipements industriels.

## Architecture Globale

L'architecture du MVP est basée sur une approche hybride qui combine :

```
┌─────────────────┐      ┌───────────────────────┐      ┌────────────────────┐
│  Interface Web   │◄────►│ Workflows n8n (Orch.) │◄────►│ Microservices Python│
└────────┬─────────┘      └──────────┬────────────┘      └─────────┬──────────┘
         │                           │                             │
         │         ┌─────────────────▼────────────────┐            │
         └────────►│       Services Google Cloud       │◄───────────┘
                   │  (Document AI, Vision AI, etc.)   │
                   └─────────────────┬────────────────┘
                                     │
                                     ▼
                   ┌─────────────────────────────────┐
                   │          Qdrant (VPS OVH)        │
                   └─────────────────────────────────┘
```

## Fonctionnalités Principales

1. **Ingestion intelligente de documentation technique**
   - Traitement des PDF jusqu'à 150 MB
   - Extraction et OCR du contenu textuel via Document AI
   - Classification des schémas techniques via Vision AI
   
2. **Base de connaissances vectorielle**
   - Stockage et indexation dans Qdrant
   - Recherche sémantique avancée
   - Métadonnées structurées avec liens texte-schémas
   
3. **Assistant de diagnostic intelligent**
   - Aide au diagnostic avec approche méthodologique
   - Affichage des schémas techniques pertinents
   - Suggestions de tests et de vérifications

## Structure du Repository

```
technicia-mvp/
├── README.md                   # Ce fichier
├── docs/                       # Documentation
│   ├── architecture.md         # Architecture détaillée
│   ├── technicia-deployment-guide.md  # Guide complet de déploiement
│   ├── deployment-tracking.md  # Suivi du déploiement
│   ├── deployment-issues.md    # Suivi des problèmes
│   └── workflows.md            # Description des workflows n8n
├── docker/                     # Configuration Docker
│   ├── docker-compose.yml      # Configuration pour tous les services
│   ├── n8n/                    # Configuration n8n
│   └── qdrant/                 # Configuration Qdrant
├── services/                   # Microservices
│   ├── document-processor/     # Service de traitement des documents
│   ├── vision-classifier/      # Service de classification des schémas
│   └── vector-store/           # Service d'interface avec Qdrant
├── scripts/                    # Scripts utilitaires
│   ├── deploy.sh               # Script de déploiement automatisé
│   └── monitor.sh              # Script de surveillance
└── workflows/                  # Workflows n8n (JSON)
    ├── ingestion.json          # Workflow d'ingestion de documents
    ├── question.json           # Workflow de traitement des questions
    └── diagnosis.json          # Workflow de diagnostic guidé
```

## Plan d'Implémentation

### 1. Préparation de l'Infrastructure VPS OVH

#### Configuration Recommandée
- VPS avec 8+ Go RAM, 4+ vCPUs et 100+ Go SSD
- Ubuntu Server 22.04 LTS
- Docker et Docker Compose

#### Ports Requis
- 22/tcp : SSH
- 80/tcp & 443/tcp : HTTP/HTTPS
- 5678/tcp : n8n
- 6333/tcp : Qdrant API
- 8001-8003/tcp : Microservices Python

### 2. Microservices Python (FastAPI)

Trois services principaux :

#### Document Processor Service (Port 8001)
- Interface avec Google Document AI
- Traitement asynchrone des PDFs volumineux
- Extraction optimisée du texte et des images

#### Vision Classifier Service (Port 8002)
- Interface avec Google Vision AI
- Classification des schémas (électriques, hydrauliques, pneumatiques)
- OCR spécialisé pour les annotations des schémas

#### Vector Store Interface (Port 8003)
- Interface avec Qdrant
- Gestion des embeddings via VoyageAI
- Recherche sémantique optimisée

### 3. Configuration de n8n

Trois workflows principaux :

#### Workflow d'Ingestion
- Upload et validation de PDF
- Orchestration du traitement avec Document AI et Vision AI
- Stockage dans Qdrant via le service Vector Store

#### Workflow de Questions
- Réception et formatage des questions
- Recherche contextuelle dans Qdrant
- Génération de réponses avec Claude 3 Sonnet

#### Workflow de Diagnostic
- Processus guidé en plusieurs étapes
- Analyse des réponses et recommandations
- Rapport de diagnostic final

### 4. Déploiement

Le déploiement utilisera Docker et Docker Compose pour l'ensemble des services. Consultez le [Guide Complet de Déploiement](docs/technicia-deployment-guide.md) pour les instructions détaillées.

## Prérequis

- Compte Google Cloud avec Document AI et Vision AI activés
- Clés API Anthropic (Claude 3 Sonnet)
- Clés API VoyageAI pour les embeddings
- VPS OVH avec accès SSH

## Installation et Configuration

Consultez le [Guide Complet de Déploiement](docs/technicia-deployment-guide.md) pour les instructions d'installation et de configuration.

## Monitoring et Maintenance

Le projet inclut des scripts de surveillance pour s'assurer du bon fonctionnement des services. 
Consultez la section [Monitoring](docs/technicia-deployment-guide.md#monitoring) du guide de déploiement.

## Dépannage

En cas de problème, consultez la section [Dépannage](docs/technicia-deployment-guide.md#dépannage) du guide de déploiement 
ou référez-vous au fichier [deployment-issues.md](docs/deployment-issues.md) pour les problèmes connus et leurs solutions.

## Licence

Tous droits réservés.
