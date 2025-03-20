# Configuration n8n pour TechnicIA

Ce répertoire contient les données persistantes de n8n et les instructions pour sa configuration.

## Structure

- `data/` - Contient les données persistantes de n8n (workflows, credentials, etc.)

## Workflows à installer

Les fichiers JSON des workflows se trouvent dans le répertoire `../../workflows/`. Vous devrez les importer manuellement dans l'interface n8n après le déploiement.

## Credentials à configurer

Après l'installation, vous devrez configurer les credentials suivants dans l'interface n8n :

1. **Google API** - Pour Document AI et Vision AI
   - Type: Service Account
   - Utilisez le fichier JSON de votre service account Google Cloud

2. **Anthropic API** - Pour Claude
   - Type: API Key
   - Utilisez votre clé API Anthropic

3. **VoyageAI API** - Pour les embeddings
   - Type: API Key
   - Utilisez votre clé API VoyageAI

4. **Qdrant** - Pour la base de données vectorielle
   - Type: HTTP
   - URL: http://qdrant:6333
   - Pas de credentials nécessaires pour cette configuration locale

5. **HTTP Generic** - Pour les appels aux microservices
   - Type: HTTP
   - URL de base: configurez selon vos endpoints

## Sécurité

Les credentials sont sensibles et ne doivent pas être stockés dans le repository. Utilisez les fonctionnalités intégrées de n8n pour gérer les credentials de manière sécurisée.

## Sauvegarde

Il est recommandé de sauvegarder régulièrement le répertoire `data/` pour éviter la perte de workflows et de configurations.
