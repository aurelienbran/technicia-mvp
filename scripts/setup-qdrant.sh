#!/bin/bash
# Script pour initialiser et configurer Qdrant pour TechnicIA

# Couleurs pour les logs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
QDRANT_HOST="localhost"
QDRANT_PORT="6333"
COLLECTION_NAME="technicia"
VECTOR_SIZE=1536  # Taille du vecteur pour Voyage AI

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

# Attendre que Qdrant soit disponible
wait_for_qdrant() {
  log "Attente du démarrage de Qdrant..."
  for i in {1..30}; do
    if curl -s "http://${QDRANT_HOST}:${QDRANT_PORT}/collections" &> /dev/null; then
      log "Qdrant est disponible"
      return 0
    fi
    echo -n "."
    sleep 2
  done
  
  error "Timeout en attendant que Qdrant démarre"
  return 1
}

# Créer une collection Qdrant
create_collection() {
  log "Création de la collection '${COLLECTION_NAME}'..."
  
  # Vérifier si la collection existe déjà
  COLLECTIONS=$(curl -s "http://${QDRANT_HOST}:${QDRANT_PORT}/collections")
  if echo "$COLLECTIONS" | grep -q "\"name\":\"${COLLECTION_NAME}\""; then
    warn "La collection '${COLLECTION_NAME}' existe déjà"
    return 0
  fi
  
  # Créer la collection avec la configuration appropriée
  RESPONSE=$(curl -s -X PUT "http://${QDRANT_HOST}:${QDRANT_PORT}/collections/${COLLECTION_NAME}" \
    -H 'Content-Type: application/json' \
    -d '{
      "vectors": {
        "size": '${VECTOR_SIZE}',
        "distance": "Cosine"
      },
      "optimizers_config": {
        "default_segment_number": 2
      },
      "replication_factor": 1,
      "write_consistency_factor": 1
    }')
  
  if echo "$RESPONSE" | grep -q "\"status\":\"ok\""; then
    log "Collection '${COLLECTION_NAME}' créée avec succès"
  else
    error "Échec de la création de la collection: $RESPONSE"
    return 1
  fi
}

# Créer les index pour optimiser les recherches
create_indexes() {
  log "Création des index sur les champs de métadonnées..."
  
  # Créer un index sur le champ type
  RESPONSE=$(curl -s -X PUT "http://${QDRANT_HOST}:${QDRANT_PORT}/collections/${COLLECTION_NAME}/index" \
    -H 'Content-Type: application/json' \
    -d '{
      "field_name": "type",
      "field_schema": "keyword"
    }')
  
  if echo "$RESPONSE" | grep -q "\"status\":\"ok\""; then
    log "Index sur 'type' créé avec succès"
  else
    warn "Échec de la création de l'index sur 'type': $RESPONSE"
  fi
  
  # Créer un index sur le champ document_id
  RESPONSE=$(curl -s -X PUT "http://${QDRANT_HOST}:${QDRANT_PORT}/collections/${COLLECTION_NAME}/index" \
    -H 'Content-Type: application/json' \
    -d '{
      "field_name": "document_id",
      "field_schema": "keyword"
    }')
  
  if echo "$RESPONSE" | grep -q "\"status\":\"ok\""; then
    log "Index sur 'document_id' créé avec succès"
  else
    warn "Échec de la création de l'index sur 'document_id': $RESPONSE"
  fi
  
  # Créer un index sur le champ section
  RESPONSE=$(curl -s -X PUT "http://${QDRANT_HOST}:${QDRANT_PORT}/collections/${COLLECTION_NAME}/index" \
    -H 'Content-Type: application/json' \
    -d '{
      "field_name": "section",
      "field_schema": "keyword"
    }')
  
  if echo "$RESPONSE" | grep -q "\"status\":\"ok\""; then
    log "Index sur 'section' créé avec succès"
  else
    warn "Échec de la création de l'index sur 'section': $RESPONSE"
  fi
}

# Vérifier la configuration finale
check_configuration() {
  log "Vérification de la configuration finale..."
  
  # Récupérer les informations sur la collection
  COLLECTION_INFO=$(curl -s "http://${QDRANT_HOST}:${QDRANT_PORT}/collections/${COLLECTION_NAME}")
  
  if echo "$COLLECTION_INFO" | grep -q "\"status\":\"ok\""; then
    log "Configuration de Qdrant vérifiée avec succès"
    log "Collection '${COLLECTION_NAME}' prête à être utilisée"
  else
    error "Impossible de vérifier la configuration: $COLLECTION_INFO"
    return 1
  fi
}

# Fonction principale
main() {
  log "Démarrage de la configuration de Qdrant pour TechnicIA..."
  
  wait_for_qdrant || exit 1
  create_collection || exit 1
  create_indexes || warn "Certains index n'ont pas pu être créés"
  check_configuration || exit 1
  
  log "Configuration de Qdrant terminée avec succès!"
}

# Exécution du script
main
