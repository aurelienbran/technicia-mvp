# Suivi de déploiement - TechnicIA MVP

Ce document trace l'historique des déploiements du MVP de TechnicIA et sert de référence pour l'équipe technique.

## Environnement de production

### VPS OVH (Gravelines GRA11)

- **Système :** Ubuntu Server 22.04 LTS
- **Configuration :** 4 vCores, 8 Go RAM, 160 Go SSD
- **Domaine :** technicia.exemple.fr (à configurer)
- **URL d'accès :** https://technicia.exemple.fr (à configurer)
- **URL de l'administration n8n :** https://technicia.exemple.fr:5678 (à configurer)

## État actuel du déploiement

### Phase de préparation (complétée)

- ✅ Configuration du VPS
- ✅ Mise à jour du système
- ✅ Installation des dépendances de base
- ✅ Configuration du pare-feu (UFW)
- ✅ Installation de Docker et Docker Compose
- ✅ Installation de Certbot pour HTTPS

### Phase d'installation (complétée)

- ✅ Clonage du repository
- ✅ Configuration des variables d'environnement
- ✅ Construction des images Docker
- ✅ Démarrage des services Docker
- ✅ Vérification du fonctionnement de base des services

### Phase de configuration (en cours)

- ✅ Configuration de Qdrant
- ✅ Initialisation des collections vectorielles
- ✅ Configuration de n8n
- ✅ Import des workflows n8n
- ⚠️ Configuration des credentials d'API (Google Cloud, Anthropic, VoyageAI)
- ⚠️ Configuration des webhooks

### Phase de déploiement frontend (complétée)

- ✅ Build de l'application React
- ✅ Configuration Nginx comme reverse proxy
- ✅ Mise en place des redirections et règles de routage
- ✅ Configuration des entêtes de sécurité

### Phase de sécurisation (en cours)

- ✅ Obtention des certificats SSL
- ⚠️ Configuration HTTPS pour tous les services exposés
- ⚠️ Mise en place de la rotation des logs
- ⚠️ Configuration des sauvegardes automatiques

### Phase de monitoring (planifiée)

- ⚠️ Installation des outils de monitoring
- ⚠️ Configuration des alertes
- ⚠️ Mise en place du dashboard de supervision

## Historique des déploiements

### 24/03/2025 - Déploiement initial

- Mise en place de l'infrastructure de base
- Installation de Docker et des services essentiels
- Configuration initiale du réseau et du pare-feu
- Tests de fonctionnement basiques effectués avec succès
- Problèmes identifiés: voir [deployment-issues.md](./deployment-issues.md)

### 25/03/2025 - Prévu: Déploiement complet du MVP

- Configuration finale des services
- Mise en place HTTPS
- Tests d'intégration complets
- Finalisation des workflows n8n
- Optimisation des performances

## Instructions pour le déploiement

### Déploiement automatisé (recommandé)

Pour déployer TechnicIA sur un nouvel environnement:

```bash
git clone https://github.com/aurelienbran/technicia-mvp.git
cd technicia-mvp
sudo ./scripts/installer.sh  # Installation des prérequis
./scripts/deploy.sh          # Déploiement des services
```

### Mise à jour depuis le serveur VPS

Pour mettre à jour le code sur votre environnement local depuis le VPS:

```bash
# Si le VPS est configuré comme remote
git fetch vps
git merge vps/main

# Pour ajouter le VPS comme remote si ce n'est pas déjà fait
git remote add vps ssh://user@ip_du_vps/opt/technicia
```

Pour récupérer les derniers commits depuis GitHub sur le VPS:

```bash
ssh user@ip_du_vps "cd /opt/technicia && git fetch origin && git pull origin main"
```

Pour redéployer après une mise à jour:

```bash
ssh user@ip_du_vps "cd /opt/technicia && ./scripts/deploy.sh"
```

## Vérification du déploiement

Pour vérifier que tous les services sont opérationnels:

```bash
ssh user@ip_du_vps "cd /opt/technicia && ./scripts/monitor.sh"
```

## Contacts en cas de problème

- **Responsable technique :** [Nom du responsable technique]
- **Contact d'urgence :** [Contact d'urgence]
