# Documentation TechnicIA

Cette documentation couvre tous les aspects de TechnicIA, un assistant intelligent de maintenance technique qui aide les techniciens à accéder rapidement à l'information pertinente dans leur documentation technique.

## Documentation de développement

### Architecture et conception
- [Architecture du système](architecture.md) - Vue d'ensemble de l'architecture technique
- [Plan d'implémentation](implementation-plan.md) - Plan détaillé de la mise en œuvre

### Suivi du projet
- [Suivi d'implémentation](implementation-tracking.md) - État actuel de l'implémentation et historique
- [Jalons](MILESTONES.md) - Jalons principaux et leur statut
- [Notes d'historique des commits](commit-history-notes.md) - Notes sur les contributions importantes

### Workflows
- [Documentation des workflows](workflows.md) - Description détaillée des workflows n8n
- [Guide de configuration n8n](n8n-config-guide.md) - Guide pour configurer n8n
- [Workflow d'ingestion réel](workflow-ingestion-reel.md) - Documentation du workflow de traitement réel des PDF

## Documentation de déploiement et maintenance

### Déploiement
- [Guide complet de déploiement](technicia-deployment-guide.md) - Instructions détaillées pour déployer TechnicIA
- [Suivi de déploiement](deployment-tracking.md) - État actuel du déploiement et historique

### Dépannage et résolution des problèmes
- [Problèmes de déploiement](deployment-issues.md) - Liste des problèmes connus et solutions
- [Dépannage des webhooks](webhook-troubleshooting.md) - Guide de dépannage des webhooks
- [Débogage des microservices](microservices-debugging.md) - Guide pour déboguer les microservices
- [Problèmes de traitement PDF](pdf-processing-issues.md) - Guide de résolution des problèmes liés au traitement PDF
- [Gestion des logs](log-management.md) - Guide pour configurer et analyser les logs

### Rapports
- [Rapport d'état](status-report.md) - Rapport d'état global du projet

## Guide rapide de référence

### Microservices

TechnicIA est composé de plusieurs microservices qui communiquent entre eux :

| Service | Port | Rôle |
|---------|------|------|
| document-processor | 8001 | Extraction du texte et des images des PDFs |
| vision-classifier | 8002 | Classification des images et schémas techniques |
| vector-store | 8003 | Gestion des embeddings et interface avec Qdrant |
| n8n | 5678 | Orchestration des workflows |
| qdrant | 6333 | Base de données vectorielle |
| frontend | 80/443 | Interface utilisateur |

### Commandes utiles

#### Docker
```bash
# Vérifier l'état des services
docker ps

# Voir les logs d'un service
docker logs technicia-document-processor
docker logs -f technicia-n8n   # Suivre les logs en temps réel

# Redémarrer un service
docker restart technicia-document-processor

# Redémarrer tous les services
docker compose -f docker/docker-compose.yml restart
```

#### Tests rapides
```bash
# Vérifier la santé des services
curl http://localhost:8001/health
curl http://localhost:8002/health
curl http://localhost:8003/health

# Tester l'upload d'un PDF (petit fichier)
curl -X POST -F "file=@test.pdf" http://localhost:5678/webhook/upload

# Tester l'upload d'un PDF (gros fichier)
curl -X POST -F "file=@large_test.pdf" http://localhost:5678/webhook/upload
```

#### Débogage
```bash
# Vérifier les connexions entre services
docker exec technicia-n8n ping document-processor

# Accéder à un shell dans un conteneur
docker exec -it technicia-document-processor /bin/bash

# Exécuter le script de vérification du système
./scripts/system-check.sh
```

### Workflows n8n

| Workflow | Rôle | Endpoint |
|----------|------|----------|
| Document Ingestion | Ingestion et traitement des PDF | `/webhook/upload` |
| Document Ingestion (Real) | Traitement réel des PDF | `/webhook/upload` |
| Question Processing | Traitement des questions utilisateur | `/webhook/question` |
| Diagnostic Guide | Guide pas à pas pour le diagnostic | `/webhook/diagnostic` |

### Erreurs communes

| Erreur | Solution rapide |
|--------|----------------|
| "No binary data received" | Vérifiez la configuration multipart/form-data du webhook |
| "Document AI not configured" | Vérifiez les variables d'environnement et credentials Google Cloud |
| "Timeout during processing" | Augmentez les timeouts ou traitez un fichier plus petit |
| "API Key error" | Vérifiez les clés API dans les variables d'environnement |

Pour plus de détails sur les erreurs et leur résolution, consultez [pdf-processing-issues.md](pdf-processing-issues.md) et [microservices-debugging.md](microservices-debugging.md).

---

Pour toute question ou problème non couvert par cette documentation, contactez l'équipe technique.
