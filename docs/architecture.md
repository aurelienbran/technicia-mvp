# Architecture Détaillée de TechnicIA

## Vue d'ensemble

TechnicIA est construit sur une architecture hybride qui combine l'orchestration via n8n avec des microservices spécialisés et des services cloud pour le traitement de l'IA. Cette approche permet de bénéficier de la flexibilité de n8n pour l'orchestration tout en exploitant des services spécialisés pour les tâches complexes.

## Composants de l'Architecture

### 1. Orchestration (n8n)

n8n sert de couche d'orchestration principale, coordonnant les différentes étapes des processus métier et facilitant l'intégration entre les composants. Les workflows n8n définissent la logique de traitement et les flux de données entre les services.

**Avantages de n8n :**
- Interface visuelle facilitant la compréhension des processus
- Capacité à gérer des tâches asynchrones et des retries
- Facilité d'intégration avec divers services via HTTP
- Possibilité d'exécution conditionnelle et de routage dynamique

### 2. Microservices Python (FastAPI)

Les microservices Python fournissent des fonctionnalités spécialisées qui nécessitent plus de flexibilité ou de puissance de traitement que ce que peut offrir n8n directement.

#### Document Processor Service
- **Responsabilités** : Traitement des PDF volumineux, extraction de contenu, préparation pour Document AI
- **Technologies** : FastAPI, PyMuPDF, Google Cloud Client Libraries
- **Points forts** : Gestion asynchrone, processing parallèle, gestion de la mémoire

#### Vision Classifier Service
- **Responsabilités** : Classification des images et schémas techniques, détection du type de schéma
- **Technologies** : FastAPI, Google Vision AI, OpenCV
- **Points forts** : Classification spécialisée pour les schémas techniques (électriques, hydrauliques, pneumatiques)

#### Vector Store Interface
- **Responsabilités** : Gestion des embeddings et de la base vectorielle
- **Technologies** : FastAPI, VoyageAI, Qdrant Client
- **Points forts** : Optimisation des requêtes vectorielles, filtrage contextuel

### 3. Services Cloud Google

Les services Google Cloud fournissent des capacités d'IA avancées pour le traitement de documents et d'images.

#### Document AI
- **Usage** : Extraction précise de texte à partir de PDFs techniques
- **Capacités** : OCR avancé, extraction structurée, détection de tableaux

#### Vision AI
- **Usage** : Analyse et classification des schémas techniques
- **Capacités** : Détection d'objets, OCR sur images, classification multi-labels

### 4. Base Vectorielle (Qdrant)

Qdrant sert de base de données vectorielle pour le stockage et la recherche efficace des embeddings.

- **Configuration** : Déploiement local sur le VPS OVH
- **Optimisations** : Index pour les métadonnées (type de document, catégorie de schéma)
- **Recherche** : Similarité cosinus avec filtrage sur métadonnées

### 5. LLM (Claude 3 Sonnet)

Claude 3 Sonnet d'Anthropic est utilisé pour la génération de réponses contextuelles et l'analyse des informations.

- **Prompting** : Prompts optimisés pour la documentation technique
- **Contexte** : Utilisation efficace du contexte pour des réponses précises
- **Limitations** : Gestion de la taille du contexte (< 200K tokens)

## Flux de Données

### 1. Ingestion de Documents

```
Upload PDF → n8n → Document Processor → Document AI → Vision AI → Embeddings → Qdrant
```

1. L'utilisateur téléverse un PDF via l'interface web
2. n8n reçoit le fichier et le route en fonction de sa taille
3. Pour les fichiers volumineux, le Document Processor prépare le document
4. Document AI extrait le contenu textuel
5. Vision AI classifie les schémas et images
6. Les textes et images sont convertis en embeddings
7. Les embeddings sont stockés dans Qdrant avec leurs métadonnées

### 2. Traitement des Questions

```
Question → n8n → Embedding → Qdrant (recherche) → Contexte → Claude → Réponse
```

1. L'utilisateur pose une question via l'interface web
2. n8n reçoit la question et la formate
3. La question est convertie en embedding
4. Qdrant effectue une recherche sémantique pour trouver les contenus pertinents
5. Les résultats sont assemblés en contexte
6. Claude génère une réponse basée sur le contexte
7. La réponse est retournée à l'utilisateur avec références aux sources

### 3. Diagnostic Guidé

```
Symptômes initiaux → n8n → Plan de diagnostic → Questions/Réponses → Analyse → Recommandations
```

1. L'utilisateur décrit les symptômes initiaux
2. n8n génère un plan de diagnostic étape par étape
3. À chaque étape, des questions spécifiques sont posées
4. Les réponses sont analysées pour affiner le diagnostic
5. Un rapport final avec recommandations est généré

## Considérations de Performance

- **Mise en cache** : Les embeddings fréquemment utilisés sont mis en cache
- **Traitement par batch** : Les opérations d'embedding sont regroupées
- **Parallélisme** : Traitement simultané de multiples pages de PDF
- **Mise à l'échelle** : Configuration Qdrant optimisée pour la charge de travail attendue

## Sécurité et Robustesse

- **Gestion des credentials** : Stockage sécurisé des clés API dans n8n
- **Validation des entrées** : Vérification approfondie des fichiers avant traitement
- **Limites et quotas** : Surveillance des quotas d'API pour éviter les interruptions
- **Logging** : Traçabilité complète des opérations pour le diagnostic

## Évolutivité Future

L'architecture a été conçue pour faciliter l'évolution vers des fonctionnalités plus avancées :

- **Multimodalité** : Ajout de la recherche d'images par contenu visuel
- **Clustering** : Regroupement automatique de documents similaires
- **Feedback utilisateur** : Apprentissage basé sur les interactions utilisateur
- **Multi-langue** : Support de documentation en plusieurs langues
