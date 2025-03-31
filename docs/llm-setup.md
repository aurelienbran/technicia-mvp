# Configuration du Service LLM pour TechnicIA

Ce document explique comment configurer le service LLM (Large Language Model) pour TechnicIA, et comment configurer les credentials dans n8n pour utiliser Claude ou d'autres modèles.

## Table des matières

1. [Configuration du service LLM](#configuration-du-service-llm)
2. [Configuration des credentials dans n8n](#configuration-des-credentials-dans-n8n)
3. [Utilisation des modèles LLM dans les workflows](#utilisation-des-modèles-llm-dans-les-workflows)
4. [Troubleshooting](#troubleshooting)

## Configuration du service LLM

Le service LLM est un microservice dédié qui gère les interactions avec les APIs de modèles de langage comme Claude d'Anthropic ou GPT-4 d'OpenAI. Voici comment le configurer:

### Variables d'environnement

Dans votre fichier `.env`, configurez les variables suivantes:

```
# Configuration LLM (Assistant de réponse)
ANTHROPIC_API_KEY=your-anthropic-api-key
CLAUDE_MODEL=claude-3-5-sonnet-20240620
# Alternative: Si vous préférez utiliser OpenAI au lieu de Claude
# OPENAI_API_KEY=your-openai-api-key
# OPENAI_MODEL=gpt-4o
```

Pour obtenir une clé API Anthropic:
1. Créez un compte sur [console.anthropic.com](https://console.anthropic.com/)
2. Allez dans "API Keys" et créez une nouvelle clé
3. Copiez cette clé dans votre fichier `.env`

### Démarrage du service

Le service LLM est inclus dans le fichier `docker-compose.yml` et démarre automatiquement avec les autres services:

```bash
docker-compose up -d
```

Vous pouvez vérifier que le service fonctionne correctement en accédant à:
- `http://localhost:8004/health` - pour vérifier l'état du service
- `http://localhost:8004/docs` - pour accéder à la documentation de l'API

## Configuration des credentials dans n8n

Pour que les workflows n8n puissent utiliser l'API Claude, vous devez configurer les credentials dans n8n:

1. Accédez à l'interface n8n: `http://localhost:5678`
2. Connectez-vous avec les identifiants par défaut (admin / TechnicIA2025!)
3. Cliquez sur "Settings" (⚙️) en haut à droite
4. Sélectionnez "Credentials" dans le menu latéral
5. Cliquez sur "New" pour créer une nouvelle credential

### Configuration pour Claude (Anthropic)

1. Sélectionnez le type "HTTP Header Auth"
2. Nommez votre credential "Claude API Authentication"
3. Dans le champ "Name", entrez: `x-api-key`
4. Dans le champ "Value", entrez votre clé API Anthropic: `key_xxxxxxxxxxxxxxx`
5. Cliquez sur "Save" pour enregistrer la credential

### Configuration pour le service LLM local (Recommandé)

Alternativement, vous pouvez configurer n8n pour utiliser le service LLM que nous venons d'ajouter:

1. Sélectionnez le type "Generic Credential Type"
2. Nommez votre credential "TechnicIA LLM Service"
3. Ajoutez une propriété:
   - Name: `url`
   - Display Name: `LLM Service URL`
   - Type: `String`
   - Default Value: `http://llm-service:8004`
4. Cliquez sur "Save" pour enregistrer la credential

## Utilisation des modèles LLM dans les workflows

Deux approches sont possibles pour utiliser les LLMs dans les workflows:

### 1. Utilisation directe de l'API Claude/OpenAI

C'est l'approche utilisée dans les workflows existants (`question.json` et `diagnosis.json`). Ces workflows font des appels HTTP directs à l'API Anthropic en utilisant les credentials "Claude API Authentication".

### 2. Utilisation du service LLM local (Recommandé)

Pour utiliser le service LLM local, modifiez les workflows pour faire des requêtes HTTP au service LLM au lieu de l'API Claude directement:

```
URL: http://llm-service:8004/api/generate
Method: POST
Body:
{
  "system": "votre prompt système",
  "messages": [
    {
      "role": "user", 
      "content": "votre question ou prompt" 
    }
  ],
  "model": "claude-3-5-sonnet-20240620",
  "temperature": 0.2,
  "provider": "anthropic"
}
```

Avantages du service LLM local:
- Mise en cache des réponses pour réduire les coûts API
- Gestion des erreurs et tentatives automatiques
- Possibilité de basculer facilement entre différents fournisseurs
- Métriques et surveillance centralisées

## Troubleshooting

### Problèmes courants

1. **Erreur "No LLM providers configured"**
   - Vérifiez que les variables d'environnement `ANTHROPIC_API_KEY` ou `OPENAI_API_KEY` sont correctement définies

2. **Erreur d'authentification dans les workflows n8n**
   - Vérifiez que les credentials sont correctement configurées dans n8n
   - Assurez-vous que la clé API est valide et active

3. **Le service ne démarre pas**
   - Vérifiez les logs: `docker-compose logs llm-service`
   - Assurez-vous que les ports ne sont pas déjà utilisés

### Support

Pour toute question ou problème, veuillez consulter la [documentation TechnicIA](./README.md) ou soumettre une issue sur le dépôt GitHub.
