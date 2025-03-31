# Service LLM pour TechnicIA

Ce service gère les interactions avec les grands modèles de langage (LLM) pour générer des réponses de haute qualité adaptées aux besoins de TechnicIA.

## Fonctionnalités

- Support des modèles Claude d'Anthropic (recommandé) et GPT d'OpenAI
- API REST pour la génération de texte
- Mise en cache des réponses pour optimiser les coûts et les performances
- Templates prédéfinis pour différents cas d'usage (questions, diagnostic, procédures)
- Monitoring des performances et des coûts
- Gestion des erreurs et des timeouts

## Configuration

### Variables d'environnement

Configurez ces variables dans le fichier `.env` :

```
# Principal (Claude)
ANTHROPIC_API_KEY=votre-clé-api-anthropic
CLAUDE_MODEL=claude-3-5-sonnet-20240620

# Alternative (OpenAI)
OPENAI_API_KEY=votre-clé-api-openai
OPENAI_MODEL=gpt-4

# Configuration du service
LLM_SERVICE_PORT=8004
```

## API Endpoints

- `GET /health` : Vérifie l'état du service et des fournisseurs LLM configurés
- `POST /generate` : Génère une réponse à partir d'un contexte et d'une question
- `GET /prompts/templates` : Récupère des templates prédéfinis de prompts système

### Exemple d'utilisation

```bash
curl -X POST http://localhost:8004/generate \
  -H "Content-Type: application/json" \
  -d '{
    "system": "Tu es TechnicIA, un assistant de maintenance technique...",
    "messages": [
      {
        "role": "user",
        "content": "Comment fonctionne le circuit hydraulique décrit dans la documentation?"
      }
    ],
    "temperature": 0.2,
    "max_tokens": 2000,
    "provider": "anthropic"
  }'
```

## Intégration avec n8n

Pour configurer l'authentification Claude dans n8n :

1. Accédez à "Credentials" dans le menu n8n
2. Cliquez sur "+ Add Credential"
3. Sélectionnez "HTTP Header Auth"
4. Donnez un nom (ex: "Claude API Authentication")
5. Dans "Name", entrez : "x-api-key"
6. Dans "Value", entrez votre clé API Anthropic
7. Sauvegardez

Ensuite, dans vos workflows n8n, vous pouvez remplacer les appels directs à l'API Claude par des appels à ce service. Exemple :

```
URL: http://llm-service:8004/generate
Méthode: POST
Body (JSON):
{
  "system": "Tu es TechnicIA, un assistant...",
  "messages": [
    {
      "role": "user",
      "content": "{{$json.question}}"
    }
  ],
  "temperature": 0.2
}
```

## Développement local

```bash
# Installation des dépendances
pip install -r requirements.txt

# Lancement du serveur de développement
uvicorn main:app --reload --port 8004
```

## Structure des données

### Requête de génération
```json
{
  "system": "String - System prompt pour définir le comportement du modèle",
  "messages": [
    {
      "role": "user|assistant",
      "content": "String - Contenu du message"
    }
  ],
  "model": "String - Modèle à utiliser (optionnel)",
  "temperature": "Float - Entre 0 et 1 (optionnel, défaut: 0.2)",
  "max_tokens": "Int - Nombre maximum de tokens à générer (optionnel, défaut: 2000)",
  "provider": "String - anthropic ou openai (optionnel, défaut: anthropic)",
  "cache": "Boolean - Activer/désactiver le cache (optionnel, défaut: true)"
}
```

### Réponse de génération
```json
{
  "content": "String - Texte généré",
  "model": "String - Modèle utilisé",
  "usage": {
    "input_tokens": "Int - Nombre de tokens en entrée",
    "output_tokens": "Int - Nombre de tokens en sortie"
  },
  "cached": "Boolean - Indique si la réponse vient du cache",
  "provider": "String - Fournisseur utilisé",
  "processing_time": "Float - Temps de traitement en secondes"
}
```
