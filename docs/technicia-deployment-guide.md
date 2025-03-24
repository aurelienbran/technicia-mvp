# Guide Complet de Déploiement de TechnicIA MVP

Ce guide détaille les étapes nécessaires pour installer et déployer le MVP de TechnicIA sur un serveur VPS (Virtual Private Server).

## Table des matières

1. [Introduction](#introduction)
2. [Prérequis](#prérequis)
3. [Préparation du serveur](#préparation-du-serveur)
4. [Clonage du repository](#clonage-du-repository)
5. [Configuration](#configuration)
6. [Déploiement](#déploiement)
   - [Méthode automatisée (recommandée)](#méthode-automatisée-recommandée)
   - [Méthode manuelle](#méthode-manuelle)
7. [Configuration de n8n](#configuration-de-n8n)
8. [Configuration de Qdrant](#configuration-de-qdrant)
9. [Configuration HTTPS](#configuration-https)
10. [Vérification](#vérification)
11. [Monitoring](#monitoring)
12. [Sauvegarde et restauration](#sauvegarde-et-restauration)
13. [Dépannage](#dépannage)
14. [Mise à jour](#mise-à-jour)

## Introduction

TechnicIA est un assistant intelligent de maintenance technique qui aide les techniciens à accéder rapidement à l'information pertinente et à diagnostiquer efficacement les problèmes sur les équipements industriels. Ce guide détaille l'ensemble du processus de déploiement et de configuration sur un serveur VPS.

## Prérequis

- Un VPS sous Ubuntu Server 22.04 LTS avec au moins :
  - 8 Go de RAM
  - 4 vCPUs
  - 100 Go d'espace disque SSD
- Accès SSH au serveur avec privilèges sudo
- Un nom de domaine (recommandé)
- Accès aux services suivants :
  - Google Cloud Platform (Document AI et Vision AI)
  - Anthropic API (Claude 3.5 Sonnet)
  - VoyageAI API (pour les embeddings)

## Préparation du serveur

### Mise à jour du système

```bash
# Mettre à jour les paquets
sudo apt update
sudo apt upgrade -y

# Installer les dépendances de base
sudo apt install -y git curl wget ca-certificates gnupg lsb-release
```

### Installation de Docker et Docker Compose

Utilisez la méthode recommandée pour installer Docker et éviter les avertissements de dépréciation:

```bash
# Désinstaller les anciens packages Docker si nécessaire
sudo apt-get remove docker docker-engine docker.io containerd runc

# Installer les packages requis
sudo apt-get install -y ca-certificates curl gnupg

# Créer le répertoire pour les clés
sudo install -m 0755 -d /etc/apt/keyrings

# Télécharger et installer la clé GPG de Docker
curl -fsSL https://download.docker.com/