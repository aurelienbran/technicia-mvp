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

## Configuration du proxy Nginx

Pour que l'upload de fichiers fonctionne correctement, la configuration du proxy Nginx doit permettre les requêtes volumineuses. Voici une configuration correcte :

```nginx
# Configuration pour les fichiers volumineux
client_max_body_size 150M;

# Proxy pour les webhooks n8n
location /webhook/ {
    proxy_pass http://n8n:5678/webhook/;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_set_header Host $host;
    proxy_cache_bypass $http_upgrade;
    
    # Configuration spécifique pour l'upload via webhook
    proxy_request_buffering off;
    proxy_buffering off;
    client_max_body_size 150M;
    proxy_read_timeout 300s;
}

# URL raccourcie pour l'upload spécifiquement
location /api/upload {
    rewrite ^/api/upload$ /webhook/document-upload permanent;
}
```

Les points clés sont :
- `client_max_body_size` doit être suffisamment grand pour les fichiers PDF
- `proxy_request_buffering off` et `proxy_buffering off` pour éviter les problèmes avec les fichiers volumineux
- `proxy_read_timeout` suffisamment long pour permettre le traitement des gros fichiers
- La redirection `/api/upload` vers `/webhook/document-upload` pour garantir la cohérence entre l'API utilisée par le frontend et le webhook n8n

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

### 4. Erreur "Request entity too large"

**Problème** : Nginx rejette les fichiers volumineux.

**Solutions** :
- Augmentez la valeur de `client_max_body_size` dans la configuration Nginx
- Assurez-vous que cette directive est présente dans le bon contexte (server ou location)

### 5. Timeout lors de l'upload

**Problème** : L'upload échoue après un certain temps pour les gros fichiers.

**Solutions** :
- Augmentez `proxy_read_timeout` dans la configuration Nginx
- Désactivez le buffering avec `proxy_request_buffering off` et `proxy_buffering off`
- Vérifiez si n8n a des timeout configurés et ajustez-les si nécessaire

### 6. Accès au webhook sans nom de domaine

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
5. **Testez le frontend et le webhook séparément** pour isoler le problème

### Inspection des requêtes réseau

Pour déboguer les problèmes d'upload depuis le navigateur :
1. Ouvrez les outils de développement (F12)
2. Naviguez vers l'onglet "Network"
3. Filtrez par "Fetch/XHR"
4. Tentez l'upload et observez la requête `/api/upload`
5. Vérifiez le statut de la réponse, les en-têtes et le corps de la requête

### Capture des logs Docker

Pour une analyse plus approfondie:

```bash
# Logs du frontend (Nginx)
docker logs -f technicia-frontend

# Logs de n8n
docker logs -f technicia-n8n | grep webhook

# Logs du document-processor
docker logs -f technicia-document-processor
```

Ces instructions devraient vous aider à dépanner efficacement les problèmes liés aux webhooks dans TechnicIA.
