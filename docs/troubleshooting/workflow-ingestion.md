# Correction du workflow d'ingestion TechnicIA

## Problème initial

Lors de l'exécution du workflow `technicia-ingestion-pure-microservices.json`, l'erreur suivante était générée:

```json
{
   "errorMessage": "Your request is invalid or could not be processed by the service",
   "errorDescription": "Field required",
   "errorDetails": {
     "rawErrorMessage": [
       "422 - \"{\\\"detail\\\":[{\\\"type\\\":\\\"missing\\\",\\\"loc\\\":[\\\"body\\\",\\\"file\\\"],\\\"msg\\\":\\\"Field required\\\",\\\"input\\\":null,\\\"url\\\":\\\"https://errors.pydantic.dev/2.6/v/missing\\\"}]}\""
     ],
     "httpCode": "422"
   },
   "n8nDetails": {
     "nodeName": "Document Processor Service",
     "nodeType": "n8n-nodes-base.httpRequest",
     "nodeVersion": 4.1,
     "itemIndex": 0,
     "time": "30/03/2025 16:25:20",
     "n8nVersion": "1.84.3 (Self Hosted)",
     "binaryDataMode": "default",
     "stackTrace": [
       "NodeApiError: Your request is invalid or could not be processed by the service",
       "    at ExecuteContext.execute (/usr/local/lib/node_modules/n8n/node_modules/n8n-nodes-base/dist/nodes/HttpRequest/V3/HttpRequestV3.node.js:525:33)",
       "    at processTicksAndRejections (node:internal/process/task_queues:95:5)",
       "    at WorkflowExecute.runNode (/usr/local/lib/node_modules/n8n/node_modules/n8n-core/dist/execution-engine/workflow-execute.js:681:27)",
       "    at /usr/local/lib/node_modules/n8n/node_modules/n8n-core/dist/execution-engine/workflow-execute.js:913:51",
       "    at /usr/local/lib/node_modules/n8n/node_modules/n8n-core/dist/execution-engine/workflow-execute.js:1246:20"
     ]
   }
}
```

## Analyse du problème

L'erreur était causée par une incompatibilité entre:

1. **Le workflow n8n**: qui envoyait les données en JSON avec un chemin de fichier
```json
{
  "documentId": "doc-123456",
  "filePath": "/tmp/technicia-docs/file.pdf",
  "fileName": "file.pdf"
  // autres paramètres...
}
```

2. **L'API Document Processor**: qui attendait un fichier binaire avec le champ `file` en multipart/form-data
```python
@app.post("/process")
async def process_document(file: UploadFile = File(...)):
    # code de traitement...
```

Le message d'erreur `Field required` indiquait précisément que le champ `file` attendu dans la requête était manquant.

## Solutions possibles

Trois approches étaient envisageables:

1. **Modifier le workflow n8n** pour envoyer un fichier binaire au lieu d'un chemin
   - Avantages: Respecte l'API existante
   - Inconvénients: Double transfert de fichier, inefficace pour les gros documents

2. **Utiliser l'endpoint existant `/process-file`** dans le Document Processor
   - Avantages: Solution rapide sans modification de code
   - Inconvénients: Problèmes similaires de double transfert

3. **Ajouter une nouvelle API par chemin** au Document Processor
   - Avantages: Plus efficace, pas de double transfert, meilleure architecture microservices
   - Inconvénients: Nécessite des modifications de code service

## Solution implémentée

Nous avons choisi la 3ème option pour des raisons de performance et d'architecture:

1. **Nouvel endpoint `/api/process`** ajouté au Document Processor qui accepte un chemin de fichier:
```python
@app.post("/api/process")
async def process_by_path(request: ProcessByPathRequest):
    """
    Traite un document PDF à partir de son chemin sur le système de fichiers.
    """
    # Code de traitement...
```

2. **Modification du workflow n8n** pour utiliser ce nouvel endpoint:
```json
"bodyParametersJson": "={{ { \"documentId\": $json.documentId, \"filePath\": $json.fullPath, \"fileName\": $json.fileName, \"mimeType\": $json.mimeType, \"outputPath\": $json.basePath, \"extractImages\": true, \"extractText\": true } }}"
```

## Avantages de la solution

- **Performance**: Évite le double transfert de fichiers volumineux
- **Architecture**: Meilleure séparation des responsabilités entre services
- **Scalabilité**: Supporte mieux les documents de grande taille
- **Robustesse**: Moins de risques d'erreurs de transfert

## Compatibilité

Le service maintient la compatibilité avec les deux méthodes:
- L'ancienne API `/process` qui accepte un fichier binaire
- La nouvelle API `/api/process` qui accepte un chemin de fichier

Pour les nouvelles intégrations, nous recommandons d'utiliser la seconde approche.

## Tests de validation

Pour tester la nouvelle implémentation:

```bash
# Test avec un chemin de fichier
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"documentId":"test-123","filePath":"/tmp/votre-fichier.pdf","fileName":"document.pdf"}' \
  http://localhost:8001/api/process
```

## Conseils d'implémentation

Pour les futurs développements:
1. Privilégier l'approche par chemins de fichiers pour les transferts entre microservices
2. Réserver le transfert de fichiers binaires aux interfaces externes (frontend vers backend)
3. S'assurer que les services partagent un volume de stockage commun
