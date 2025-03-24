# Problèmes de déploiement - TechnicIA MVP

Ce document répertorie les problèmes rencontrés lors du déploiement de TechnicIA MVP, ainsi que leurs solutions ou contournements.

## Problèmes résolus

### 1. Fichiers manquants suite au commit d8619ad

**Date :** 24/03/2025

**Description :** Le commit d8619ad, censé corriger l'erreur de clonage du repository et mettre à jour l'installation de Docker, a accidentellement effacé plusieurs scripts importants:
- `scripts/installer.sh`
- `scripts/setup-qdrant.sh`
- `scripts/setup-n8n.sh`

**Solution :** Les fichiers ont été restaurés par trois commits successifs:
- Commit 527ab4aa4fcf4bcc3b3e5912bf9ee01797d1da8e: Restauration de installer.sh
- Commit 9a71c67d2a198761f5f0ca15e2663c15f3d375a1: Restauration de setup-qdrant.sh
- Commit 724f3b1ed72f67d0af6658347836ac29a444b9c0: Restauration de setup-n8n.sh

**Notes :** À l'avenir, il est recommandé d'utiliser `git add <fichier>` pour ajouter spécifiquement les fichiers modifiés, plutôt que `git add .` qui peut entraîner l'inclusion accidentelle de suppressions non intentionnelles.

### 2. Erreur de syntaxe dans le script deploy.sh

**Date :** 24/03/2025

**Description :** Une erreur de syntaxe a été détectée à la ligne 48 du script deploy.sh, probablement liée à une structure conditionnelle mal formée.

**Solution :** Le script a été vérifié et corrigé dans le commit e885fa450012d20294596685483cb4f5a3b52395.

**Notes :** Il est recommandé d'utiliser des outils comme ShellCheck pour valider la syntaxe des scripts bash avant de les committer.

## Problèmes en cours

### 1. Erreur CORS lors des appels API depuis le frontend

**Date :** 24/03/2025

**Description :** Lors des tests d'intégration, des erreurs CORS (Cross-Origin Resource Sharing) ont été détectées lorsque le frontend essaie de communiquer avec les services backend.

**Investigation en cours :** 
- Vérifier la configuration CORS dans les microservices FastAPI
- S'assurer que tous les services sont sur le même réseau Docker
- Configurer correctement les en-têtes dans le service de proxy (Nginx)

**Contournement temporaire :** Pour les tests de développement, un plugin CORS a été installé dans le navigateur pour ignorer ces erreurs.

### 2. Problème de performance avec les documents volumineux

**Date :** 24/03/2025

**Description :** Les documents PDF dépassant 50 Mo prennent beaucoup de temps à être traités, et le service document-processor peut parfois se bloquer.

**Investigation en cours :**
- Optimiser le processus d'extraction pour gérer les documents par lots
- Implémenter un mécanisme de file d'attente pour éviter la surcharge
- Explorer la possibilité de paralléliser le traitement des pages

**Contournement temporaire :** Limiter la taille des documents à 30 Mo pour les démonstrations, et prétraiter les documents plus volumineux manuellement.

## Problèmes potentiels à surveiller

### 1. Consommation élevée de mémoire par Qdrant

**Description :** Lors des tests avec de grandes quantités de données, Qdrant peut consommer une quantité importante de mémoire, potentiellement jusqu'à 4 Go.

**Solution préventive :** Configurer la limite de mémoire dans docker-compose.yml et surveiller l'utilisation des ressources. Adapter la configuration de Qdrant (segments, optimiseurs) en fonction de la charge.

### 2. Expiration des tokens d'API Google Cloud

**Description :** Les tokens d'authentification pour Google Cloud ont une durée de validité limitée, ce qui pourrait causer des interruptions de service.

**Solution préventive :** Mettre en place un mécanisme de rafraîchissement automatique des tokens et une surveillance qui alerte lorsque les tokens approchent de leur expiration.
