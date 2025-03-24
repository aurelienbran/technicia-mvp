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

### 3. Problème avec le Dockerfile du frontend - Absence de package-lock.json

**Date :** 25/03/2025

**Description :** Le Dockerfile du frontend utilise `npm ci` qui nécessite un fichier `package-lock.json`. Ce fichier n'existe pas dans le répertoire frontend, ce qui cause l'échec de la construction.

**Solution :** Modification du Dockerfile pour utiliser `npm install` à la place de `npm ci`, ce qui permet l'installation des dépendances sans nécessiter de fichier `package-lock.json`.

**Notes :** Pour une installation déterministe en production, il est recommandé de générer et versionner un fichier `package-lock.json`. Pour le MVP, `npm install` est suffisant.

### 4. Structure incomplète du frontend - Absence du répertoire public

**Date :** 25/03/2025

**Description :** Le répertoire `public` avec le fichier `index.html` manquait dans le projet frontend, ce qui provoquait l'échec de la construction de l'application React.

**Solution :** Ajout d'un répertoire `public` avec un fichier `index.html` minimal nécessaire à la construction de l'application React.

**Notes :** Pour les futures versions, une vérification de structure complète devrait être effectuée avant de committer un projet React.

### 5. Script de déploiement réinitialisant les modifications locales

**Date :** 25/03/2025

**Description :** Le script `deploy.sh` exécute `git reset --hard origin/main`, ce qui supprime toutes les modifications locales, y compris les correctifs ou configurations personnalisées.

**Solution :** 
1. Création d'un script `apply-patches.sh` qui applique automatiquement les correctifs nécessaires après la mise à jour du code.
2. Modification du script `deploy.sh` pour préserver les fichiers modifiés importants et appeler le script de correctifs.

**Notes :** Cette approche permet de maintenir un équilibre entre l'obtention des dernières mises à jour et la préservation des configurations locales.

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

### 3. Variables d'environnement non chargées correctement

**Date :** 25/03/2025

**Description :** Malgré la présence du fichier `.env`, Docker Compose affiche des avertissements indiquant que les variables d'environnement ne sont pas définies. Cela suggère un problème de chargement des variables d'environnement.

**Investigation en cours :**
- Vérifier le format du fichier `.env` et s'assurer qu'il est correctement situé
- Tester différentes méthodes de chargement des variables d'environnement
- Ajouter des logs supplémentaires pour diagnostiquer le problème de chargement

**Contournement temporaire :** Définir manuellement les variables d'environnement dans le terminal avant d'exécuter Docker Compose.

## Problèmes potentiels à surveiller

### 1. Consommation élevée de mémoire par Qdrant

**Description :** Lors des tests avec de grandes quantités de données, Qdrant peut consommer une quantité importante de mémoire, potentiellement jusqu'à 4 Go.

**Solution préventive :** Configurer la limite de mémoire dans docker-compose.yml et surveiller l'utilisation des ressources. Adapter la configuration de Qdrant (segments, optimiseurs) en fonction de la charge.

### 2. Expiration des tokens d'API Google Cloud

**Description :** Les tokens d'authentification pour Google Cloud ont une durée de validité limitée, ce qui pourrait causer des interruptions de service.

**Solution préventive :** Mettre en place un mécanisme de rafraîchissement automatique des tokens et une surveillance qui alerte lorsque les tokens approchent de leur expiration.