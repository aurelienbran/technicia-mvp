# Architecture TechnicIA - Intégration des services

Ce document résume les modifications apportées à l'architecture de TechnicIA pour optimiser l'intégration des services et garantir un fonctionnement robuste.

## Améliorations apportées

### 1. Intégration de services manquants

Le service `vector-store` était référencé dans les workflows `question.json` et `diagnosis.json`, mais n'était pas inclus dans le docker-compose.yml. Ce service a été ajouté pour assurer la cohérence de l'architecture.

### 2. Création du service claude-service

Un nouveau service `claude-service` a été créé pour centraliser et optimiser les interactions avec l'API Claude d'Anthropic. Ce service propose plusieurs avantages:

- **Gestion centralisée des appels à Claude**
- **Mécanismes robustes de gestion d'erreurs et de retry**
- **Endpoints spécialisés** pour les différents cas d'usage (questions, diagnostic, etc.)
- **Métriques de performance** pour surveiller les temps de réponse
- **Templates de prompts optimisés** dans un service dédié

### 3. Mise à jour des workflows

Les workflows `question.json` et `diagnosis.json` ont été modifiés pour utiliser le nouveau service `claude-service` au lieu d'appeler directement l'API Claude. Ces modifications préservent la fonctionnalité des workflows tout en améliorant leur robustesse.

## Architecture actuelle

L'architecture actuelle compte 6 services Docker:

```
┌───────────────┐      ┌─────────────────┐
│  Frontend     │<────>│  n8n            │
│  (Interface)  │      │  (Orchestration)│
└───────────────┘      └────────┬────────┘
                                │
       ┌──────────────┬─────────┼─────────┬─────────────┬─────────────┐
       │              │         │         │             │             │
┌──────▼─────┐ ┌──────▼─────┐ ┌─▼───────┐ ┌───────────┐ ┌───────────┐
│ Document   │ │ Schema     │ │ Vector  │ │ Qdrant    │ │ Claude    │
│ Processor  │ │ Analyzer   │ │ Engine  │ │(Vector DB)│ │ Service   │
└────────────┘ └────────────┘ └─────────┘ └───────────┘ └───────────┘
                                     │
                                     ▼
                              ┌─────────────┐
                              │ Vector      │
                              │ Store       │
                              └─────────────┘
```

- **Document Processor**: Traitement des PDF et extraction du contenu
- **Schema Analyzer**: Classification des images techniques via Vision AI
- **Vector Engine**: Gestion des embeddings et indexation
- **Vector Store**: Recherche vectorielle dans Qdrant
- **Qdrant**: Base de données vectorielle
- **Claude Service**: Service d'interaction avec l'API Claude
- **n8n**: Orchestrateur des workflows

## Workflow des données

1. **Upload d'un document**:
   - Le document est reçu par n8n et transmis au Document Processor
   - Les images sont analysées par Schema Analyzer
   - Le contenu est vectorisé par Vector Engine et stocké dans Qdrant

2. **Question utilisateur**:
   - n8n reçoit la question via webhook
   - Vector Store effectue la recherche vectorielle dans Qdrant
   - Claude Service génère une réponse basée sur le contexte trouvé

3. **Diagnostic guidé**:
   - n8n orchestre le processus de diagnostic
   - Vector Store effectue la recherche de contexte initial
   - Claude Service génère le plan de diagnostic
   - Les étapes sont présentées une par une à l'utilisateur
   - Claude Service génère le rapport final

## Recommandations supplémentaires

### 1. Gestion de la transition

Les services `vector-engine` et `vector-store` semblent avoir des fonctionnalités qui se chevauchent. Une stratégie possible serait:

- Maintenir les deux services pour le moment
- Documenter leurs différences et cas d'usage
- À terme, envisager de consolider ces fonctionnalités dans un seul service

### 2. Optimisations futures

- **Ajouter un cache** au Claude Service pour éviter des appels répétés identiques
- **Implémenter un mécanisme de persistance** pour les états de diagnostic
- **Ajouter des logs structurés** pour faciliter le monitoring
- **Configurer des health checks plus avancés** pour chaque service

### 3. Tests et validation

Avant le déploiement en production, effectuez des tests complets:

- Tests fonctionnels des workflows end-to-end
- Tests de robustesse (erreurs réseau, indisponibilité temporaire des services)
- Tests de performance avec des volumes importants de données
