# Guide d'utilisation des workflows optimisés pour TechnicIA

Ce guide explique comment utiliser les workflows optimisés pour TechnicIA, qui résolvent les problèmes de résolution DNS entre les services.

## Problème résolu

Les workflows optimisés corrigent une erreur commune où n8n essaie de se connecter aux services avec des noms préfixés par "technicia-" alors que dans le docker-compose.yml, les services sont définis sans ce préfixe.

## Workflows optimisés disponibles

1. **technicia-ingestion-optimized.json** - Pour l'ingestion des documents PDF
2. **question-optimized.json** - Pour poser des questions sur les documents indexés
3. **diagnostic-optimized.json** - Pour le diagnostic guidé des problèmes techniques

## Importation des workflows

1. Accédez à l'interface n8n à l'adresse http://localhost:5678
2. Connectez-vous avec vos identifiants
3. Allez dans la section "Workflows" et cliquez sur "Import from File"
4. Importez les fichiers dans cet ordre:
   - `workflows/technicia-ingestion-optimized.json`
   - `workflows/question-optimized.json`
   - `workflows/diagnostic-optimized.json`
5. Pour chaque workflow importé, activez-le en cliquant sur le bouton "Active"

## Configuration des credentials pour Claude

Pour que les workflows fonctionnent correctement, vous devez configurer les credentials pour l'API Claude:

1. Dans n8n, allez dans **Settings** (⚙️) puis **Credentials**
2. Cliquez sur **+ Add Credential**
3. Choisissez le type **HTTP Header Auth**
4. Remplissez les champs suivants:
   - **Name**: Claude API Authentication
   - **Name**: x-api-key
   - **Value**: Votre clé API Anthropic (la même que dans votre fichier .env)
5. Cliquez sur **Save**

## Utilisation des workflows

### Ingestion de documents

Le workflow d'ingestion permet d'indexer des documents PDF dans TechnicIA:

1. Utilisez le webhook: `http://localhost:5678/webhook/upload`
2. Méthode: POST avec un formulaire multipart/form-data
3. Paramètre: "file" contenant le fichier PDF

Exemple avec curl:
```bash
curl -X POST -F "file=@chemin/vers/votre/document.pdf" http://localhost:5678/webhook/upload
```

Ou utilisez le script fourni:
```bash
./scripts/start-technicia.sh --import chemin/vers/votre/document.pdf
```

### Poser des questions

Le workflow de questions vous permet d'interroger les documents indexés:

1. Utilisez le webhook: `http://localhost:5678/webhook/question`
2. Méthode: POST avec un corps JSON
3. Format du corps:
```json
{
  "question": "Votre question sur la documentation technique"
}
```

Exemple avec curl:
```bash
curl -X POST http://localhost:5678/webhook/question \
  -H "Content-Type: application/json" \
  -d '{"question": "Comment fonctionne le circuit hydraulique?"}'
```

### Diagnostic guidé

Le workflow de diagnostic offre une approche pas à pas pour résoudre les problèmes:

1. Initier un diagnostic:
   - Webhook: `http://localhost:5678/webhook/diagnostic`
   - Méthode: POST avec un corps JSON
   - Format:
   ```json
   {
     "symptoms": "Description des symptômes du problème",
     "equipment": "Type ou modèle d'équipement concerné"
   }
   ```

2. Traiter les étapes du diagnostic:
   - Webhook: `http://localhost:5678/webhook/diagnostic/step`
   - Méthode: POST avec un corps JSON
   - Format:
   ```json
   {
     "sessionId": "ID de session retourné par l'étape précédente",
     "stepIndex": 0,
     "stepResult": "Résultat du test effectué"
   }
   ```

## Résolution de problèmes

Si vous rencontrez des problèmes malgré l'utilisation des workflows optimisés:

1. Vérifiez que tous les services sont bien démarrés:
```bash
docker-compose ps
```

2. Vérifiez les logs des services:
```bash
docker-compose logs -f document-processor
docker-compose logs -f vector-store
docker-compose logs -f claude-service
```

3. Testez la connectivité entre les services:
```bash
docker exec -it n8n ping document-processor
docker exec -it n8n ping vector-store
```

4. Si nécessaire, redémarrez tous les services:
```bash
./scripts/start-technicia.sh --clean
```

## Notes importantes

- Les workflows optimisés utilisent les noms de services exacts tels que définis dans le docker-compose.yml
- Si vous modifiez les noms des services dans docker-compose.yml, vous devrez ajuster les URLs dans les workflows en conséquence
- Vérifiez toujours que les webhooks et les endpoints d'API sont correctement configurés
