# Workflows n8n pour TechnicIA

Ce document décrit les workflows n8n utilisés dans TechnicIA et leur fonctionnement. Les workflows sont au cœur de l'orchestration du système, reliant tous les composants ensemble de manière visuelle et maintenable.

## Vue d'ensemble des Workflows

TechnicIA utilise trois workflows principaux :

1. **Workflow d'ingestion** - Pour traiter les documents PDF et les indexer dans Qdrant
2. **Workflow de traitement des questions** - Pour traiter les questions et générer des réponses
3. **Workflow de diagnostic guidé** - Pour guider les techniciens à travers un processus de diagnostic pas à pas

## 1. Workflow d'Ingestion de Documents

Ce workflow gère le traitement des documents PDF, depuis leur upload jusqu'à leur indexation dans la base vectorielle.

### Étapes du workflow

1. **Réception du document** (Webhook)
   - Endpoint : `/upload-pdf`
   - Accepte les fichiers PDF jusqu'à 150 MB
   - Validation du type de fichier et de la taille

2. **Vérification de la taille**
   - Si le fichier dépasse 25 MB, il est routé vers un traitement spécial
   - Sinon, il est traité directement par le workflow

3. **Pour les gros fichiers**
   - Appel au microservice Document Processor
   - Traitement asynchrone par chunks pour éviter la saturation de la mémoire

4. **Extraction avec Document AI**
   - Appel à l'API Document AI de Google
   - Extraction du texte et des images
   - OCR sur le contenu textuel

5. **Analyse des images avec Vision AI**
   - Classification des images extraites
   - Détection des schémas techniques
   - OCR sur les annotations des schémas

6. **Analyse et préparation**
   - Classification des types de schémas (électrique, hydraulique, etc.)
   - Structuration des données extraites
   - Préparation des métadonnées

7. **Vectorisation et stockage**
   - Génération d'embeddings via VoyageAI
   - Indexation dans Qdrant avec métadonnées
   - Optimisation de la recherche

8. **Notification**
   - Confirmation du traitement
   - Statistiques sur le document indexé

### Paramètres clés

- **Taille max** : 150 MB
- **Chunk size** : 1000 tokens
- **Overlap** : 200 tokens
- **Modèle d'embedding** : VoyageAI voyage-2 (1024 dimensions)

### Exemple de configuration

```javascript
// Configuration du nœud Document AI
{
  "url": "https://REGION-documentai.googleapis.com/v1/projects/PROJECT_ID/locations/LOCATION_ID/processors/PROCESSOR_ID:process",
  "method": "POST",
  "headers": {
    "Authorization": "Bearer {{$node.Credentials.json.googleApiKey}}",
    "Content-Type": "application/json"
  },
  "body": {
    "rawDocument": {
      "content": "{{$binary.data.toString('base64')}}",
      "mimeType": "application/pdf"
    }
  }
}
```

## 2. Workflow de Traitement des Questions

Ce workflow gère les questions des utilisateurs et génère des réponses contextuelles en utilisant les documents indexés.

### Étapes du workflow

1. **Réception de la question** (Webhook)
   - Endpoint : `/chat`
   - Paramètres : `question`, `userId`, `sessionId`
   - Validation de la requête

2. **Formatage de la requête**
   - Nettoyage et normalisation du texte
   - Détection de la langue (le cas échéant)
   - Ajout de métadonnées de session

3. **Recherche dans Qdrant**
   - Génération de l'embedding de la question
   - Recherche sémantique dans la base vectorielle
   - Récupération des k documents les plus pertinents

4. **Préparation du contexte**
   - Formation du contexte à partir des documents récupérés
   - Inclusion des références aux schémas pertinents
   - Structuration du contexte pour le LLM

5. **Génération de réponse avec Claude**
   - Appel à l'API Claude avec le contexte
   - Utilisation d'un prompt optimisé pour la documentation technique
   - Paramétrage de la température pour des réponses précises

6. **Traitement de la réponse**
   - Extraction et formatage de la réponse
   - Ajout des références aux sources
   - Préparation des schémas pour l'affichage

7. **Renvoi au frontend**
   - Réponse structurée avec texte et références
   - Métadonnées pour l'affichage
   - Temps de traitement

### Paramètres clés

- **Top k** : 5 (nombre de documents récupérés)
- **Modèle LLM** : Claude 3 Sonnet
- **Température** : 0.2 (pour des réponses précises et déterministes)
- **Max tokens** : 1000 (pour la réponse générée)

### Exemple de configuration

```javascript
// Configuration du prompt pour Claude
{
  "system": "Tu es un assistant technique spécialisé dans la documentation hydraulique, pneumatique et électrique. Utilise uniquement les informations fournies dans le contexte pour répondre aux questions. Si tu ne trouves pas l'information, dis-le clairement.",
  "user": "Contexte :\n{{$node.PrepareContext.json.textualContext}}\n\nSchémas pertinents :\n{{$node.PrepareContext.json.relevantImages.join('\n')}}\n\nQuestion : {{$node.FormatQuery.json.question}}"
}
```

## 3. Workflow de Diagnostic Guidé

Ce workflow implémente un assistant de diagnostic pas à pas pour guider les techniciens dans l'identification et la résolution de problèmes.

### Étapes du workflow

1. **Démarrage du diagnostic** (Webhook)
   - Endpoint : `/start-diagnosis`
   - Paramètres : `userId`, `equipmentId`, `initialSymptoms`
   - Validation des informations de base

2. **Initialisation du diagnostic**
   - Appel au backend pour initialiser la session
   - Génération d'un plan de diagnostic basé sur les symptômes initiaux
   - Définition des étapes de diagnostic

3. **Boucle de diagnostic**
   - Gestion d'un processus itératif d'étapes
   - Conservation de l'état entre les étapes
   - Progression à travers l'arbre de décision

4. **Pour chaque étape**
   - Présentation de l'étape courante à l'utilisateur
   - Attente de sa réponse via un webhook
   - Analyse de la réponse et mise à jour du diagnostic

5. **Analyse des réponses**
   - Évaluation des symptômes additionnels
   - Raffinement des hypothèses
   - Identification des composants potentiellement défectueux

6. **Génération de recommandations**
   - Utilisation de Claude pour générer des recommandations contextuelles
   - Adaptation en fonction des informations recueillies
   - Suggestion de prochaines étapes

7. **Finalisation du diagnostic**
   - Compilation des résultats
   - Génération d'un rapport de diagnostic complet
   - Recommandations finales

8. **Stockage et présentation**
   - Sauvegarde du diagnostic dans la base de données
   - Présentation des résultats à l'utilisateur
   - Références aux schémas pertinents

### Paramètres clés

- **Modèle LLM** : Claude 3 Sonnet
- **Température** : 0.1 (pour des recommandations techniques précises)
- **Format de diagnostic** : Structure hiérarchique avec étapes, réponses et recommandations

### Exemple de configuration

```javascript
// Configuration du nœud de traitement d'étape
{
  "functionCode": `
    // Process user response for current step
    const stepResponse = $input.item.json;
    const diagnosticState = $node["Loop Diagnostic Steps"].json;
    
    // Add the response to collected data
    const collectedData = { ...diagnosticState.collectedData };
    collectedData[\`step\${stepResponse.stepNumber}\`] = stepResponse.response;
    
    // Prepare for next step
    return {
      json: {
        ...diagnosticState,
        currentStep: parseInt(stepResponse.stepNumber) + 1,
        collectedData,
        currentResponse: stepResponse.response
      }
    };
  `
}
```

## Importation des Workflows

Les workflows sont disponibles sous forme de fichiers JSON dans le dossier `/workflows` de ce repository. Pour les importer dans votre instance n8n :

1. Accédez à l'interface n8n (généralement sur le port 5678)
2. Cliquez sur "Workflows" dans la barre latérale
3. Utilisez le bouton "Import" et sélectionnez le fichier JSON
4. Configurez les credentials nécessaires :
   - Google Cloud (pour Document AI et Vision AI)
   - VoyageAI (pour les embeddings)
   - Anthropic (pour Claude)
   - URLs des microservices

## Personnalisation des Workflows

Les workflows peuvent être personnalisés selon vos besoins spécifiques :

- **Taille de chunk** : Ajustez selon la complexité de votre documentation
- **Paramètres LLM** : Modifiez la température ou le modèle selon vos besoins
- **Étapes de diagnostic** : Personnalisez en fonction de vos équipements
- **Intégrations** : Ajoutez des étapes pour intégration avec d'autres systèmes

## Considérations de Performance

- **Traitement par lot** : Pour les gros volumes, considérez d'augmenter le traitement par lot
- **Mise en cache** : Implémentez la mise en cache des requêtes fréquentes
- **Monitoring** : Ajoutez des nœuds de logging pour surveiller les performances

## Dépannage

- **Erreurs Document AI** : Vérifiez les quotas et les permissions de votre compte Google Cloud
- **Problèmes de vectorisation** : Validez les clés API et les limites de taille de texte
- **Erreurs de webhook** : Assurez-vous que les URLs sont correctement configurées
- **Timeouts** : Ajustez les délais d'attente pour les documents volumineux
