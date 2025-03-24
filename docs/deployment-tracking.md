# Suivi de Déploiement TechnicIA MVP

## Instructions d'utilisation

Ce document sert à suivre le processus de déploiement du MVP TechnicIA. Il permet de documenter les étapes, les problèmes rencontrés et les configurations spécifiques à chaque environnement. 

Pour chaque étape de déploiement, indiquez :
- La date de début/fin
- Le statut (Non commencé, En cours, Complété, Bloqué)
- Le responsable
- Les problèmes rencontrés et leur résolution
- Les configurations spécifiques appliquées

## État Global du Déploiement

**Date de dernière mise à jour :** 24 mars 2025  
**État global :** Planifié  
**Environnement en cours :** N/A  
**Prochaine étape :** Déploiement sur environnement de test

## Environnements

| Environnement | Statut | URL | Serveur | Version |
|---------------|--------|-----|---------|---------|
| Test | Non déployé | https://test-technicia.exemple.fr | VPS-TEST-XYZ | - |
| Staging | Non déployé | https://staging-technicia.exemple.fr | VPS-STAGING-XYZ | - |
| Production | Non déployé | https://technicia.exemple.fr | VPS-PROD-XYZ | - |

## Configuration du Serveur OVH

### Informations du Serveur de Production

| Paramètre | Valeur |
|-----------|--------|
| Type de serveur | VPS |
| Modèle | VPS-SSD-4 |
| CPU | 4 vCores |
| RAM | 8 GB |
| Stockage | 160 GB SSD |
| OS | Ubuntu Server 22.04 LTS |
| Localisation | Gravelines (GRA11) |
| IP | À compléter |
| Nom de domaine | À compléter |

### Firewall Configuration

| Port | Service | Commentaire |
|------|---------|-------------|
| 22/tcp | SSH | Accès administrateur |
| 80/tcp | HTTP | Redirection vers HTTPS |
| 443/tcp | HTTPS | Frontend + API |
| 5678/tcp | n8n | Administration des workflows (accès interne uniquement) |
| 6333/tcp | Qdrant API | Base vectorielle (accès interne uniquement) |

## Processus de Déploiement - Environnement de Test

| Étape | Statut | Date début | Date fin | Responsable | Commentaires |
|-------|--------|------------|----------|-------------|--------------|
| **Préparation du serveur** | Non commencé | - | - | - | - |
| - Installation OS | Non commencé | - | - | - | - |
| - Configuration Firewall | Non commencé | - | - | - | - |
| - Installation Docker | Non commencé | - | - | - | - |
| **Déploiement des services** | Non commencé | - | - | - | - |
| - Clonage du repository | Non commencé | - | - | - | - |
| - Configuration des clés API | Non commencé | - | - | - | - |
| - Exécution du script de déploiement | Non commencé | - | - | - | - |
| **Configuration HTTPS** | Non commencé | - | - | - | - |
| - Configuration DNS | Non commencé | - | - | - | - |
| - Installation Certbot | Non commencé | - | - | - | - |
| - Obtention certificats SSL | Non commencé | - | - | - | - |
| **Tests post-déploiement** | Non commencé | - | - | - | - |
| - Tests fonctionnels | Non commencé | - | - | - | - |
| - Tests de performance | Non commencé | - | - | - | - |
| - Tests de sécurité | Non commencé | - | - | - | - |
| **Configuration monitoring** | Non commencé | - | - | - | - |
| - Installation du script de monitoring | Non commencé | - | - | - | - |
| - Configuration des alertes | Non commencé | - | - | - | - |
| - Tests des alertes | Non commencé | - | - | - | - |

## Processus de Déploiement - Environnement de Staging

| Étape | Statut | Date début | Date fin | Responsable | Commentaires |
|-------|--------|------------|----------|-------------|--------------|
| **Préparation du serveur** | Non commencé | - | - | - | - |
| **Déploiement des services** | Non commencé | - | - | - | - |
| **Configuration HTTPS** | Non commencé | - | - | - | - |
| **Tests post-déploiement** | Non commencé | - | - | - | - |
| **Configuration monitoring** | Non commencé | - | - | - | - |

## Processus de Déploiement - Environnement de Production

| Étape | Statut | Date début | Date fin | Responsable | Commentaires |
|-------|--------|------------|----------|-------------|--------------|
| **Préparation du serveur** | Non commencé | - | - | - | - |
| **Déploiement des services** | Non commencé | - | - | - | - |
| **Configuration HTTPS** | Non commencé | - | - | - | - |
| **Tests post-déploiement** | Non commencé | - | - | - | - |
| **Configuration monitoring** | Non commencé | - | - | - | - |

## Configuration des Clés API

| Service | Environnement | Statut | Commentaires |
|---------|---------------|--------|--------------|
| Google Cloud (Document AI) | Test | Non configuré | - |
| Google Cloud (Document AI) | Staging | Non configuré | - |
| Google Cloud (Document AI) | Production | Non configuré | - |
| Google Cloud (Vision AI) | Test | Non configuré | - |
| Google Cloud (Vision AI) | Staging | Non configuré | - |
| Google Cloud (Vision AI) | Production | Non configuré | - |
| VoyageAI | Test | Non configuré | - |
| VoyageAI | Staging | Non configuré | - |
| VoyageAI | Production | Non configuré | - |
| Anthropic (Claude) | Test | Non configuré | - |
| Anthropic (Claude) | Staging | Non configuré | - |
| Anthropic (Claude) | Production | Non configuré | - |

## Problèmes Rencontrés

> Note: Les problèmes détaillés sont suivis dans le fichier `docs/deployment-issues.md`

| ID | Environnement | Description | Statut | Date identification | Date résolution | Solution |
|----|---------------|-------------|--------|---------------------|-----------------|----------|
| - | - | - | - | - | - | - |

## Maintenance et Mises à Jour Planifiées

| Date | Type | Environnement | Description | Responsable | Statut |
|------|------|---------------|-------------|-------------|--------|
| - | - | - | - | - | - |

## Notes et Observations

- Les quotas d'API pour les services cloud doivent être vérifiés et ajustés avant le déploiement en production
- La configuration DNS doit être effectuée au moins 24h avant le déploiement pour permettre la propagation
- Un monitoring des coûts des services cloud doit être mis en place après le déploiement en production
- La documentation utilisateur doit être finalisée avant le déploiement en production
