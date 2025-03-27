# TechnicIA - Workflows

Ce dossier contient les workflows n8n utilisés dans le projet TechnicIA.

## Workflow principal

Le workflow principal à utiliser est `technicia-ingestion-unified.json`. Ce workflow unifié intègre toutes les étapes d'ingestion dans un flux cohérent et simplifié.

Les anciens workflows (`technicia-ingestion-1.json`, `technicia-ingestion-2.json`, `technicia-ingestion-3.json` et `technicia-ingestion.json`) sont conservés à titre de référence.

## Configuration

Pour importer ce workflow dans n8n :

1. Lancez n8n
2. Allez dans Workflows > Import From File
3. Sélectionnez le fichier `technicia-ingestion-unified.json`
4. Configurez les credentials nécessaires :
   - Google API (pour Document AI et Vision AI)
   - Voyage AI (pour les embeddings)
5. Activez le workflow

## Fonctionnalités du workflow unifié

Le workflow unifié gère tout le processus d'ingestion :
1. Réception et validation des fichiers PDF
2. Extraction de contenu via Document AI
3. Classification d'images via Vision AI
4. Vectorisation du texte via Voyage AI
5. Indexation dans Qdrant
6. Notification au frontend

## Points importants

- Le webhook d'upload est configuré sur le chemin `/upload` 
- NGINX doit être configuré pour rediriger `/api/upload` (utilisé par le frontend) vers `/webhook/technicia-upload` (utilisé par n8n)
- Le format de réponse est adapté pour correspondre à ce qu'attend le frontend
- Un point de terminaison `/health` est disponible pour vérifier l'état du service

## APIs et services utilisés

Le workflow est configuré pour communiquer avec les services suivants :
- Document AI (Google Cloud) pour l'extraction de texte
- Vision AI (Google Cloud) pour la classification d'images
- Voyage AI pour la génération d'embeddings
- Qdrant pour l'indexation vectorielle
- Frontend via un endpoint de notification (`/api/notifications`)

## Détection des erreurs

Si des problèmes de communication apparaissent :

1. Vérifiez les logs de n8n
2. Vérifiez que le webhook ID "technicia-upload" est bien actif
3. Contrôlez que les services externes sont accessibles
4. Vérifiez la configuration NGINX pour s'assurer que le routage est correct

## Autres workflows

Les autres workflows dans ce dossier sont conservés à titre de référence ou pour des cas d'usage spécifiques, mais ne sont pas nécessaires pour le fonctionnement normal de l'application.
