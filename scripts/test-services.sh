#!/bin/bash

# Script de test des microservices TechnicIA
# Usage: ./test-services.sh [option]
# Options:
#   --all                 Teste tous les services
#   --document-processor  Teste le service Document Processor
#   --schema-analyzer     Teste le service Schema Analyzer
#   --vector-engine       Teste le service Vector Engine
#   --qdrant              Teste la base de données Qdrant
#   -h, --help            Affiche cette aide

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
PROJECT_DIR=$(dirname "$SCRIPT_DIR")
TEST_DIR="$PROJECT_DIR/tests"
TEMP_DIR="/tmp/technicia-test"

# Couleurs pour une meilleure lisibilité
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Créer le répertoire de test si nécessaire
mkdir -p "$TEMP_DIR"

# Afficher l'entête du test
print_header() {
    local service=$1
    echo -e "\n${BLUE}=========================================${NC}"
    echo -e "${BLUE}    Test du service $service ${NC}"
    echo -e "${BLUE}=========================================${NC}\n"
}

# Afficher le résultat du test
print_result() {
    local service=$1
    local status=$2
    local error_msg=$3
    
    if [ "$status" -eq 0 ]; then
        echo -e "\n${GREEN}✅ Test du service $service réussi${NC}\n"
    else
        echo -e "\n${RED}❌ Test du service $service échoué${NC}"
        if [ ! -z "$error_msg" ]; then
            echo -e "${RED}Erreur: $error_msg${NC}\n"
        fi
    fi
}

# Vérifier si un service est en cours d'exécution
check_service_running() {
    local service=$1
    local port=$2
    
    curl -s "http://localhost:$port/health" > /dev/null
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Le service $service n'est pas accessible sur le port $port.${NC}"
        echo -e "${YELLOW}Assurez-vous que les services sont démarrés avec './scripts/start-technicia.sh'${NC}"
        return 1
    fi
    
    return 0
}

# Test du service Document Processor
test_document_processor() {
    print_header "Document Processor"
    
    # Vérifier si le service est en exécution
    check_service_running "Document Processor" 8001
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    # Test de l'endpoint de santé
    echo -e "${YELLOW}Test de l'endpoint de santé...${NC}"
    curl -s "http://localhost:8001/health" | jq
    
    # Création d'un fichier PDF de test simple
    echo -e "\n${YELLOW}Création d'un fichier PDF de test...${NC}"
    if command -v base64 &> /dev/null; then
        # Petit PDF de test (encodé en base64)
        PDF_BASE64="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NS45MiBUbSAoVGhpcyBpcyBhIHRlc3QgUERGIGZvciB0aGUgUHl0aG9uIHNjcmlwdCkgVGogRVQgCmVuZHN0cmVhbSBlbmRvYmoKOSAwIG9iago8PCAvVHlwZSAvRm9udCAvU3VidHlwZSAvVHlwZTAgL0Jhc2VGb250IC9HMnVsUEIrQ2FsaWJyaSAvRW5jb2RpbmcgL0lkZW50aXR5LUgKL0Rlc2NlbmRhbnRGb250cyBbMTUgMCBSXSAvVG9Vbmljb2RlIDE0IDAgUiA+PgplbmRvYmoKMTUgMCBvYmoKPDwgL1R5cGUgL0ZvbnQgL1N1YnR5cGUgL0NJREZvbnRUeXBlMiAvQmFzZUZvbnQgL0cydWxQQitDYWxpYnJpIC9DSURTeXN0ZW1JbmZvCjw8IC9SZWdpc3RyeSAoQWRvYmUpIC9PcmRlcmluZyAoSWRlbnRpdHkpIC9TdXBwbGVtZW50IDAgPj4gL0ZvbnREZXNjcmlwdG9yIDE2IDAgUgogL0NJRFRvR0lETWFwIC9JZGVudGl0eSAvRFcgMTAwMCAvVyBbMCBbNTA3XSA1ICBbMjI5XSAxMiAgWzQ4OF0gNjggIFs4NTRdIDg3IFsyMjldIDkwICBbNTYyXQpwbkwgMjc2IDExMCAgWzU2Ml1dCi9EV2lkdGhNYXAgMTMgMCBSID4+CmVuZG9iagoxNiAwIG9iago8PCAvVHlwZSAvRm9udERlc2NyaXB0b3IgL0ZvbnROYW1lIC9HMnVsUEIrQ2FsaWJyaSAvRmxhZ3MgNCAvRm9udEJCb3ggWy01MDMgLTMxMyAxMjQwIDEwMjZdCi9JdGFsaWNBbmdsZSAwIC9Bc2NlbnQgOTUyIC9EZXNjZW50IC0yNjkgL0NhcEhlaWdodCA2NDQgL1N0ZW1WIDAgL1hIZWlnaHQKNDc2IC9BdmdXaWR0aCA1MjEgL01heFdpZHRoIDEzMjggL0ZvbnRGaWxlMiAoKSA+PgplbmRvYmoKOCAwIG9iago8PCAvVHlwZSAvUGFnZXMgL01lZGlhQm94IFswIDAgNjEyIDc5Ml0gL0NvdW50IDEgL0tpZHMgWyAyIDAgUiBdID4+CmVuZG9iagoxNyAwIG9iago8PCAvVHlwZSAvQ2F0YWxvZyAvUGFnZXMgOCAwIFIgPj4KZW5kb2JqCjE4IDAgb2JqCihUZWNonicSUEApdlRlc3RlcikKZW5kb2JqCjE5IDAgb2JqCihNYWPQtFBERm9ybWF0VGVjaG5pY0lBKQplbmRvYmoKMjAgMCBvYmoKKCkKZW5kb2JqCjE5IDAgb2JqCihNYWPQtFBERm9ybWF0VGVjaG5pY0lBKQplbmRvYmoKMjAgMCBvYmoKKCkKZW5kb2JqCjE5IDAgb2JqCihNYWNpbnRvc2ggSEQpCmVuZG9iagoyMSAwIG9iagooPGQ3NTk2YzEwIGI5YmQzYmJiYTdjMzQ3MmEzNTFhNmRmOTM4NzgxMzI5PikKZW5kb2JqCjE4IDAgb2JqCihUZWNonicSUEApdlRlc3RlcikKZW5kb2JqCjIyIDAgb2JqCihRdWFydHogUERGQ29udGV4dCkKZW5kb2JqCjIzIDAgb2JqCih0ZXN0LnBkZikKZW5kb2JqCjI0IDAgb2JqCihEOjIwMjMwNTEyMTAxMzIxWjAwJzAwJykKZW5kb2JqCjI1IDAgb2JqCigpCmVuZG9iagoyNiAwIG9iagoocXVhcnR6LTIuMSkKZW5kb2JqCjI3IDAgb2JqCihtYWNPUyBWZXJzaW9uIDEyLjYgKEJ1aWxkIDIyRzExNSkgUXVhcnR6IFBERkNvbnRleHQpCmVuZG9iagoyOCAwIG9iagooRDoyMDIzMDYxMDEwMTMyMVpAQCkKZW5kb2JqCjI5IDAgb2JqCigpCmVuZG9iagozMCAwIG9iagpbIDcgMCBSIF0KZW5kb2JqCjEgMCBvYmoKPDwgL1RpdGxlIDE4IDAgUiAvQXV0aG9yIDE5IDAgUiAvU3ViamVjdCAyMCAwIFIgL1Byb2R1Y2VyIDIyIDAgUiAvQ3JlYXRvciA3IDAgUgogL0NyZWF0aW9uRGF0ZSAyOCAwIFIgL01vZERhdGUgMjcgMCBSIC9LZXl3b3JkcyAyNSAwIFIgL0FBUEx0aXRsZSBKVkJFUmkkMCAvQUFQTHN1YmplY3QKMjYgMCBSIC9BUFBMX01ENSBMZU5IICgzNWJmOGM4MzkxNzJkZDAxYjU2NTU1ODRiMTZlZWE2MykgL0FBUExfTUQ1X09yaWdpbmFsIChkNzU5NmMxMCBiOWJkM2JiYmE3YzM0NzJhMzUxYTZkZjkzODc4MTMyOSkKID4+CmVuZG9iagp4cmVmCjAgMzEKMDAwMDAwMDAwMCA2NTUzNSBmIAowMDAwMDA3MzgwIDAwMDAwIG4gCjAwMDAwMDAwNzkgMDAwMDAgbiAKMDAwMDAwNDc1NSAwMDAwMCBuIAowMDAwMDAwMDIyIDAwMDAwIG4gCjAwMDAwMDAwNjAgMDAwMDAgbiAKMDAwMDAwMDE5MSAwMDAwMCBuIAowMDAwMDA0NzM0IDAwMDAwIG4gCjAwMDAwMDY3MDcgMDAwMDAgbiAKMDAwMDAwNTgwNCAwMDAwMCBuIAowMDAwMDAwMjkwIDAwMDAwIG4gCjAwMDAwMDQ3MTMgMDAwMDAgbiAKMDAwMDAwNDgyNSAwMDAwMCBuIAowMDAwMDA0ODc1IDAwMDAwIG4gCjAwMDAwMDQ5ODkgMDAwMDAgbiAKMDAwMDAwNTk1MCAwMDAwMCBuIAowMDAwMDA2NTE0IDAwMDAwIG4gCjAwMDAwMDY3ODMgMDAwMDAgbiAKMDAwMDAwNzIwMSAwMDAwMCBuIAowMDAwMDA3MDk3IDAwMDAwIG4gCjAwMDAwMDY4MzMgMDAwMDAgbiAKMDAwMDAwNzEwMCAwMDAwMCBuIAowMDAwMDA3MjQxIDAwMDAwIG4gCjAwMDAwMDcyNzcgMDAwMDAgbiAKMDAwMDAwNzMwMiAwMDAwMCBuIAowMDAwMDA3MzQ0IDAwMDAwIG4gCjAwMDAwMDczNjMgMDAwMDAgbiAKMDAwMDAwNzQyOSAwMDAwMCBuIAowMDAwMDA3NDk2IDAwMDAwIG4gCjAwMDAwMDcwNjQgMDAwMDAgbiAKMDAwMDAwNzM2MSAwMDAwMCBuIAp0cmFpbGVyCjw8IC9TaXplIDMxIC9Sb290IDEyIDAgUiAvSW5mbyAxIDAgUiAvSUQgWyA8MzViZjhjODM5MTcyZGQwMWI1NjU1NTg0YjE2ZWVhNjM+CjwzNWJmOGM4MzkxNzJkZDAxYjU2NTU1ODRiMTZlZWE2Mz4gXSA+PgpzdGFydHhyZWYKNzcyOAolJUVPRgo="
        echo "$PDF_BASE64" | base64 -d > "$TEMP_DIR/test.pdf"
    else
        echo -e "${YELLOW}Commande base64 non trouvée. Création d'un fichier PDF factice...${NC}"
        echo "Test PDF" > "$TEMP_DIR/test.pdf"
    fi
    
    echo -e "\n${YELLOW}Test avec un fichier par chemin...${NC}"
    curl -s -X POST \
      -H "Content-Type: application/json" \
      -d "{\"documentId\":\"test-doc-$(date +%s)\",\"filePath\":\"$TEMP_DIR/test.pdf\",\"fileName\":\"test.pdf\",\"extractImages\":true,\"extractText\":true}" \
      "http://localhost:8001/api/process" | jq
      
    return $?
}

# Test du service Schema Analyzer
test_schema_analyzer() {
    print_header "Schema Analyzer"
    
    # Vérifier si le service est en exécution
    check_service_running "Schema Analyzer" 8002
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    # Test de l'endpoint de santé
    echo -e "${YELLOW}Test de l'endpoint de santé...${NC}"
    curl -s "http://localhost:8002/health" | jq
    
    # Génération d'une image de test (cercle bleu)
    echo -e "\n${YELLOW}Création d'une image de test...${NC}"
    IMAGE_PATH="$TEMP_DIR/test_circle.png"
    
    # Si convert (ImageMagick) est installé, créer une vraie image
    if command -v convert &> /dev/null; then
        convert -size 200x200 xc:white -fill blue -draw "circle 100,100 50,50" "$IMAGE_PATH"
        echo "Image créée: $IMAGE_PATH"
    else
        # Sinon, créer un fichier factice
        echo "Image de test" > "$IMAGE_PATH"
        echo "Fichier factice créé (ImageMagick non installé)"
    fi
    
    echo -e "\n${YELLOW}Test avec un chemin d'image...${NC}"
    curl -s -X POST \
      -H "Content-Type: application/json" \
      -d "{\"imagePath\":\"$IMAGE_PATH\",\"imageId\":\"test-img-$(date +%s)\",\"documentId\":\"test-doc\"}" \
      "http://localhost:8002/api/analyze-image" | jq
      
    return $?
}

# Test du service Vector Engine
test_vector_engine() {
    print_header "Vector Engine"
    
    # Vérifier si le service est en exécution
    check_service_running "Vector Engine" 8003
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    # Test de l'endpoint de santé
    echo -e "${YELLOW}Test de l'endpoint de santé...${NC}"
    curl -s "http://localhost:8003/health" | jq
    
    # Test de l'indexation d'un texte
    echo -e "\n${YELLOW}Test d'indexation de texte...${NC}"
    DOCUMENT_ID="test-doc-$(date +%s)"
    
    curl -s -X POST \
      -H "Content-Type: application/json" \
      -d "{
        \"documentId\": \"$DOCUMENT_ID\",
        \"textBlocks\": [
          {\"text\": \"Ceci est un texte de test pour TechnicIA\", \"page\": 1},
          {\"text\": \"Le système doit être capable de vectoriser ce texte\", \"page\": 1}
        ],
        \"metadata\": {
          \"fileName\": \"test.pdf\",
          \"pageCount\": 1
        }
      }" \
      "http://localhost:8003/api/process" | jq
    
    # Test de recherche
    echo -e "\n${YELLOW}Test de recherche...${NC}"
    curl -s -X POST \
      -H "Content-Type: application/json" \
      -d "{
        \"query\": \"Que contient ce document de test?\",
        \"documentId\": \"$DOCUMENT_ID\",
        \"limit\": 5
      }" \
      "http://localhost:8003/api/search" | jq
      
    return $?
}

# Test de la base de données Qdrant
test_qdrant() {
    print_header "Qdrant"
    
    # Vérifier si le service est en exécution
    curl -s "http://localhost:6333/health" > /dev/null
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Qdrant n'est pas accessible sur le port 6333.${NC}"
        echo -e "${YELLOW}Assurez-vous que les services sont démarrés avec './scripts/start-technicia.sh'${NC}"
        return 1
    fi
    
    # Test de l'endpoint de santé
    echo -e "${YELLOW}Test de l'endpoint de santé...${NC}"
    curl -s "http://localhost:6333/health" | jq
    
    # Liste des collections
    echo -e "\n${YELLOW}Liste des collections...${NC}"
    curl -s "http://localhost:6333/collections" | jq
    
    # Informations sur la collection
    echo -e "\n${YELLOW}Informations sur la collection 'technicia'...${NC}"
    curl -s "http://localhost:6333/collections/technicia" | jq
    
    return $?
}

# Afficher l'aide
show_help() {
    echo "Usage: $0 [option]"
    echo "Options:"
    echo "  --all                 Teste tous les services"
    echo "  --document-processor  Teste le service Document Processor"
    echo "  --schema-analyzer     Teste le service Schema Analyzer"
    echo "  --vector-engine       Teste le service Vector Engine"
    echo "  --qdrant              Teste la base de données Qdrant"
    echo "  -h, --help            Affiche cette aide"
}

# Vérifier la présence de jq pour le formatage JSON
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}⚠️  La commande 'jq' n'est pas installée. Les résultats JSON ne seront pas formatés correctement.${NC}"
    echo -e "${YELLOW}   Vous pouvez l'installer avec 'apt-get install jq' ou 'brew install jq'${NC}"
    # Créer une fonction jq simplifiée si elle n'existe pas
    jq() {
        cat
    }
fi

# Analyser les arguments
if [ $# -eq 0 ]; then
    show_help
    exit 0
fi

case "$1" in
    --all)
        test_document_processor
        test_schema_analyzer
        test_vector_engine
        test_qdrant
        ;;
    --document-processor)
        test_document_processor
        ;;
    --schema-analyzer)
        test_schema_analyzer
        ;;
    --vector-engine)
        test_vector_engine
        ;;
    --qdrant)
        test_qdrant
        ;;
    -h|--help)
        show_help
        ;;
    *)
        echo -e "${RED}❌ Option non reconnue: $1${NC}"
        show_help
        exit 1
        ;;
esac

exit 0
