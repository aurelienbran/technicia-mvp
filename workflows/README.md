# TechnicIA - Workflows

Ce dossier contient les workflows n8n utilisés dans le projet TechnicIA.

## Workflow principal

Le workflow principal à utiliser est `technicia-ingestion.json`. C'est ce workflow qui est configuré pour fonctionner correctement avec le frontend.

## Configuration

Pour importer ce workflow dans n8n :

1. Lancez n8n
2. Allez dans Workflows > Import From File
3. Sélectionnez le fichier `technicia-ingestion.json`
4. Activez le workflow

## Points importants

- Le webhook d'upload est configuré sur le chemin `/upload` 
- NGINX est configuré pour rediriger `/api/upload` (utilisé par le frontend) vers `/webhook/upload` (utilisé par n8n)
- Le format de réponse est adapté pour correspondre à ce qu'attend le frontend

## Compatibilité avec le microserveur Python

Le workflow est configuré pour communiquer avec le microserveur Python `technicia-document-processor` sur les endpoints :
- `/process` pour le traitement des fichiers
- `/task/{task_id}` pour vérifier le statut des tâches en cours

## Détection des erreurs

Si des problèmes de communication apparaissent entre le frontend et les workflows n8n :

1. Vérifiez les logs de n8n
2. Vérifiez que le webhook ID "upload" est bien actif
3. Contrôlez que le microserveur Python est accessible
4. Vérifiez la configuration NGINX pour s'assurer que le routage est correct

## Autres workflows

Les autres workflows dans ce dossier sont conservés à titre de référence ou pour des cas d'usage spécifiques, mais ne sont pas nécessaires pour le fonctionnement normal de l'application.
