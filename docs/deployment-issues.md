# Problèmes connus lors du déploiement de TechnicIA MVP

Ce document répertorie les problèmes fréquemment rencontrés lors du déploiement et de l'utilisation de TechnicIA MVP, ainsi que leurs solutions.

## Problèmes de construction et déploiement

### Problème avec le Dockerfile du frontend

**Symptôme**: Lors de la construction du frontend, une erreur apparaît :
```
npm ERR! Couldn't find npm-shrinkwrap.json or package-lock.json
```

**Cause**: Le Dockerfile du frontend utilise `npm ci` qui nécessite un fichier package-lock.json qui n'est pas présent dans le repository.

**Solution**: Modifiez le Dockerfile du frontend pour utiliser `npm install` à la place de `npm ci`:

```diff
- RUN npm ci
+ RUN npm install
```
Le script de déploiement automatisé (`deploy.sh`) effectue cette modification automatiquement.

### Structure incomplète du frontend

**Symptôme**: Erreur lors de la construction du frontend indiquant que le fichier `public/index.html` est manquant.

**Cause**: Le repository peut ne pas inclure tous les fichiers nécessaires pour la structure du frontend React.

**Solution**: Créez manuellement la structure minimale requise, ou utilisez le script de déploiement automatisé qui génère cette structure.

```bash
mkdir -p /opt/technicia/frontend/public
echo '<!DOCTYPE html><html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>TechnicIA</title></head><body><div id="root"></div></body></html>' > /opt/technicia/frontend/public/index.html
```

### Variables d'environnement non chargées

**Symptôme**: Docker Compose affiche des avertissements sur les variables d'environnement non définies lors du démarrage des services.

**Cause**: Le fichier `.env` n'est pas correctement placé ou exporté.

**Solution**: Assurez-vous que le fichier `.env` est copié dans le répertoire `docker/` et que les variables sont exportées avant de lancer Docker Compose.

```bash
cp /opt/technicia/.env /opt/technicia/docker/.env
cd /opt/technicia/docker
export $(grep -v '^#' .env | xargs)
docker compose up -d
```

## Problèmes de configuration des webhooks n8n

### Webhook d'upload de document non fonctionnel

**Symptôme**: Impossible de téléverser des fichiers PDF via l'interface utilisateur, le webhook ne reçoit pas les fichiers.

**Cause**: Mauvaise configuration du webhook dans n8n, notamment utilisation de la méthode HTTP GET au lieu de POST, ou absence de configuration pour le traitement des données binaires.

**Solution**: 
1. Modifiez la configuration du webhook d'upload de documents dans n8n:
   - Changez la méthode HTTP en POST
   - Activez l'option "Raw Body" et définissez "Body Content Type" à "multipart-form-data"

2. Consultez le guide détaillé [webhook-troubleshooting.md](webhook-troubleshooting.md) pour des instructions complètes.

## Problèmes de connexion aux services externes

### Erreur d'authentification avec Google Cloud

**Symptôme**: Les services Document AI ou Vision AI échouent avec des erreurs d'authentification.

**Cause**: Le fichier de credentials Google Cloud est manquant, mal placé ou n'a pas les permissions adéquates.

**Solution**: 
1. Vérifiez que le fichier d'identifiants se trouve dans `/opt/technicia/docker/credentials/google-credentials.json`
2. Vérifiez les permissions du fichier : `chmod 600 /opt/technicia/docker/credentials/google-credentials.json`
3. Confirmez que le fichier d'identifiants a accès aux services Document AI et Vision AI

### Erreur d'authentification avec Anthropic (Claude)

**Symptôme**: Le service de chat ne fonctionne pas correctement, avec des erreurs d'authentification Anthropic.

**Cause**: Clé API manquante ou invalide pour Anthropic.

**Solution**: 
1. Vérifiez que la variable `ANTHROPIC_API_KEY` est correctement définie dans le fichier `.env`
2. Assurez-vous que la clé API a un format valide et dispose des permissions pour accéder à Claude 3.5 Sonnet

### Erreur avec VoyageAI

**Symptôme**: Les embeddings échouent ou ne sont pas générés correctement.

**Cause**: Clé API manquante ou invalide pour VoyageAI.

**Solution**:
1. Vérifiez que la variable `VOYAGE_API_KEY` est correctement définie dans le fichier `.env`
2. Vérifiez les quotas disponibles sur votre compte VoyageAI

## Problèmes de performance

### Traitement lent des documents volumineux

**Symptôme**: Le traitement des documents PDF volumineux (>50 Mo) est extrêmement lent ou échoue.

**Cause**: Ressources Docker limitées ou timeouts dans les services.

**Solution**:
1. Augmentez les ressources allouées à Docker (mémoire, CPU)
2. Augmentez les timeouts dans les services concernés (document-processor, n8n)
3. Pour les documents très volumineux, envisagez de les diviser en plusieurs fichiers plus petits

### n8n est lent ou se bloque

**Symptôme**: L'interface n8n devient lente, se bloque ou certains workflows échouent.

**Cause**: Ressources insuffisantes ou trop d'exécutions simultanées.

**Solution**:
1. Augmentez les ressources allouées au conteneur n8n
2. Ajustez les paramètres de concurrence dans n8n (réduisez le nombre d'exécutions simultanées)
3. Nettoyez régulièrement l'historique d'exécution de n8n

## Problèmes de réseau

### Échec de connexion entre les services

**Symptôme**: Certains services ne peuvent pas communiquer entre eux, par exemple Document Processor ne peut pas appeler Vector Store.

**Cause**: Problèmes avec le réseau Docker ou les noms d'hôte.

**Solution**:
1. Vérifiez que tous les services sont sur le même réseau Docker
2. Vérifiez que les services utilisent les noms d'hôte corrects (comme définis dans docker-compose.yml)
3. Testez la connectivité : `docker exec technicia-n8n ping document-processor`

## Conclusion

Si vous rencontrez un problème qui n'est pas répertorié ici, vérifiez les logs des services pour obtenir plus de détails et essayez de diagnostiquer le problème spécifique. N'hésitez pas à consulter les ressources suivantes pour des instructions supplémentaires:

- [Guide Complet de Déploiement](technicia-deployment-guide.md)
- [Guide de Configuration n8n](n8n-config-guide.md)
- [Guide de Dépannage des Webhooks](webhook-troubleshooting.md)
