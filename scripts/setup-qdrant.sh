#!/bin/bash
# Script d'initialisation et de configuration de Qdrant pour TechnicIA

# Couleurs pour les logs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
COLLECTION_NAME="${1:-technicia}"
VECTOR_SIZE=1024
DEPLOY_DIR="/opt/technicia"
DOCKER_DIR="$DEPLOY_DIR/docker"
TMP_SCRIPT="/tmp/qdrant_init_$$.py"

# Fonction pour afficher les logs
log() {
  echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
  echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERREUR: $1${NC}"
}

warn() {
  echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ATTENTION: $1${NC}"
}

# Vérifier si le conteneur Qdrant est en cours d'exécution
log "Vérification du conteneur Qdrant..."
if ! docker ps | grep -q "technicia-qdrant"; then
    error "Le conteneur Qdrant n'est pas en cours d'exécution. Veuillez démarrer les services avec deploy.sh."
    exit 1
fi

# Vérification de pip et installation des dépendances
log "Vérification des dépendances Python..."
if ! command -v pip3 &> /dev/null; then
    log "Installation de pip..."
    sudo apt-get update
    sudo apt-get install -y python3-pip
fi

log "Installation du client Qdrant..."
pip3 install --quiet qdrant-client

# Création du script Python pour initialiser Qdrant
log "Préparation du script d'initialisation de la collection Qdrant..."

cat > "$TMP_SCRIPT" << EOF
from qdrant_client import QdrantClient
from qdrant_client.http import models
import sys

def initialize_qdrant():
    # Connexion au client Qdrant
    client = QdrantClient(host="localhost", port=6333)
    
    # Vérifier si la collection existe déjà
    try:
        collections = client.get_collections().collections
        collection_names = [c.name for c in collections]
    except Exception as e:
        print(f"Erreur lors de la connexion à Qdrant: {str(e)}")
        sys.exit(1)
    
    # Nom de la collection
    collection_name = "$COLLECTION_NAME"
    
    # Si la collection existe déjà, vérifier ses paramètres
    if collection_name in collection_names:
        print(f"La collection '{collection_name}' existe déjà.")
        
        # Vérifier les index
        try:
            collection_info = client.get_collection(collection_name=collection_name)
            print(f"Vecteurs indexés: {collection_info.vectors_count}")
            
            # Vérifier les payload indexes
            payload_indexes = client.list_collection_aliases(collection_name=collection_name)
            print(f"Payload indexes: {payload_indexes}")
            
            return
        except Exception as e:
            print(f"Erreur lors de la vérification de la collection: {str(e)}")
            sys.exit(1)
    
    # Créer la collection
    try:
        client.create_collection(
            collection_name=collection_name,
            vectors_config=models.VectorParams(
                size=$VECTOR_SIZE,  # Taille des vecteurs
                distance=models.Distance.COSINE
            ),
            optimizers_config=models.OptimizersConfigDiff(
                indexing_threshold=20000
            )
        )
        
        # Créer des index sur les métadonnées importantes
        # Index pour le type (text ou image)
        client.create_payload_index(
            collection_name=collection_name,
            field_name="metadata.type",
            field_schema=models.PayloadSchemaType.KEYWORD
        )
        
        # Index pour le type de schéma (électrique, hydraulique, etc.)
        client.create_payload_index(
            collection_name=collection_name,
            field_name="metadata.schema_type",
            field_schema=models.PayloadSchemaType.KEYWORD
        )
        
        # Index pour le numéro de page
        client.create_payload_index(
            collection_name=collection_name,
            field_name="metadata.page_number",
            field_schema=models.PayloadSchemaType.INTEGER
        )
        
        # Index pour le nom du document
        client.create_payload_index(
            collection_name=collection_name,
            field_name="metadata.document_name",
            field_schema=models.PayloadSchemaType.KEYWORD
        )
        
        print(f"Collection '{collection_name}' créée avec succès!")
        
    except Exception as e:
        print(f"Erreur lors de la création de la collection: {str(e)}")
        sys.exit(1)

if __name__ == "__main__":
    initialize_qdrant()
EOF

# Exécution du script Python
log "Initialisation de la collection Qdrant..."
python3 "$TMP_SCRIPT"

# Vérification du résultat
if [ $? -ne 0 ]; then
    error "Erreur lors de l'initialisation de la collection Qdrant."
    rm -f "$TMP_SCRIPT"
    exit 1
fi

# Test de connexion à l'API Qdrant
log "Test de l'API Qdrant..."
if curl -s "http://localhost:6333/collections" > /dev/null; then
    log "✅ API Qdrant accessible"
else
    warn "⚠️ API Qdrant non accessible"
fi

# Vérification de la collection
if curl -s "http://localhost:6333/collections/$COLLECTION_NAME" > /dev/null; then
    log "✅ Collection $COLLECTION_NAME accessible"
else
    warn "⚠️ Collection $COLLECTION_NAME non accessible"
fi

# Nettoyage
rm -f "$TMP_SCRIPT"

log "Configuration de Qdrant terminée avec succès!"
log "La collection '$COLLECTION_NAME' est prête à être utilisée."
log ""
log "Prochaine étape: Ingérer des documents via l'interface utilisateur ou le workflow n8n d'ingestion."
