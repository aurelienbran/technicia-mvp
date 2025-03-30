# Guide de la nouvelle architecture de services TechnicIA

## Relation entre anciens et nouveaux services

Dans le cadre de l'amélioration de l'architecture TechnicIA, nous avons standardisé les noms des services et ajouté des APIs plus efficaces. Ce document clarifie la relation entre les implémentations originales et les nouvelles.

## Vue d'ensemble

| Fonction | Ancien nom | Nouveau nom | Changements |
|----------|------------|-------------|-------------|
| Traitement de PDF | `document-processor` | `document-processor` | API par chemin ajoutée |
| Analyse d'images | `vision-classifier` | `schema-analyzer` | APIs batch ajoutées |
| Vectorisation | `vector-store` | `vector-engine` | Structure d'API standardisée |

## Important - Comment gérer les implémentations

Pour éviter les doublons et la confusion, voici notre stratégie:

1. **Pour le Document Processor**:
   - Nous avons mis à jour le service existant
   - Aucun changement de nom n'a été effectué
   - La compatibilité ascendante a été maintenue

2. **Pour la classification d'images**:
   - Si vous utilisez déjà `vision-classifier`, continuez à utiliser ce service
   - Les nouvelles installations devraient utiliser `schema-analyzer`
   - Le docker-compose a été mis à jour pour utiliser le nouveau service

3. **Pour la vectorisation**:
   - Si vous utilisez déjà `vector-store`, continuez à utiliser ce service
   - Les nouvelles installations devraient utiliser `vector-engine`
   - Le docker-compose a été mis à jour pour utiliser le nouveau service

## APIs compatibles

### Document Processor

Le Document Processor a été amélioré avec un nouvel endpoint mais conserve toutes les anciennes APIs:

```
Document Processor
├── /process [POST] - Accepte un fichier binaire (original)
├── /process-file [POST] - Alternative pour formulaires (original)
├── /api/process [POST] - Accepte un chemin de fichier (nouveau)
├── /health [GET] - Vérification d'état (original)
└── /task/{task_id} [GET] - Statut d'une tâche (original)
```

### Schema Analyzer (ancien Vision Classifier)

Le Schema Analyzer offre à la fois les anciennes APIs et de nouvelles fonctionnalités pour le traitement par lots:

```
Schema Analyzer
├── /classify [POST] - Classification d'une image (compatible)
├── /api/analyze [POST] - Analyse de plusieurs images (nouveau)
├── /api/analyze-image [POST] - Analyse d'une image par chemin (nouveau)
└── /health [GET] - Vérification d'état (compatible)
```

### Vector Engine (ancien Vector Store)

Le Vector Engine offre des APIs standardisées tout en maintenant la compatibilité:

```
Vector Engine
├── /embed-text [POST] - Vectorisation de texte (compatible)
├── /embed-image [POST] - Vectorisation d'image (compatible)
├── /search [POST] - Recherche vectorielle (compatible)
├── /api/process [POST] - Traitement batch d'un document (nouveau)
├── /api/search [POST] - Recherche avec paramètres étendus (nouveau)
├── /api/document/{document_id}/status [GET] - Statut du document (nouveau)
└── /health [GET] - Vérification d'état (compatible)
```

## Configuration du docker-compose

Le fichier `docker-compose.yml` a été mis à jour pour utiliser les nouveaux noms de services:

```yaml
services:
  # Service de traitement des documents
  document-processor:
    build:
      context: ./services/document-processor
    # configuration...

  # Service d'analyse des schémas
  schema-analyzer:
    build:
      context: ./services/schema-analyzer
    # configuration...

  # Service de vectorisation
  vector-engine:
    build:
      context: ./services/vector-engine
    # configuration...
```

## Workflow n8n mis à jour

Le workflow n8n a été mis à jour pour utiliser les nouveaux endpoints API:

- Fichier: `workflows/technicia-ingestion-pure-microservices-fixed.json`
- Appels API:
  - `http://document-processor:8001/api/process`
  - `http://schema-analyzer:8002/api/analyze`
  - `http://vector-engine:8003/api/process`

## Migration et déploiement

### Pour un environnement existant

Si vous avez déjà déployé TechnicIA:

1. **Approche conservative**: Continuez à utiliser les anciens noms de services et APIs
   - Mettez à jour uniquement le service document-processor avec les nouvelles APIs
   - Adaptez le workflow n8n pour utiliser le nouvel endpoint `/api/process`

2. **Migration complète** vers la nouvelle architecture:
   - Arrêtez tous les services: `./scripts/start-technicia.sh --stop`
   - Renommez les dossiers de services si nécessaire
   - Démarrez avec le nouveau docker-compose: `./scripts/start-technicia.sh --clean`
   - Importez le workflow mis à jour dans n8n

### Pour un nouvel environnement

Si vous installez TechnicIA pour la première fois:
- Suivez simplement les instructions d'installation standard
- Utilisez le workflow `technicia-ingestion-pure-microservices-fixed.json`

## Conclusion

Cette restructuration améliore l'architecture globale tout en maintenant la compatibilité avec les déploiements existants. Les nouveaux noms de services (schema-analyzer, vector-engine) reflètent mieux leurs fonctions et l'ajout d'APIs par chemin permet une meilleure gestion des fichiers volumineux.
