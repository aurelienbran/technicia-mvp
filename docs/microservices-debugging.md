# Guide de débogage des microservices TechnicIA

Ce document fournit des instructions détaillées pour le débogage des microservices qui composent TechnicIA, en mettant particulièrement l'accent sur le traitement des PDF.

## Table des matières

1. [Outils de débogage](#outils-de-débogage)
2. [Surveillance des logs](#surveillance-des-logs)
3. [Diagnostic du service document-processor](#diagnostic-du-service-document-processor)
4. [Diagnostic du service vision-classifier](#diagnostic-du-service-vision-classifier)
5. [Diagnostic du service vector-store](#diagnostic-du-service-vector-store)
6. [Diagnostic n8n](#diagnostic-n8n)
7. [Problèmes courants et solutions](#problèmes-courants-et-solutions)
8. [Vérification de l'état du système](#vérification-de-létat-du-système)

## Outils de débogage

### Outils Docker

```bash
# Vérifier l'état de tous les conteneurs
docker ps -a

# Consulter les logs d'un service spécifique
docker logs technicia-document-processor
docker logs technicia-vision-classifier
docker logs technicia-vector-store
docker logs technicia-n8n

# Suivre les logs en temps réel
docker logs -f technicia-document-processor

# Inspecter les ressources utilisées
docker stats

# Accéder à un shell dans un conteneur pour le débogage
docker exec -it technicia-document-processor /bin/bash
```

### Outils réseau

```bash
# Vérifier la communication entre les services
docker exec technicia-n8n ping document-processor
docker exec technicia-n8n ping vision-classifier
docker exec technicia-n8n ping vector-store

# Tester un endpoint API
docker exec technicia-n8n curl -s http://document-processor:8000/health | jq
```

## Surveillance des logs

### Centralisation des logs

Tous les logs des services sont accessibles via Docker. Pour une solution plus avancée:

1. Créez un fichier `docker-compose.override.yml` dans le dossier `docker/`:

```yaml
version: '3.8'

services:
  document-processor:
    logging:
      driver: "json-file"
      options:
        max-size: "100m"
        max-file: "3"
        
  vision-classifier:
    logging:
      driver: "json-file"
      options:
        max-size: "100m"
        max-file: "3"
        
  vector-store:
    logging:
      driver: "json-file"
      options:
        max-size: "100m"
        max-file: "3"
        
  n8n:
    logging:
      driver: "json-file"
      options:
        max-size: "200m"
        max-file: "3"
```

2. Redémarrez les services:

```bash
cd docker
docker compose down
docker compose up -d
```

### Analyse des logs

Utilisez ces commandes pour extraire des informations pertinentes des logs:

```bash
# Extraire les erreurs du document-processor
docker logs technicia-document-processor 2>&1 | grep -i error

# Extraire les avertissements du vision-classifier
docker logs technicia-vision-classifier 2>&1 | grep -i warning

# Vérifier les problèmes d'authentification API
docker logs technicia-vector-store 2>&1 | grep -i "api key" | grep -i error
```

## Diagnostic du service document-processor

### Vérification de l'état du service

```bash
curl http://localhost:8001/health
```

Réponse attendue:
```json
{
  "status": "healthy",
  "google_cloud_configured": true,
  "temp_dir": "/tmp/technicia",
  "active_tasks": 0
}
```

Si `google_cloud_configured` est `false`, vérifiez les variables d'environnement.

### Tests d'endpoints

#### Test de l'endpoint `/process`

```bash
curl -X POST -F "file=@./test_docs/small.pdf" http://localhost:8001/process
```

#### Test de l'endpoint `/process-large-file`

```bash
curl -X POST -F "file=@./test_docs/large.pdf" http://localhost:8001/process-large-file
```

Vérifiez l'ID de tâche retourné, puis:

```bash
curl http://localhost:8001/task/[task_id]
```

### Problèmes spécifiques

1. **Erreur Document AI**:
   - Vérifiez le fichier credentials Google Cloud
   - Confirmez que le processor Document AI existe et est accessible
   - Vérifiez que le projet GCP a les APIs activées

2. **Erreur d'extraction**:
   - Vérifiez que le PDF est lisible
   - Assurez-vous que le document n'est pas corrompu ou protégé
   - Augmentez le niveau de log pour le débogage détaillé

## Diagnostic du service vision-classifier

### Vérification de l'état du service

```bash
curl http://localhost:8002/health
```

### Test de classification d'image

```bash
curl -X POST -F "file=@./test_docs/schematic.png" http://localhost:8002/classify
```

### Problèmes spécifiques

1. **Erreur Vision AI**:
   - Vérifiez les credentials Google Cloud
   - Confirmez que l'API Vision est activée

2. **Classification incorrecte**:
   - Ajustez les seuils de détection dans le code source
   - Vérifiez les schémas techniques non reconnus

## Diagnostic du service vector-store

### Vérification de l'état du service

```bash
curl http://localhost:8003/health
```

### Test de vectorisation

```bash
curl -X POST http://localhost:8003/embed-text \
  -H "Content-Type: application/json" \
  -d '{"text": "Test de vectorisation", "metadata": {"test": true}}'
```

### Problèmes spécifiques

1. **Erreur Qdrant**:
   - Vérifiez que Qdrant est en cours d'exécution: `docker ps | grep qdrant`
   - Vérifiez la connectivité: `docker exec technicia-vector-store ping qdrant`

2. **Erreur VoyageAI**:
   - Vérifiez la clé API dans les variables d'environnement
   - Vérifiez les quotas de votre compte VoyageAI

## Diagnostic n8n

### Accès à l'interface n8n

Ouvrez http://localhost:5678 dans votre navigateur.

### Vérification des workflows

1. Allez dans la section "Workflows" 
2. Vérifiez l'état d'activation de chaque workflow
3. Examinez les exécutions récentes pour identifier les erreurs

### Problèmes spécifiques

1. **Erreur webhook**:
   - Vérifiez la configuration du webhook (méthode HTTP, options)
   - Testez le webhook avec un outil comme Postman

2. **Erreur de traitement de fichier**:
   - Examinez le nœud "Validate & Prepare File" pour voir si le fichier est correctement capturé
   - Vérifiez les propriétés binaires du fichier dans les exécutions

3. **Erreur HTTP**:
   - Vérifiez les URLs des endpoints dans les nœuds HTTP Request
   - Assurez-vous que les services sont accessibles depuis n8n

## Problèmes courants et solutions

### 1. Le PDF n'est pas traité correctement

**Symptômes**:
- Message d'erreur dans les logs du document-processor
- Aucun texte ou image n'est extrait

**Solutions**:
1. Vérifiez le format du PDF (utilisez `file` pour confirmer qu'il s'agit bien d'un PDF)
2. Essayez un autre PDF pour déterminer si le problème est spécifique au fichier
3. Augmentez la mémoire allouée au conteneur document-processor

### 2. Les images ne sont pas classifiées

**Symptômes**:
- Aucune image n'apparaît dans les résultats
- Erreurs de classification dans les logs

**Solutions**:
1. Vérifiez que Vision AI est correctement configuré
2. Ajustez les seuils de détection dans le code
3. Vérifiez si les images sont correctement extraites du PDF

### 3. La vectorisation échoue

**Symptômes**:
- Erreurs dans les logs du vector-store
- Aucun vecteur n'est stocké dans Qdrant

**Solutions**:
1. Vérifiez la clé API VoyageAI
2. Confirmez que Qdrant est accessible
3. Vérifiez que la collection existe dans Qdrant

### 4. n8n workflow échoue

**Symptômes**:
- Exécutions en erreur dans l'interface n8n
- Message d'erreur dans les logs n8n

**Solutions**:
1. Vérifiez chaque nœud individuellement pour isoler le problème
2. Augmentez les timeouts pour les nœuds HTTP Request 
3. Vérifiez les formats de données entre les nœuds

## Vérification de l'état du système

Pour vérifier rapidement l'état de tous les services, exécutez:

```bash
./scripts/system-check.sh
```

Ce script vérifie:
1. L'état de tous les conteneurs Docker
2. La santé de chaque service via son endpoint /health
3. La connectivité entre les services
4. L'état des APIs externes

Si vous ne disposez pas de ce script, voici un exemple simplifié:

```bash
#!/bin/bash

echo "=== Vérification des conteneurs ==="
docker ps -a

echo -e "\n=== Vérification des endpoints de santé ==="
echo "Document Processor:"
curl -s http://localhost:8001/health | jq

echo "Vision Classifier:"
curl -s http://localhost:8002/health | jq

echo "Vector Store:"
curl -s http://localhost:8003/health | jq

echo -e "\n=== Vérification des connexions entre services ==="
echo "Document Processor -> Vector Store:"
docker exec technicia-document-processor curl -s http://vector-store:8000/health > /dev/null && echo "OK" || echo "FAIL"

echo "n8n -> Document Processor:"
docker exec technicia-n8n curl -s http://document-processor:8000/health > /dev/null && echo "OK" || echo "FAIL"
```

---

Ce guide peut être complété et amélioré en fonction des problèmes spécifiques rencontrés lors de l'utilisation de TechnicIA. N'hésitez pas à documenter les nouveaux problèmes et solutions découverts.
