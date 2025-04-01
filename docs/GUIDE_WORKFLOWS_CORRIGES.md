# Guide d'utilisation des workflows corrigés pour TechnicIA

Ce guide explique comment utiliser les nouveaux workflows corrigés pour TechnicIA, garantissant une compatibilité parfaite avec les microservices existants et résolvant les problèmes de résolution DNS.

## Workflows corrigés disponibles

1. **technicia-ingestion-corrected.json** - Version corrigée pour l'ingestion des documents PDF
2. **question-corrected.json** - Version corrigée pour la recherche et les questions-réponses
3. **diagnostic-corrected.json** - Version corrigée pour le diagnostic guidé des problèmes techniques

## Principales corrections apportées

### 1. Workflow d'ingestion
- Correction du traitement des fichiers binaires (champ "file" au lieu de "data")
- Adaptation aux endpoints exacts du document-processor (`/process` au lieu de `/api/process`)
- Utilisation d'un formulaire multipart/form-data pour l'upload vers document-processor
- Transmission correcte des paramètres et formats pour tous les microservices

### 2. Workflow de question
- Structure améliorée avec étape de validation des requêtes
- Adaptation aux formats exacts des API de recherche vectorielle
- Traitement correct du JSON pour l'appel au claude-service
- Gestion robuste des erreurs

### 3. Workflow de diagnostic
- Étapes de préparation des requêtes pour validation des inputs
- Format JSON adapté pour le service claude-service
- Gestion correcte des sessions de diagnostic
- Formatage adapté des résultats d'étapes intermédiaires

## Importation des workflows

1. Accédez à l'interface n8n à l'adresse http://localhost:5678
2. Connectez-vous avec vos identifiants
3. Allez dans la section "Workflows" et cliquez sur "Import from File"
4. Importez les fichiers suivants :
   - `workflows/technicia-ingestion-corrected.json`
   - `workflows/question-corrected.json`
   - `workflows/diagnostic-corrected.json`
5. Activez chaque workflow importé en cliquant sur le bouton "Active"

## Configuration des credentials pour Claude

Pour que les workflows fonctionnent correctement, configurez les credentials pour l'API Claude :

1. Dans n8n, allez dans **Settings** (⚙️) puis **Credentials**
2. Cliquez sur **+ Add Credential**
3. Choisissez le type **HTTP Header Auth**
4. Remplissez les champs suivants :
   - **Name** : Claude API Authentication
   - **Name** : x-api-key
   - **Value** : Votre clé API Anthropic (la même que dans votre fichier .env)
5. Cliquez sur **Save**

## Utilisation des workflows

### Ingestion de documents (corrigé)

Ce workflow permet d'indexer des documents PDF :

1. Utilisez le webhook : `http://localhost:5678/webhook/upload`
2. Méthode : POST avec un formulaire multipart/form-data
3. Paramètre : "file" contenant le fichier PDF

Exemple avec curl :
```bash
curl -X POST -F "file=@chemin/vers/votre/document.pdf" http://localhost:5678/webhook/upload
```

Ou utilisez le script fourni :
```bash
./scripts/start-technicia.sh --import chemin/vers/votre/document.pdf
```

### Poser des questions (corrigé)

Ce workflow permet d'interroger les documents indexés :

1. Utilisez le webhook : `http://localhost:5678/webhook/question`
2. Méthode : POST avec un corps JSON
3. Format du corps :
```json
{
  "question": "Votre question sur la documentation technique"
}
```

Exemple avec curl :
```bash
curl -X POST http://localhost:5678/webhook/question \
  -H "Content-Type: application/json" \
  -d '{"question": "Comment fonctionne le circuit hydraulique?"}'
```

### Diagnostic guidé (corrigé)

Ce workflow offre une approche pas à pas pour résoudre les problèmes :

1. Initier un diagnostic :
   - Webhook : `http://localhost:5678/webhook/diagnostic`
   - Méthode : POST avec un corps JSON
   - Format :
   ```json
   {
     "symptoms": "Description des symptômes du problème",
     "equipment": "Type ou modèle d'équipement concerné"
   }
   ```

2. Traiter les étapes du diagnostic :
   - Webhook : `http://localhost:5678/webhook/diagnostic/step`
   - Méthode : POST avec un corps JSON
   - Format :
   ```json
   {
     "sessionId": "ID de session retourné par l'étape précédente",
     "stepIndex": 0,
     "stepResult": "Résultat du test effectué"
   }
   ```

## Avantages des workflows corrigés

1. **Compatibilité garantie** : Les workflows corrigés sont conçus pour fonctionner parfaitement avec les microservices existants, sans erreur DNS ou problème de format.

2. **Robustesse améliorée** : Validation des entrées, gestion des erreurs et traitement des cas limites pour une meilleure fiabilité.

3. **Maintenabilité** : Organisation claire avec des nœuds de fonction dédiés pour chaque étape logique du processus.

4. **Documentation intégrée** : Chaque workflow comprend une note explicative détaillant son fonctionnement.

5. **Performances optimisées** : Formats de requêtes et réponses adaptés à chaque microservice pour des échanges de données efficaces.

## Résolution de problèmes courants

### Erreur "The item has no binary field"
Si vous rencontrez cette erreur dans le workflow d'ingestion, vérifiez que la propriété dans le nœud "Écrire le fichier" est bien définie sur "file" et non sur "data".

### Problèmes de connexion entre services
Vérifiez que tous les services sont bien démarrés avec :
```bash
docker-compose ps
```

### Erreurs HTTP dans les appels API
Consultez les logs des services concernés pour détails :
```bash
docker-compose logs -f document-processor
docker-compose logs -f vector-store
docker-compose logs -f claude-service
```

### Problèmes d'authentification Claude
Vérifiez que vous avez correctement configuré les credentials "Claude API Authentication" dans n8n et que votre clé API est valide.

## Mise à jour automatique avec script

Pour faciliter la mise en place des workflows corrigés, utilisez l'option `--setup-corrected` du script start-technicia.sh :

```bash
./scripts/start-technicia.sh --setup-corrected
```

Cette commande vous guidera à travers l'importation des workflows corrigés.