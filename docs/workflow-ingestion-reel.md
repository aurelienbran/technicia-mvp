# Workflow d'ingestion avec traitement réel des PDF

Ce document explique le fonctionnement du workflow d'ingestion avec traitement réel des fichiers PDF dans TechnicIA.

## Vue d'ensemble

Le workflow `ingestion-real.json` permet de traiter de manière complète les fichiers PDF téléversés, en utilisant les microservices TechnicIA pour extraire, classifier et vectoriser le contenu textuel et les images.

### Fonctionnalités implémentées

1. **Upload et validation de PDF**
   - Réception des fichiers PDF via webhook
   - Validation du format et extraction des métadonnées
   - Détection des fichiers volumineux (> 25 Mo)

2. **Traitement adaptatif**
   - Traitement asynchrone pour les fichiers volumineux
   - Traitement synchrone pour les fichiers standard

3. **Extraction et classification**
   - Extraction du texte via Document AI
   - Détection et classification des images via Vision AI
   - Découpage intelligent du texte en chunks

4. **Vectorisation et indexation**
   - Vectorisation du texte et des images
   - Stockage dans Qdrant pour recherche sémantique

## Architecture du workflow

### Nœuds principaux

1. **Document Upload Webhook**
   - Point d'entrée pour l'upload de fichiers PDF

2. **Validate & Prepare File**
   - Valide le format PDF
   - Extrait les métadonnées
   - Détermine si le fichier est volumineux

3. **Large File?**
   - Branchement conditionnel selon la taille du fichier

4. **Process Large File / Process Standard File**
   - Traitement adapté selon la taille via les endpoints différents du service `document-processor`

5. **Check Processing Status / Wait 3 Seconds**
   - Polling pour les traitements asynchrones (fichiers volumineux)

6. **Extract Data**
   - Extraction des données du document traité (texte et images)
   - Normalisation des formats entre les traitements asynchrones et synchrones

7. **Prepare Images for Classification / Classify Image**
   - Préparation et classification des images extraites

8. **Process Data for Vectorization**
   - Transformation des données pour la vectorisation
   - Découpage du texte en chunks
   - Préparation des images classifiées

9. **Vectorize Text Chunk / Vectorize Image**
   - Vectorisation du texte et des images via le service `vector-store`
   - Stockage dans Qdrant

10. **Return Success Response**
    - Retour d'une réponse formatée à l'utilisateur

## Configuration et utilisation

### Prérequis

1. Tous les services doivent être démarrés via Docker Compose:
   ```bash
   cd docker
   docker-compose up -d
   ```

2. Les variables d'environnement suivantes doivent être configurées:
   - `DOCUMENT_AI_PROJECT`
   - `DOCUMENT_AI_LOCATION`
   - `DOCUMENT_AI_PROCESSOR_ID`
   - `VOYAGE_API_KEY`
   - `GOOGLE_APPLICATION_CREDENTIALS`

### Importation du workflow

1. Ouvrir l'interface n8n (http://localhost:5678)
2. Importer le fichier `workflows/ingestion-real.json`
3. Activer le workflow

### Tests

Pour tester le workflow:

1. Utiliser un outil comme Postman ou curl pour envoyer un PDF:
   ```bash
   curl -X POST -F "file=@chemin/vers/document.pdf" http://localhost:5678/webhook/upload
   ```

2. Pour tester le traitement des fichiers volumineux, utilisez un PDF de plus de 25 Mo, ou un PDF dont le nom contient "large" ou "big"

## Points d'attention

1. **Traitement des fichiers volumineux**
   - Le traitement asynchrone utilise un polling toutes les 3 secondes
   - Un timeout de 180 secondes est configuré pour les fichiers volumineux

2. **Classification des images**
   - Le workflow simule la classification si aucune image n'est détectée
   - En production, cela devrait être remplacé par le traitement réel

3. **Gestion d'erreurs**
   - Un nœud "Error Handler" centralisé est présent pour gérer les erreurs
   - Les erreurs sont loggées dans la console n8n

## Dépannage

### Problèmes courants

1. **Erreur "Aucune donnée binaire reçue"**
   - Vérifiez que le fichier est envoyé correctement en multipart/form-data
   - Assurez-vous que le champ s'appelle "file"

2. **Timeout lors du traitement**
   - Augmentez les valeurs de timeout dans les nœuds HTTP Request

3. **Erreur Document AI**
   - Vérifiez les variables d'environnement et les credentials Google Cloud

4. **Erreur de vectorisation**
   - Vérifiez la clé API VoyageAI
   - Vérifiez que Qdrant est correctement démarré

## Améliorations futures

1. **Extraction réelle des images**
   - Intégrer l'extraction réelle des images depuis les PDF

2. **Classification avancée**
   - Améliorer la classification des schémas techniques

3. **Chunking optimisé**
   - Implémenter un chunking plus intelligent basé sur la structure du document

4. **Traitement parallèle**
   - Optimiser le traitement des fichiers volumineux par découpage et traitement parallèle
