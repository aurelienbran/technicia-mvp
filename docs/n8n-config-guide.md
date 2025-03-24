# Guide de Configuration de n8n pour TechnicIA

Ce guide détaille la configuration complète de n8n pour le projet TechnicIA, en se concentrant sur l'importation et la configuration des workflows et des credentials nécessaires.

## Table des matières

1. [Introduction](#introduction)
2. [Accès à l'interface n8n](#accès-à-linterface-n8n)
3. [Configuration initiale](#configuration-initiale)
4. [Importation des workflows](#importation-des-workflows)
5. [Configuration des credentials](#configuration-des-credentials)
6. [Vérification et activation des workflows](#vérification-et-activation-des-workflows)
7. [Personnalisation des workflows](#personnalisation-des-workflows)
8. [Dépannage](#dépannage)

## Introduction

n8n est la plateforme d'orchestration centrale de TechnicIA. Elle permet de coordonner les différents services (Document AI, Vision AI, Claude, etc.) et de gérer les flux de travail pour l'ingestion de documents, le traitement des questions et le diagnostic guidé.

## Accès à l'interface n8n

Après le déploiement de TechnicIA, n8n est accessible à l'adresse :

- http://votre-ip-ou-domaine:5678

Si vous avez configuré HTTPS, utilisez :

- https://votre-ip-ou-domaine:5678

## Configuration initiale

### Création du compte administrateur

Lors de votre première connexion, n8n vous demandera de créer un compte administrateur :

1. Entrez votre adresse e-mail
2. Créez un mot de passe fort
3. Cliquez sur "Create owner"

Ce compte sera utilisé pour toutes les configurations futures et l'accès à l'interface d'administration.

### Vérification de la connexion aux services

Avant de configurer les workflows, assurez-vous que n8n peut communiquer avec les autres services :

1. Accédez à l'onglet "Settings" dans le menu latéral
2. Cliquez sur "API" dans la sous-navigation
3. Vérifiez que le protocole est correctement configuré (HTTP ou HTTPS)
4. Assurez-vous que l'URL de base correspond à votre domaine ou IP
5. Vérifiez que l'URL des webhooks est correctement définie

## Importation des workflows

TechnicIA utilise trois workflows principaux, tous disponibles dans le répertoire `/opt/technicia/workflows` :

### Méthode d'importation

1. Dans l'interface n8n, cliquez sur "Workflows" dans le menu latéral
2. Cliquez sur le bouton "+ Create Workflow" en haut à droite
3. Dans le menu déroulant, sélectionnez "Import from File"
4. Naviguez jusqu'au répertoire `/opt/technicia/workflows`
5. Sélectionnez le fichier workflow à importer (un à la fois)
6. Cliquez sur "Import"

### Workflow d'ingestion de documents

Fichier : `ingestion.json`

Ce workflow gère le processus d'ingestion des documents PDF, leur traitement via Document AI et Vision AI, et leur indexation dans Qdrant.

Après l'importation :
1. Ouvrez le workflow pour vérifier sa structure
2. Vérifiez les nœuds HTTP Request (vers Document Processor, Vision Classifier, etc.)
3. Assurez-vous que les URLs pointent vers les bons services (document-processor:8000, etc.)

### Workflow de traitement des questions

Fichier : `question.json`

Ce workflow traite les questions des utilisateurs en recherchant les informations pertinentes dans la base vectorielle et en générant des réponses via Claude.

Après l'importation :
1. Vérifiez le nœud de webhook (qui doit être exposé pour recevoir les questions)
2. Vérifiez la configuration du nœud "Call Claude API"
3. Assurez-vous que le nœud de recherche vectorielle pointe vers le bon service

### Workflow de diagnostic guidé

Fichier : `diagnosis.json`

Ce workflow pilote le processus de diagnostic pas à pas en collectant des informations et en générant des recommandations.

Après l'importation :
1. Vérifiez les nœuds de webhook (début de diagnostic, étapes, etc.)
2. Vérifiez la configuration des appels à Claude
3. Assurez-vous que la logique de diagnostic est cohérente

## Configuration des credentials

Pour que les workflows fonctionnent correctement, vous devez configurer plusieurs credentials :

### 1. Google Cloud Service Account

1. Dans le menu latéral, cliquez sur "Credentials"
2. Cliquez sur le bouton "+ Credential" en haut à droite
3. Recherchez et sélectionnez "Google Cloud Service Account"
4. Entrez les informations suivantes :
   - Nom : `google-cloud`
   - Description : `Credentials pour les services Google Cloud (Document AI, Vision AI)`
   - Method : `Service Account`
   - Service Account : Téléchargez votre fichier JSON de credentials
5. Cliquez sur "Save"

### 2. Anthropic API (pour Claude)

1. Cliquez sur "+ Credential"
2. Recherchez et sélectionnez "HTTP Header Auth"
3. Entrez les informations suivantes :
   - Nom : `anthropic-api`
   - Description : `API Key pour Anthropic Claude`
   - Name : `x-api-key`
   - Value : Votre clé API Anthropic
4. Cliquez sur "Save"

### 3. Voyage AI (pour embeddings)

1. Cliquez sur "+ Credential"
2. Recherchez et sélectionnez "HTTP Header Auth"
3. Entrez les informations suivantes :
   - Nom : `voyage-api`
   - Description : `API Key pour Voyage AI`
   - Name : `Authorization`
   - Value : `Bearer votre-clé-api-voyage`
4. Cliquez sur "Save"

### 4. Microservices Authentication (si nécessaire)

1. Cliquez sur "+ Credential"
2. Recherchez et sélectionnez "HTTP Basic Auth"
3. Entrez les informations suivantes :
   - Nom : `technicia-services`
   - Description : `Auth pour les microservices TechnicIA`
   - User : `admin` (ou utilisateur configuré)
   - Password : `password` (ou mot de passe configuré)
4. Cliquez sur "Save"

## Vérification et activation des workflows

Une fois les workflows importés et les credentials configurés, vous devez :

### 1. Associer les credentials aux nœuds

Pour chaque workflow :
1. Ouvrez le workflow
2. Cliquez sur chaque nœud utilisant des API externes
3. Dans l'onglet "Credentials", sélectionnez les credentials appropriés
4. Enregistrez les modifications

### 2. Tester les workflows

1. Pour chaque workflow, cliquez sur le bouton "Execute Workflow" en bas à droite
2. Observez les résultats dans la vue "Execution"
3. Vérifiez que chaque nœud s'exécute correctement (indicateur vert)
4. Consultez les données d'entrée/sortie de chaque nœud pour vérifier le bon fonctionnement

### 3. Activer les webhooks

Pour chaque workflow utilisant des webhooks :
1. Cliquez sur le nœud webhook
2. Notez l'URL du webhook (généralement de la forme `https://votre-domaine.com/webhook/xxx-xxx-xxx`)
3. Cliquez sur "Active" en haut à droite du workflow pour l'activer

## Personnalisation des workflows

### Adaptation aux spécificités de votre installation

Selon votre VPS et votre configuration, vous pourriez avoir besoin d'adapter les workflows :

1. **URLs des services** : Si vos services ne sont pas accessibles via les noms de conteneurs Docker, vous devrez mettre à jour les URLs dans les nœuds HTTP Request

2. **Configuration de base** : 
   - Ouvrez chaque workflow
   - Vérifiez les variables et constantes définies dans les nœuds "Set"
   - Adaptez ces valeurs en fonction de votre environnement

3. **Personnalisation des prompts** : 
   - Dans les workflows qui utilisent Claude, vous pouvez personnaliser les prompts dans les nœuds "Function" qui préparent le contexte
   - Ajustez le "system prompt" et le format des questions pour obtenir des réponses plus adaptées à vos besoins

### Exemples d'adaptations courantes

- **Modification des URLs de service** : Dans les nœuds HTTP Request, remplacez `http://service-name:port/` par `http://votre-ip:port/` si nécessaire
- **Ajustement des timeouts** : Pour les documents volumineux, augmentez les timeouts des requêtes dans les nœuds HTTP Request
- **Personnalisation des messages d'erreur** : Dans les nœuds "Error", adaptez les messages pour qu'ils soient plus informatifs ou adaptés à vos utilisateurs

## Dépannage

### Problèmes courants et solutions

#### 1. Workflow non déclenché

**Symptômes** : Le workflow ne s'exécute pas lorsqu'il est appelé.

**Solutions** :
- Vérifier que le workflow est activé (bouton "Active" en haut à droite)
- Vérifier que l'URL du webhook est correcte et accessible
- Vérifier les logs n8n pour détecter d'éventuelles erreurs

#### 2. Erreurs d'appels API

**Symptômes** : Les nœuds HTTP Request échouent avec des erreurs.

**Solutions** :
- Vérifier que les credentials sont correctement configurés
- Vérifier que les services sont accessibles depuis le conteneur n8n
- Vérifier le format des requêtes (headers, body, etc.)
- Vérifier les quotas et limites des API externes

#### 3. Problèmes avec Claude

**Symptômes** : Les appels à Claude échouent ou génèrent des réponses inappropriées.

**Solutions** :
- Vérifier la clé API Anthropic
- Vérifier le format des prompts (doit suivre les conventions Claude)
- Réduire la taille du contexte si nécessaire (limite de tokens)
- Vérifier que le modèle spécifié est disponible

### Consulter les logs

Pour diagnostiquer les problèmes, consultez les logs n8n :

```bash
docker logs technicia-n8n
```

Ou pour un suivi en temps réel :

```bash
docker logs -f technicia-n8n
```

### Reconfiguration complète

En cas de problèmes persistants, vous pouvez réinitialiser complètement la configuration n8n :

```bash
# Arrêter n8n
docker stop technicia-n8n

# Sauvegarder les données actuelles
cp -r /opt/technicia/docker/n8n/data /opt/technicia/docker/n8n/data.bak

# Supprimer la configuration actuelle
rm -rf /opt/technicia/docker/n8n/data

# Redémarrer n8n (cela créera une nouvelle configuration vierge)
docker start technicia-n8n

# Puis réimporter les workflows depuis les fichiers .json
```

---

Ce guide détaillé devrait vous permettre de configurer correctement n8n pour TechnicIA. Si vous rencontrez des problèmes spécifiques non couverts ici, consultez la [documentation officielle de n8n](https://docs.n8n.io/) ou contactez l'équipe de support TechnicIA.