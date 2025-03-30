#!/bin/bash

# Script de migration automatisée pour TechnicIA v1 vers v2
# Usage: ./migrate-technicia.sh [option]
# Options:
#   --minimal     Migration minimale (seulement le Document Processor et le workflow)
#   --complete    Migration complète (renommage des services et mise à jour des APIs)
#   --check       Vérification de la compatibilité sans effectuer de modification
#   --rollback    Annuler les modifications et revenir à l'état précédent
#   -h, --help    Affiche cette aide

set -e  # Le script s'arrête en cas d'erreur

# Couleurs pour une meilleure lisibilité
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Répertoires
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
PROJECT_DIR=$(dirname "$SCRIPT_DIR")
BACKUP_DIR="$PROJECT_DIR/backups/$(date +%Y%m%d_%H%M%S)"
SERVICES_DIR="$PROJECT_DIR/services"
WORKFLOWS_DIR="$PROJECT_DIR/workflows"
OLD_WORKFLOW="technicia-ingestion-pure-microservices.json"
NEW_WORKFLOW="technicia-ingestion-pure-microservices-fixed.json"

# Détection de l'état actuel
detect_current_state() {
    echo -e "${BLUE}=== Détection de l'état actuel de l'installation ===${NC}"
    
    # Vérifier si docker-compose est en cours d'exécution
    if docker ps | grep -q "document-processor"; then
        echo -e "${YELLOW}Services TechnicIA en cours d'exécution.${NC}"
        SERVICES_RUNNING=true
    else
        echo -e "${YELLOW}Services TechnicIA arrêtés.${NC}"
        SERVICES_RUNNING=false
    fi
    
    # Vérifier si les services existent
    HAS_DOCUMENT_PROCESSOR=false
    HAS_VISION_CLASSIFIER=false
    HAS_VECTOR_STORE=false
    HAS_SCHEMA_ANALYZER=false
    HAS_VECTOR_ENGINE=false
    
    if [ -d "$SERVICES_DIR/document-processor" ]; then
        HAS_DOCUMENT_PROCESSOR=true
        echo -e "${GREEN}✓ Document Processor trouvé${NC}"
    fi
    
    if [ -d "$SERVICES_DIR/vision-classifier" ]; then
        HAS_VISION_CLASSIFIER=true
        echo -e "${GREEN}✓ Vision Classifier trouvé (ancien)${NC}"
    fi
    
    if [ -d "$SERVICES_DIR/vector-store" ]; then
        HAS_VECTOR_STORE=true
        echo -e "${GREEN}✓ Vector Store trouvé (ancien)${NC}"
    fi
    
    if [ -d "$SERVICES_DIR/schema-analyzer" ]; then
        HAS_SCHEMA_ANALYZER=true
        echo -e "${GREEN}✓ Schema Analyzer trouvé (nouveau)${NC}"
    fi
    
    if [ -d "$SERVICES_DIR/vector-engine" ]; then
        HAS_VECTOR_ENGINE=true
        echo -e "${GREEN}✓ Vector Engine trouvé (nouveau)${NC}"
    fi
    
    # Vérifier les workflows n8n
    if [ -f "$WORKFLOWS_DIR/$OLD_WORKFLOW" ]; then
        echo -e "${GREEN}✓ Ancien workflow d'ingestion trouvé${NC}"
    fi
    
    if [ -f "$WORKFLOWS_DIR/$NEW_WORKFLOW" ]; then
        echo -e "${GREEN}✓ Nouveau workflow d'ingestion trouvé${NC}"
    fi
}

# Créer une sauvegarde avant migration
create_backup() {
    echo -e "${BLUE}=== Création d'une sauvegarde avant migration ===${NC}"
    
    # Créer le répertoire de sauvegarde
    mkdir -p "$BACKUP_DIR/services"
    mkdir -p "$BACKUP_DIR/workflows"
    
    # Sauvegarder docker-compose.yml
    if [ -f "$PROJECT_DIR/docker-compose.yml" ]; then
        echo -e "${YELLOW}Sauvegarde du fichier docker-compose.yml...${NC}"
        cp "$PROJECT_DIR/docker-compose.yml" "$BACKUP_DIR/docker-compose.yml"
    fi
    
    # Sauvegarder les services
    if [ "$HAS_DOCUMENT_PROCESSOR" = true ]; then
        echo -e "${YELLOW}Sauvegarde du service Document Processor...${NC}"
        cp -r "$SERVICES_DIR/document-processor" "$BACKUP_DIR/services/"
    fi
    
    if [ "$HAS_VISION_CLASSIFIER" = true ]; then
        echo -e "${YELLOW}Sauvegarde du service Vision Classifier...${NC}"
        cp -r "$SERVICES_DIR/vision-classifier" "$BACKUP_DIR/services/"
    fi
    
    if [ "$HAS_VECTOR_STORE" = true ]; then
        echo -e "${YELLOW}Sauvegarde du service Vector Store...${NC}"
        cp -r "$SERVICES_DIR/vector-store" "$BACKUP_DIR/services/"
    fi
    
    if [ "$HAS_SCHEMA_ANALYZER" = true ]; then
        echo -e "${YELLOW}Sauvegarde du service Schema Analyzer...${NC}"
        cp -r "$SERVICES_DIR/schema-analyzer" "$BACKUP_DIR/services/"
    fi
    
    if [ "$HAS_VECTOR_ENGINE" = true ]; then
        echo -e "${YELLOW}Sauvegarde du service Vector Engine...${NC}"
        cp -r "$SERVICES_DIR/vector-engine" "$BACKUP_DIR/services/"
    fi
    
    # Sauvegarder les workflows
    echo -e "${YELLOW}Sauvegarde des workflows...${NC}"
    cp -r "$WORKFLOWS_DIR"/* "$BACKUP_DIR/workflows/"
    
    echo -e "${GREEN}✓ Sauvegarde complète créée dans : $BACKUP_DIR${NC}"
    echo -e "${YELLOW}Pour restaurer cette sauvegarde en cas de problème, utilisez:${NC}"
    echo -e "${YELLOW}  $0 --rollback $BACKUP_DIR${NC}"
}

# Migration minimale (Document Processor uniquement)
minimal_migration() {
    echo -e "${BLUE}=== Début de la migration minimale ===${NC}"
    
    # Mettre à jour Document Processor uniquement
    if [ "$HAS_DOCUMENT_PROCESSOR" = true ]; then
        echo -e "${YELLOW}Mise à jour du service Document Processor...${NC}"
        
        # Vérifier si les services sont en cours d'exécution
        if [ "$SERVICES_RUNNING" = true ]; then
            echo -e "${YELLOW}Arrêt temporaire du service Document Processor...${NC}"
            docker-compose -f "$PROJECT_DIR/docker-compose.yml" stop document-processor
        fi
        
        # Créer le nouveau fichier main.py
        cp "$PROJECT_DIR/services/document-processor/main.py" "$PROJECT_DIR/services/document-processor/main.py.bak"
        cp "$PROJECT_DIR/backups/latest/services/document-processor/main.py" "$PROJECT_DIR/services/document-processor/main.py"
        
        # Redémarrer le service si nécessaire
        if [ "$SERVICES_RUNNING" = true ]; then
            echo -e "${YELLOW}Redémarrage du service Document Processor...${NC}"
            docker-compose -f "$PROJECT_DIR/docker-compose.yml" up -d --build document-processor
        fi
        
        echo -e "${GREEN}✓ Service Document Processor mis à jour${NC}"
    else
        echo -e "${RED}✗ Service Document Processor non trouvé${NC}"
    fi
    
    echo -e "${YELLOW}Pour finaliser la migration minimale:${NC}"
    echo -e "${YELLOW}1. Connectez-vous à n8n (http://localhost:5678)${NC}"
    echo -e "${YELLOW}2. Importez le workflow: $WORKFLOWS_DIR/$NEW_WORKFLOW${NC}"
    echo -e "${YELLOW}3. Activez le nouveau workflow et désactivez l'ancien${NC}"
    
    echo -e "${GREEN}Migration minimale terminée avec succès !${NC}"
}

# Migration complète (tous les services)
complete_migration() {
    echo -e "${BLUE}=== Début de la migration complète ===${NC}"
    
    # Arrêter tous les services
    if [ "$SERVICES_RUNNING" = true ]; then
        echo -e "${YELLOW}Arrêt de tous les services...${NC}"
        docker-compose -f "$PROJECT_DIR/docker-compose.yml" down
    fi
    
    # 1. Mise à jour de Document Processor (comme dans la migration minimale)
    if [ "$HAS_DOCUMENT_PROCESSOR" = true ]; then
        echo -e "${YELLOW}Mise à jour du service Document Processor...${NC}"
        cp "$PROJECT_DIR/services/document-processor/main.py" "$PROJECT_DIR/services/document-processor/main.py.bak"
        cp "$PROJECT_DIR/backups/latest/services/document-processor/main.py" "$PROJECT_DIR/services/document-processor/main.py"
        echo -e "${GREEN}✓ Service Document Processor mis à jour${NC}"
    else
        echo -e "${RED}✗ Service Document Processor non trouvé${NC}"
    fi
    
    # 2. Création/Mise à jour de Schema Analyzer
    if [ "$HAS_SCHEMA_ANALYZER" = false ]; then
        echo -e "${YELLOW}Création du nouveau service Schema Analyzer...${NC}"
        
        # Si vision-classifier existe, le copier comme base
        if [ "$HAS_VISION_CLASSIFIER" = true ]; then
            mkdir -p "$SERVICES_DIR/schema-analyzer"
            cp -r "$SERVICES_DIR/vision-classifier"/* "$SERVICES_DIR/schema-analyzer/"
        else
            # Sinon, créer à partir de la sauvegarde
            mkdir -p "$SERVICES_DIR/schema-analyzer"
            cp -r "$PROJECT_DIR/backups/latest/services/schema-analyzer"/* "$SERVICES_DIR/schema-analyzer/"
        fi
        
        # Mettre à jour le main.py et Dockerfile
        cp "$PROJECT_DIR/backups/latest/services/schema-analyzer/main.py" "$SERVICES_DIR/schema-analyzer/main.py"
        cp "$PROJECT_DIR/backups/latest/services/schema-analyzer/Dockerfile" "$SERVICES_DIR/schema-analyzer/Dockerfile"
        
        # Créer requirements.txt s'il n'existe pas
        if [ ! -f "$SERVICES_DIR/schema-analyzer/requirements.txt" ]; then
            cp "$PROJECT_DIR/backups/latest/services/schema-analyzer/requirements.txt" "$SERVICES_DIR/schema-analyzer/requirements.txt"
        fi
        
        echo -e "${GREEN}✓ Service Schema Analyzer créé${NC}"
    else
        echo -e "${YELLOW}Le service Schema Analyzer existe déjà.${NC}"
    fi
    
    # 3. Création/Mise à jour de Vector Engine
    if [ "$HAS_VECTOR_ENGINE" = false ]; then
        echo -e "${YELLOW}Création du nouveau service Vector Engine...${NC}"
        
        # Si vector-store existe, le copier comme base
        if [ "$HAS_VECTOR_STORE" = true ]; then
            mkdir -p "$SERVICES_DIR/vector-engine"
            cp -r "$SERVICES_DIR/vector-store"/* "$SERVICES_DIR/vector-engine/"
        else
            # Sinon, créer à partir de la sauvegarde
            mkdir -p "$SERVICES_DIR/vector-engine"
            cp -r "$PROJECT_DIR/backups/latest/services/vector-engine"/* "$SERVICES_DIR/vector-engine/"
        fi
        
        # Mettre à jour le main.py et Dockerfile
        cp "$PROJECT_DIR/backups/latest/services/vector-engine/main.py" "$SERVICES_DIR/vector-engine/main.py"
        cp "$PROJECT_DIR/backups/latest/services/vector-engine/Dockerfile" "$SERVICES_DIR/vector-engine/Dockerfile"
        
        # Créer requirements.txt s'il n'existe pas
        if [ ! -f "$SERVICES_DIR/vector-engine/requirements.txt" ]; then
            cp "$PROJECT_DIR/backups/latest/services/vector-engine/requirements.txt" "$SERVICES_DIR/vector-engine/requirements.txt"
        fi
        
        echo -e "${GREEN}✓ Service Vector Engine créé${NC}"
    else
        echo -e "${YELLOW}Le service Vector Engine existe déjà.${NC}"
    fi
    
    # 4. Mise à jour du docker-compose.yml
    echo -e "${YELLOW}Mise à jour du fichier docker-compose.yml...${NC}"
    cp "$PROJECT_DIR/docker-compose.yml" "$PROJECT_DIR/docker-compose.yml.bak"
    cp "$PROJECT_DIR/backups/latest/docker-compose.yml" "$PROJECT_DIR/docker-compose.yml"
    
    # 5. Redémarrer les services avec la nouvelle configuration
    echo -e "${YELLOW}Démarrage des services avec la nouvelle configuration...${NC}"
    docker-compose -f "$PROJECT_DIR/docker-compose.yml" up -d
    
    echo -e "${YELLOW}Pour finaliser la migration complète:${NC}"
    echo -e "${YELLOW}1. Connectez-vous à n8n (http://localhost:5678)${NC}"
    echo -e "${YELLOW}2. Importez le workflow: $WORKFLOWS_DIR/$NEW_WORKFLOW${NC}"
    echo -e "${YELLOW}3. Activez le nouveau workflow et désactivez l'ancien${NC}"
    
    echo -e "${GREEN}Migration complète terminée avec succès !${NC}"
}

# Vérification sans modification
check_compatibility() {
    echo -e "${BLUE}=== Vérification de la compatibilité ===${NC}"
    
    # Vérifier la structure des dossiers
    DIR_STRUCTURE_OK=true
    
    if [ ! -d "$SERVICES_DIR/document-processor" ]; then
        echo -e "${RED}✗ Document Processor non trouvé (requis)${NC}"
        DIR_STRUCTURE_OK=false
    fi
    
    # Vérifier si docker et docker-compose sont installés
    DOCKER_OK=true
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}✗ Docker n'est pas installé${NC}"
        DOCKER_OK=false
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        echo -e "${RED}✗ Docker Compose n'est pas installé${NC}"
        DOCKER_OK=false
    fi
    
    # Vérifier l'accès à Internet pour télécharger des images
    NETWORK_OK=true
    if ! ping -c 1 google.com &> /dev/null; then
        echo -e "${YELLOW}⚠ Connexion Internet non vérifiable${NC}"
        NETWORK_OK=false
    fi
    
    # Vérifier l'espace disque disponible
    DISK_SPACE=$(df -h "$PROJECT_DIR" | awk 'NR==2 {print $4}')
    echo -e "${YELLOW}Espace disque disponible: $DISK_SPACE${NC}"
    
    # Résultat global
    if [ "$DIR_STRUCTURE_OK" = true ] && [ "$DOCKER_OK" = true ]; then
        echo -e "${GREEN}✓ Système compatible pour la migration${NC}"
        echo -e "${YELLOW}Vous pouvez procéder à la migration avec:${NC}"
        echo -e "${YELLOW}  $0 --minimal${NC}"
        echo -e "${YELLOW}ou${NC}"
        echo -e "${YELLOW}  $0 --complete${NC}"
    else
        echo -e "${RED}✗ Des problèmes ont été détectés, veuillez les résoudre avant de migrer${NC}"
    fi
}

# Rollback à partir d'une sauvegarde
rollback_migration() {
    ROLLBACK_DIR=$1
    
    if [ -z "$ROLLBACK_DIR" ]; then
        # Trouver la dernière sauvegarde
        ROLLBACK_DIR=$(ls -td "$PROJECT_DIR/backups/"* | head -1)
    fi
    
    if [ ! -d "$ROLLBACK_DIR" ]; then
        echo -e "${RED}✗ Répertoire de sauvegarde non trouvé: $ROLLBACK_DIR${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}=== Restauration à partir de: $ROLLBACK_DIR ===${NC}"
    
    # Arrêter tous les services
    echo -e "${YELLOW}Arrêt de tous les services...${NC}"
    docker-compose -f "$PROJECT_DIR/docker-compose.yml" down
    
    # Restaurer docker-compose.yml
    if [ -f "$ROLLBACK_DIR/docker-compose.yml" ]; then
        echo -e "${YELLOW}Restauration du fichier docker-compose.yml...${NC}"
        cp "$ROLLBACK_DIR/docker-compose.yml" "$PROJECT_DIR/docker-compose.yml"
    fi
    
    # Restaurer les services
    for service in document-processor vision-classifier vector-store schema-analyzer vector-engine; do
        if [ -d "$ROLLBACK_DIR/services/$service" ]; then
            echo -e "${YELLOW}Restauration du service $service...${NC}"
            rm -rf "$SERVICES_DIR/$service"
            cp -r "$ROLLBACK_DIR/services/$service" "$SERVICES_DIR/"
        fi
    done
    
    # Redémarrer les services
    echo -e "${YELLOW}Redémarrage des services...${NC}"
    docker-compose -f "$PROJECT_DIR/docker-compose.yml" up -d
    
    echo -e "${GREEN}Restauration terminée avec succès !${NC}"
}

# Créer un lien symbolique vers la dernière sauvegarde
update_latest_link() {
    rm -f "$PROJECT_DIR/backups/latest"
    ln -sf "$BACKUP_DIR" "$PROJECT_DIR/backups/latest"
}

# Montrer l'aide
show_help() {
    echo "Script de migration automatisée pour TechnicIA v1 vers v2"
    echo "Usage: $0 [option]"
    echo "Options:"
    echo "  --minimal     Migration minimale (seulement le Document Processor et le workflow)"
    echo "  --complete    Migration complète (renommage des services et mise à jour des APIs)"
    echo "  --check       Vérification de la compatibilité sans effectuer de modification"
    echo "  --rollback    Annuler les modifications et revenir à l'état précédent"
    echo "  -h, --help    Affiche cette aide"
}

# Vérifier que le script s'exécute depuis le bon endroit
if [ ! -d "$SERVICES_DIR" ] || [ ! -d "$WORKFLOWS_DIR" ]; then
    echo -e "${RED}Erreur: Le script doit être exécuté depuis le répertoire du projet TechnicIA${NC}"
    echo -e "${RED}Exemple: ./scripts/migrate-technicia.sh --check${NC}"
    exit 1
fi

# Créer le répertoire de sauvegarde s'il n'existe pas
mkdir -p "$PROJECT_DIR/backups"

# Analyse des arguments
if [ $# -eq 0 ]; then
    show_help
    exit 0
fi

# Détection de l'état actuel
detect_current_state

case "$1" in
    --minimal)
        create_backup
        update_latest_link
        minimal_migration
        ;;
    --complete)
        create_backup
        update_latest_link
        complete_migration
        ;;
    --check)
        check_compatibility
        ;;
    --rollback)
        rollback_migration "$2"
        ;;
    -h|--help)
        show_help
        ;;
    *)
        echo -e "${RED}Option non reconnue: $1${NC}"
        show_help
        exit 1
        ;;
esac

exit 0
