# Guide de migration TechnicIA v1 vers v2

Ce document décrit le processus de migration d'une installation existante de TechnicIA v1 vers la nouvelle version 2, avec une attention particulière aux modifications des workflows n8n et des APIs de microservices.

## Changements majeurs

L'architecture de TechnicIA v2 introduit plusieurs améliorations:

1. **Document Processor amélioré**: Ajout d'une API par chemin de fichier pour éviter les transferts redondants
2. **Nomenclature standardisée des services**:
   - `vision-classifier` → `schema-analyzer`
   - `vector-store` → `vector-engine`
3. **Interfaces API uniformisées** avec préfixe `/api/` pour les nouvelles fonctionnalités
4. **Workflows n8n optimisés** pour une meilleure gestion des fichiers volumineux

## Compatibilité ascendante

Toutes les modifications ont été conçues pour préserver la compatibilité avec les installations existantes:

- Les anciennes APIs restent disponibles et fonctionnelles
- Les nouveaux services peuvent coexister avec les anciens
- Les workflows précédents continuent de fonctionner

## Étapes de migration

### 1. Préparation

Avant de commencer la migration:

```bash
# Créer une sauvegarde de votre configuration actuelle
cp docker-compose.yml docker-compose.yml.bak
cp -r services services.bak
cp -r workflows workflows.bak

# Créer une sauvegarde de vos données Qdrant (si applicable)
# Arrêter les services
./scripts/start-technicia.sh --stop
```

### 2. Mise à jour du code source

```bash
# Récupérer les derniers changements
git fetch origin
git checkout main
git pull

# En cas de modifications locales
git stash
git pull
git stash pop
```

### 3. Migration minimale (recommandée)

Si vous souhaitez conserver votre architecture actuelle tout en bénéficiant des corrections:

```bash
# Mettre à jour uniquement le service Document Processor
cp -f services/document-processor/main.py services.bak/document-processor/main.py

# Redémarrer seulement ce service
docker-compose up -d --build document-processor
```

Puis, dans n8n:
1. Importez le workflow `technicia-ingestion-pure-microservices-fixed.json`
2. Activez ce nouveau workflow et désactivez l'ancien

### 4. Migration complète

Pour passer entièrement à la nouvelle architecture:

```bash
# Appliquer les changements du docker-compose
cp docker-compose.yml.bak docker-compose.yml

# Mise à jour des services existants
cp -f services/document-processor/main.py services.bak/document-processor/main.py

# Créer les nouveaux services (s'ils n'existent pas encore)
mkdir -p services/schema-analyzer
cp -r services/schema-analyzer/* services.bak/vision-classifier/

mkdir -p services/vector-engine
cp -r services/vector-engine/* services.bak/vector-store/

# Démarrer tous les services avec la nouvelle configuration
./scripts/start-technicia.sh --build
```

Puis, dans n8n:
1. Importez tous les workflows mis à jour depuis le dossier `workflows`
2. Activez les nouveaux workflows et désactivez les anciens

## Migration des données (si nécessaire)

Si vous avez des données importantes dans l'ancienne collection Qdrant:

```bash
# Script pour migrer les données (à adapter selon votre configuration)
python scripts/migrate_qdrant_data.py \
  --source-collection technicia_old \
  --target-collection technicia \
  --host localhost \
  --port 6333
```

## Vérification de la migration

Après la migration:

```bash
# Vérifier l'état des services
./scripts/start-technicia.sh --status

# Tester tous les services
./scripts/test-services.sh --all
```

## Résolution des problèmes courants

### Problème: Les workflows n8n utilisent encore les anciens endpoints

**Solution**:
1. Dans n8n, ouvrez le workflow problématique
2. Vérifiez les nœuds HTTP Request pointant vers les microservices
3. Mettez à jour les URLs et paramètres selon la nouvelle API

### Problème: Doublons de services dans docker-compose

**Solution**:
Vérifiez votre docker-compose.yml et supprimez les entrées dupliquées:
- Si vous avez à la fois `vision-classifier` et `schema-analyzer`, gardez un seul
- Si vous avez à la fois `vector-store` et `vector-engine`, gardez un seul

### Problème: Les anciens et nouveaux services utilisent les mêmes ports

**Solution**:
Modifiez les mappings de ports dans docker-compose.yml pour éviter les conflits:
```yaml
schema-analyzer:
  ports:
    - "8002:8002"  # Port original
vision-classifier:
  ports:
    - "8012:8002"  # Port alternatif
```

## Support et assistance

Si vous rencontrez des difficultés lors de la migration:
1. Consultez la [documentation détaillée](../architecture/service-naming.md)
2. Utilisez le script de dépannage: `./scripts/test-services.sh --all`
3. Contactez l'équipe de support technique si les problèmes persistent

## Retour à la version précédente

En cas de problème majeur, vous pouvez revenir à la version précédente:

```bash
# Restaurer les fichiers sauvegardés
cp docker-compose.yml.bak docker-compose.yml
cp -r services.bak/* services/

# Redémarrer les services
docker-compose down
docker-compose up -d
```

Dans n8n, réactivez les anciens workflows.
