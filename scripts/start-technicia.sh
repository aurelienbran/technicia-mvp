#!/bin/bash

# Script de démarrage pour TechnicIA MVP
# Usage: ./start-technicia.sh [option]
# Options:
#   --build           Construit toutes les images Docker
#   --logs            Affiche les logs en temps réel après le démarrage
#   --clean           Supprime les volumes et redémarre tout proprement
#   --status          Affiche le statut des services
#   --stop            Arrête tous les services
#   --import FILE.pdf Importe un fichier PDF pour test
#   --setup-optimized Configure n8n avec les workflows optimisés
#   --setup-corrected Configure n8n avec les workflows corrigés
#   -h, --help        Affiche cette aide

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
PROJECT_DIR=$(dirname "$SCRIPT_DIR")
COMPOSE_FILE="$PROJECT_DIR/docker-compose.yml"
ENV_FILE="$PROJECT_DIR/.env"
ENV_EXAMPLE="$PROJECT_DIR/.env.example"
WORKFLOWS_DIR="$PROJECT_DIR/workflows"
OPTIMIZED_INGESTION="$WORKFLOWS_DIR/technicia-ingestion-optimized.json"
OPTIMIZED_QUESTION="$WORKFLOWS_DIR/question-optimized.json"
OPTIMIZED_DIAGNOSTIC="$WORKFLOWS_DIR/diagnostic-optimized.json"
CORRECTED_INGESTION="$WORKFLOWS_DIR/technicia-ingestion-corrected.json"
CORRECTED_QUESTION="$WORKFLOWS_DIR/question-corrected.json"
CORRECTED_DIAGNOSTIC="$WORKFLOWS_DIR/diagnostic-corrected.json"

# Vérification des prérequis
check_prerequisites() {
    echo "🔍 Vérification des prérequis..."
    
    if ! command -v docker &> /dev/null; then
        echo "❌ Docker n'est pas installé. Veuillez l'installer avant de continuer."
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        echo "❌ Docker Compose n'est pas installé. Veuillez l'installer avant de continuer."
        exit 1
    fi
    
    echo "✅ Prérequis validés"
}

# Vérification du fichier d'environnement
check_env_file() {
    if [ ! -f "$ENV_FILE" ]; then
        echo "⚠️  Fichier .env non trouvé, création à partir de .env.example..."
        if [ -f "$ENV_EXAMPLE" ]; then
            cp "$ENV_EXAMPLE" "$ENV_FILE"
            echo "✅ Fichier .env créé. Veuillez modifier les valeurs avant de continuer."
            exit 0
        else
            echo "❌ Fichier .env.example non trouvé. Impossible de créer le fichier .env."
            exit 1
        fi
    fi
}

# Démarrage des services
start_services() {
    local build_arg=$1
    echo "🚀 Démarrage des services TechnicIA..."
    
    if [ "$build_arg" = "build" ]; then
        docker-compose -f "$COMPOSE_FILE" up -d --build
    else
        docker-compose -f "$COMPOSE_FILE" up -d
    fi
    
    echo "⏳ Attente du démarrage complet des services..."
    sleep 5
    
    # Vérifier que tous les services sont up
    if docker-compose -f "$COMPOSE_FILE" ps | grep -q "Exit"; then
        echo "❌ Certains services n'ont pas démarré correctement."
        docker-compose -f "$COMPOSE_FILE" ps
        exit 1
    fi
    
    echo "✅ Services TechnicIA démarrés avec succès!"
    echo ""
    echo "ℹ️  Accès aux interfaces:"
    echo "   - n8n: http://localhost:5678"
    echo "   - Qdrant: http://localhost:6333/dashboard"
    echo "   - Frontend: http://localhost:3000"
    echo ""
    echo "🔍 Pour importer un workflow n8n, accédez à http://localhost:5678 et importez les workflows depuis le répertoire /workflows"
}

# Afficher les logs
show_logs() {
    echo "📋 Affichage des logs en temps réel (Ctrl+C pour quitter)..."
    docker-compose -f "$COMPOSE_FILE" logs -f
}

# Nettoyage complet
clean_restart() {
    echo "🧹 Nettoyage complet et redémarrage..."
    
    docker-compose -f "$COMPOSE_FILE" down -v
    echo "✅ Services et volumes supprimés"
    
    start_services "build"
}

# Afficher le statut
show_status() {
    echo "📊 Statut des services TechnicIA:"
    docker-compose -f "$COMPOSE_FILE" ps
}

# Arrêter les services
stop_services() {
    echo "🛑 Arrêt des services TechnicIA..."
    docker-compose -f "$COMPOSE_FILE" down
    echo "✅ Services arrêtés"
}

# Importer un fichier PDF pour test
import_pdf() {
    local pdf_file=$1
    
    if [ ! -f "$pdf_file" ]; then
        echo "❌ Fichier non trouvé: $pdf_file"
        exit 1
    fi
    
    echo "📄 Importation du fichier PDF: $pdf_file"
    
    # Vérifier que les services sont démarrés
    if ! docker-compose -f "$COMPOSE_FILE" ps | grep -q "Up"; then
        echo "❌ Les services ne sont pas démarrés. Veuillez les démarrer avant d'importer un fichier."
        exit 1
    fi
    
    # Obtenir l'URL du webhook n8n
    echo "⏳ Préparation de l'importation..."
    
    # Utiliser curl pour envoyer le fichier
    echo "📤 Envoi du fichier au service d'ingestion..."
    curl -X POST \
        -F "file=@$pdf_file" \
        http://localhost:5678/webhook/upload \
        -v
    
    echo "✅ Requête d'importation envoyée"
    echo "ℹ️  Suivez l'avancement dans les logs du service document-processor"
}

# Configure n8n avec les workflows optimisés
setup_optimized_workflows() {
    echo "🔧 Configuration de n8n avec les workflows optimisés..."
    
    # Vérifier que les services sont démarrés
    if ! docker-compose -f "$COMPOSE_FILE" ps | grep -q "Up"; then
        echo "❌ Les services ne sont pas démarrés. Veuillez les démarrer avant de configurer n8n."
        exit 1
    fi
    
    # Vérifier l'existence des fichiers de workflow optimisés
    if [ ! -f "$OPTIMIZED_INGESTION" ] || [ ! -f "$OPTIMIZED_QUESTION" ] || [ ! -f "$OPTIMIZED_DIAGNOSTIC" ]; then
        echo "❌ Les fichiers de workflow optimisés n'ont pas été trouvés."
        echo "Veuillez vérifier que vous avez bien les fichiers suivants:"
        echo "- $OPTIMIZED_INGESTION"
        echo "- $OPTIMIZED_QUESTION"
        echo "- $OPTIMIZED_DIAGNOSTIC"
        exit 1
    fi
    
    echo "📝 Pour importer les workflows optimisés, suivez ces étapes:"
    echo ""
    echo "1. Accédez à n8n: http://localhost:5678"
    echo "2. Dans la section 'Workflows', cliquez sur 'Import from File'"
    echo "3. Importez les fichiers suivants dans cet ordre:"
    echo "   - technicia-ingestion-optimized.json"
    echo "   - question-optimized.json"
    echo "   - diagnostic-optimized.json"
    echo "4. Activez chaque workflow en cliquant sur le bouton 'Active'"
    echo ""
    echo "ℹ️  Pour plus d'informations, consultez le guide: docs/GUIDE_WORKFLOWS_OPTIMISES.md"
}

# Configure n8n avec les workflows corrigés
setup_corrected_workflows() {
    echo "🔧 Configuration de n8n avec les workflows CORRIGÉS..."
    
    # Vérifier que les services sont démarrés
    if ! docker-compose -f "$COMPOSE_FILE" ps | grep -q "Up"; then
        echo "❌ Les services ne sont pas démarrés. Veuillez les démarrer avant de configurer n8n."
        exit 1
    fi
    
    # Vérifier l'existence des fichiers de workflow corrigés
    if [ ! -f "$CORRECTED_INGESTION" ] || [ ! -f "$CORRECTED_QUESTION" ] || [ ! -f "$CORRECTED_DIAGNOSTIC" ]; then
        echo "❌ Les fichiers de workflow corrigés n'ont pas été trouvés."
        echo "Veuillez vérifier que vous avez bien les fichiers suivants:"
        echo "- $CORRECTED_INGESTION"
        echo "- $CORRECTED_QUESTION"
        echo "- $CORRECTED_DIAGNOSTIC"
        exit 1
    fi
    
    echo "📝 Pour importer les workflows CORRIGÉS, suivez ces étapes:"
    echo ""
    echo "1. Accédez à n8n: http://localhost:5678"
    echo "2. Dans la section 'Workflows', cliquez sur 'Import from File'"
    echo "3. Importez les fichiers suivants dans cet ordre:"
    echo "   - technicia-ingestion-corrected.json"
    echo "   - question-corrected.json"
    echo "   - diagnostic-corrected.json"
    echo "4. Activez chaque workflow en cliquant sur le bouton 'Active'"
    echo ""
    echo "⚠️  N'oubliez pas de configurer l'authentification pour Claude:"
    echo "   Settings > Credentials > Add Credential > HTTP Header Auth"
    echo "   - Name: Claude API Authentication"
    echo "   - Name: x-api-key"
    echo "   - Value: <votre clé API Anthropic>"
    echo ""
    echo "ℹ️  Ces workflows corrigés sont RECOMMANDÉS pour une compatibilité garantie avec les microservices existants."
    echo "ℹ️  Pour plus d'informations, consultez le guide: docs/GUIDE_WORKFLOWS_CORRIGES.md"
}

# Afficher l'aide
show_help() {
    echo "Usage: $0 [option]"
    echo "Options:"
    echo "  --build           Construit toutes les images Docker"
    echo "  --logs            Affiche les logs en temps réel après le démarrage"
    echo "  --clean           Supprime les volumes et redémarre tout proprement"
    echo "  --status          Affiche le statut des services"
    echo "  --stop            Arrête tous les services"
    echo "  --import FILE.pdf Importe un fichier PDF pour test"
    echo "  --setup-optimized Configure n8n avec les workflows optimisés"
    echo "  --setup-corrected Configure n8n avec les workflows CORRIGÉS (recommandé)"
    echo "  -h, --help        Affiche cette aide"
}

# Analyser les arguments
if [ $# -eq 0 ]; then
    check_prerequisites
    check_env_file
    start_services
else
    case "$1" in
        --build)
            check_prerequisites
            check_env_file
            start_services "build"
            ;;
        --logs)
            show_logs
            ;;
        --clean)
            check_prerequisites
            check_env_file
            clean_restart
            ;;
        --status)
            show_status
            ;;
        --stop)
            stop_services
            ;;
        --import)
            if [ -z "$2" ]; then
                echo "❌ Aucun fichier spécifié pour l'importation"
                show_help
                exit 1
            fi
            import_pdf "$2"
            ;;
        --setup-optimized)
            setup_optimized_workflows
            ;;
        --setup-corrected)
            setup_corrected_workflows
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "❌ Option non reconnue: $1"
            show_help
            exit 1
            ;;
    esac
fi

exit 0
