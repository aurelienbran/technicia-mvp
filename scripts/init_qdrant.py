#!/usr/bin/env python3
"""
Script d'initialisation de Qdrant pour TechnicIA.
Crée la collection principale si elle n'existe pas déjà.
"""
import os
import logging
import sys
from qdrant_client import QdrantClient
from qdrant_client.http import models

# Configuration du logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Configuration Qdrant
QDRANT_HOST = os.getenv("QDRANT_HOST", "qdrant")
QDRANT_PORT = int(os.getenv("QDRANT_PORT", "6333"))
COLLECTION_NAME = os.getenv("COLLECTION_NAME", "technicia")
VECTOR_SIZE = 1024  # Taille des vecteurs VoyageAI

def init_qdrant():
    """
    Initialise Qdrant en créant la collection principale si elle n'existe pas.
    Configure les index appropriés pour les métadonnées.
    """
    try:
        logger.info(f"Connexion à Qdrant sur {QDRANT_HOST}:{QDRANT_PORT}")
        client = QdrantClient(host=QDRANT_HOST, port=QDRANT_PORT)
        
        # Vérifier si la collection existe déjà
        collections = client.get_collections()
        collection_names = [c.name for c in collections.collections]
        
        if COLLECTION_NAME in collection_names:
            logger.info(f"La collection {COLLECTION_NAME} existe déjà")
            return
        
        # Créer la collection
        logger.info(f"Création de la collection {COLLECTION_NAME}")
        client.create_collection(
            collection_name=COLLECTION_NAME,
            vectors_config=models.VectorParams(
                size=VECTOR_SIZE,
                distance=models.Distance.COSINE
            )
        )
        
        # Créer des index pour accélérer les requêtes
        logger.info("Création des index pour les métadonnées")
        client.create_payload_index(
            collection_name=COLLECTION_NAME,
            field_name="type",
            field_schema=models.PayloadSchemaType.KEYWORD
        )
        
        client.create_payload_index(
            collection_name=COLLECTION_NAME,
            field_name="page_number",
            field_schema=models.PayloadSchemaType.INTEGER
        )
        
        logger.info("Initialisation de Qdrant réussie")
        
    except Exception as e:
        logger.error(f"Erreur lors de l'initialisation de Qdrant: {str(e)}")
        sys.exit(1)

if __name__ == "__main__":
    init_qdrant()
