# Plan d'Implémentation TechnicIA MVP

## Objectif

Ce document détaille le plan d'implémentation pour finaliser le MVP de TechnicIA en se basant sur l'état actuel du repository et en maximisant l'utilisation de n8n pour l'orchestration.

## Principes directeurs

1. **Maximiser l'usage de n8n** : Utiliser n8n pour toutes les tâches d'orchestration, d'intégration et de transformation de données basiques
2. **Microservices spécialisés** : Développer des microservices uniquement pour les fonctionnalités qui ne peuvent pas être réalisées efficacement via n8n
3. **Architecture hybride** : Combiner n8n et microservices dans une architecture cohérente et flexible

## État actuel du repository

D'après l'analyse du repository "aurelienbran/technicia-mvp", nous disposons déjà de :

- **Documentation détaillée** (architecture, déploiement, workflows)
- **Configuration Docker** avec docker-compose.yml pour 5 services
- **Deux microservices implémentés** :
  - `document-processor` : Service FastAPI pour le traitement des PDFs via Document AI
  - `vision-classifier` : Service FastAPI pour la classification des images via Vision AI

## Composants manquants à implémenter

1. **Service vector-store** (référencé dans docker-compose.yml mais non implémenté)
2. **Workflows n8n** (décrits dans la documentation mais non implémentés)
3. **Initialisation de Qdrant** (configuration de la base vectorielle)
4. **Interface utilisateur** (front-end minimal pour interagir avec le système)

## Plan d'implémentation par phases

### Phase 1 : Complétion des microservices essentiels (Semaine 1)

#### 1.1 Implémentation du service vector-store

Ce service est crucial car il gère l'interface avec Qdrant et les embeddings - il s'agit d'une tâche qui n'est pas adaptée à n8n.

**Fichiers à créer** :
- `services/vector-store/main.py` - API FastAPI
- `services/vector-store/requirements.txt` - Dépendances
- `services/vector-store/Dockerfile` - Configuration Docker

**Fonctionnalités** :
- API pour générer des embeddings via VoyageAI
- Interface avec Qdrant pour la recherche vectorielle
- Gestion des collections et des métadonnées
- Endpoints pour l'upsert et la recherche sémantique

**Estimation** : 2 jours

#### 1.2 Script d'initialisation de Qdrant

**Fichiers à créer** :
- `scripts/init_qdrant.py` - Script Python pour initialiser la collection
- `docker/init_scripts/init_collections.sh` - Script shell pour l'exécution au démarrage

**Fonctionnalités** :
- Création de la collection avec les paramètres appropriés
- Configuration des index pour les métadonnées
- Vérification de l'existence et initialisation conditionnelle

**Estimation** : 1 jour

#### 1.3 Mise à jour du docker-compose.yml

**Modifications** :
- Ajout d'un service d'initialisation pour Qdrant
- Configuration des volumes partagés entre services
- Configuration des variables d'environnement

**Estimation** : 0.5 jour

### Phase 2 : Configuration et développement des workflows n8n (Semaine 2)

#### 2.1 Configuration de l'environnement n8n

**Actions** :
- Créer un dossier pour les credentials et variables
- Configurer les noeuds personnalisés si nécessaire
- Préparer les webhooks et points d'entrée

**Estimation** : 1 jour

#### 2.2 Workflow d'ingestion de documents

**Fonctionnalités à implémenter via n8n** :
- Réception du document via webhook
- Orchestration du processus d'ingestion
- Appels aux microservices pour les tâches spécialisées
- Suivi et notification de l'état d'avancement

**Séquence d'étapes** :
1. Webhook pour recevoir le PDF
2. Vérification de la taille et du format
3. Conditionnement selon la taille du fichier
4. Appel au Document Processor pour l'extraction
5. Appel au Vision Classifier pour l'analyse des images
6. Appel au Vector Store pour l'indexation
7. Notification de fin de traitement

**Estimation** : 2 jours

#### 2.3 Workflow de traitement des questions

**Fonctionnalités à implémenter via n8n** :
- Réception et formatage des questions
- Orchestration de la recherche et génération de réponses
- Traitement des réponses et inclusions des références

**Séquence d'étapes** :
1. Webhook pour recevoir la question
2. Formatage et préparation de la requête
3. Appel au Vector Store pour la recherche sémantique
4. Construction du contexte pour le LLM
5. Appel à Claude 3.5 Sonnet pour la génération de réponse
6. Post-traitement de la réponse et extraction des références
7. Renvoi de la réponse structurée

**Estimation** : 2 jours

#### 2.4 Workflow de diagnostic guidé

**Fonctionnalités à implémenter via n8n** :
- Gestion du processus de diagnostic pas à pas
- Conservation de l'état entre les étapes
- Orchestration des appels au LLM pour les analyses

**Séquence d'étapes** :
1. Webhook pour démarrer le diagnostic
2. Initialisation du plan de diagnostic
3. Boucle d'étapes avec webhooks intermédiaires
4. Analyse des réponses à chaque étape
5. Génération de recommandations contextuelles
6. Finalisation et rapport de diagnostic

**Estimation** : 2 jours

### Phase 3 : Développement de l'interface utilisateur minimale (Semaine 3)

Pour l'interface utilisateur, nous allons développer un front-end minimaliste en React qui interagira avec les workflows n8n via les webhooks.

#### 3.1 Structure et configuration du frontend

**Fichiers à créer** :
- Structure de base React
- Configuration de build
- Dockerfile pour le déploiement

**Estimation** : 1 jour

#### 3.2 Module d'upload de documents

**Fonctionnalités** :
- Interface de glisser-déposer pour les fichiers PDF
- Visualisation de la progression
- Feedback sur l'état du traitement

**Estimation** : 1 jour

#### 3.3 Interface de chat

**Fonctionnalités** :
- Zone de saisie des questions
- Affichage des réponses avec formatage Markdown
- Visualisation des schémas techniques référencés
- Historique de conversation

**Estimation** : 2 jours

#### 3.4 Module de diagnostic guidé

**Fonctionnalités** :
- Interface pas à pas pour le diagnostic
- Formulaires dynamiques selon l'étape
- Affichage des recommandations et schémas

**Estimation** : 2 jours

### Phase 4 : Intégration, tests et déploiement (Semaine 4)

#### 4.1 Intégration complète du système

**Actions** :
- Vérification des interactions entre composants
- Test de bout en bout des workflows
- Ajustements des configurations

**Estimation** : 2 jours

#### 4.2 Tests fonctionnels

**Actions** :
- Test de l'upload de documents de différentes tailles
- Test de diverses questions et requêtes
- Test du processus de diagnostic complet

**Estimation** : 2 jours

#### 4.3 Finalisation du déploiement

**Actions** :
- Mise à jour de la documentation de déploiement
- Création de scripts de déploiement automatisé
- Configuration du monitoring et des sauvegardes

**Estimation** : 1 jour

## Répartition entre n8n et microservices

### Tâches réalisées via n8n

1. **Orchestration globale** du pipeline d'ingestion et de traitement
2. **Intégration avec les services externes** (Document AI, Vision AI, Claude)
3. **Transformations de données basiques** (formatage, structuration)
4. **Logique conditionnelle** pour le routage des flux
5. **Gestion des webhooks** et points d'entrée
6. **Notification et suivi** des processus
7. **Construction des prompts** pour le LLM

### Tâches nécessitant des microservices

1. **Traitement des documents volumineux** (document-processor)
   - Raison : Gestion avancée de la mémoire et traitement asynchrone
   
2. **Classification d'images et schémas** (vision-classifier)
   - Raison : Traitement spécialisé des images et intégration complexe avec Vision AI
   
3. **Gestion des embeddings et recherche vectorielle** (vector-store)
   - Raison : Interaction complexe avec Qdrant et optimisations de recherche

4. **Interface utilisateur** (frontend)
   - Raison : n8n n'est pas conçu pour créer des interfaces utilisateur interactives

## Chronologie estimée

- **Semaine 1** : Complétion des microservices essentiels
- **Semaine 2** : Configuration et développement des workflows n8n
- **Semaine 3** : Développement de l'interface utilisateur minimale
- **Semaine 4** : Intégration, tests et déploiement

## Prochaines étapes immédiates

1. Implémenter le service vector-store
2. Créer le script d'initialisation de Qdrant
3. Mettre à jour le docker-compose.yml avec les nouveaux services
4. Commencer le développement des workflows n8n

Ce plan d'implémentation maximise l'utilisation de n8n pour l'orchestration tout en s'appuyant sur des microservices spécialisés uniquement pour les tâches qui nécessitent des capacités au-delà de ce que n8n peut offrir.