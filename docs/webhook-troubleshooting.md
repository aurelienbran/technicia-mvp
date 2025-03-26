# Guide de dépannage des webhooks dans TechnicIA

Ce document fournit des instructions pour configurer correctement les webhooks dans n8n pour l'ingestion de documents et résoudre les problèmes courants.

## Configuration correcte du webhook d'upload de documents

Le webhook d'upload de documents doit être configuré comme suit pour fonctionner correctement :

1. **Méthode HTTP** : `POST` (et non GET)
2. **Path** : `upload`
3. **Options** :
   - Activer `Raw Body`
   - Définir `Body Content Type` à `multipart-form-data`

Voici un exemple de configuration correcte pour le nœud Webhook de n8n :

```json
{
  "parameters": {
    "path": "upload",
    "responseMode": "responseNode",
    "options": {
      "rawBody": true,
      "bodyContentType": "multipart-form-data"
    },
    "httpMethod": "POST"
  },
  "name": "Document Upload Webhook",
  "type": "n8n-nodes-base.webhook",
  "typeVersion": 1,
  "webhookId": "document-upload"
}
```

## Problèmes courants et solutions

### 1. Erreur "No file received"

**Problème** : Le webhook n'arrive pas à détecter le fichier dans la requête.

**Solutions** :
- Vérifiez que la méthode HTTP est bien `POST`
- Assurez-vous que l'option `bodyContentType` est définie à `multipart-form-data`
- Vérifiez dans le frontend que le fichier est envoyé avec le nom de champ `file`

### 2. Erreur "Only PDF files are supported"

**Problème** : Le fichier envoyé n'est pas un PDF ou est corrompu.

**Solutions** :
- Assurez-vous que le fichier est un PDF valide
- Vérifiez que le Content-Type est correctement défini à `application/pdf`

### 3. Webhook non déclenché

**Problème** : Le webhook n'est pas déclenché lorsque le formulaire est soumis.

**Solutions** :
- Vérifiez la configuration Nginx pour s'assurer que la redirection vers n8n fonctionne correctement
- Assurez-vous que le formulaire envoie les données à la bonne URL (`/api/upload`)
- Vérifiez les logs du conteneur frontend pour voir si les requêtes atteignent nginx
- Vérifiez les logs du conteneur n8n pour voir si les requêtes atteignent n8n

### 4. Accès au webhook sans nom de domaine

Pour tester votre webhook localement ou sans nom de domaine configuré :

1. **Utiliser ngrok** pour exposer votre instance n8n :
   ```bash
   ngrok http 80
   ```

2. **Utiliser l'URL générée** pour tester le téléversement :
   - L'URL sera de la forme `https://random-id.ngrok.io`
   - Assurez-vous que la configuration de proxy de Nginx redirige correctement vers n8n

3. **Tester avec un outil comme Postman** :
   ```
   POST https://your-ngrok-url/api/upload
   Content-Type: multipart/form-data
   
   // Avec un champ "file" contenant votre PDF
   ```

## Vérification technique

Pour vérifier que le webhook est correctement configuré :

1. Dans n8n, naviguez vers le workflow d'ingestion de documents
2. Éditez le nœud "Document Upload Webhook"
3. Vérifiez les paramètres suivants :
   - `httpMethod`: Doit être `POST`
   - `options.rawBody`: Doit être `true`
   - `options.bodyContentType`: Doit être `multipart-form-data`
4. Cliquez sur "Listen for test event" pour activer le webhook
5. Utilisez Postman ou curl pour tester le webhook

```bash
curl -X POST -F "file=@votre_document.pdf" http://localhost:5678/webhook/document-upload
```

## Débogage avancé

Si des problèmes persistent :

1. **Activez les logs détaillés de n8n** en modifiant la variable d'environnement `N8N_LOG_LEVEL` à `debug`
2. **Inspectez les requêtes réseau** dans les outils de développement du navigateur
3. **Ajoutez des nœuds Function** dans le workflow pour afficher les données reçues à chaque étape
4. **Vérifiez que le chemin du webhook** correspond à celui configuré dans Nginx

Ces instructions devraient vous aider à dépanner efficacement les problèmes liés aux webhooks dans TechnicIA.
