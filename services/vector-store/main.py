"""
Service de gestion des embeddings et interface avec Qdrant pour TechnicIA.
Utilise VoyageAI pour la génération d'embeddings et Qdrant pour le stockage et la recherche vectorielle.
"""
from fastapi import FastAPI, HTTPException, Body
from fastapi.responses import JSONResponse
import httpx
import os
import logging
import json
import uuid
from typing import Dict, List, Any, Optional
from pydantic import BaseModel, Field
from qdrant_client import QdrantClient
from qdrant_client.http import models

# Configuration du logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Configuration de l'application
app = FastAPI(
    title="Vector Store Service",
    description="Service de gestion des embeddings et interface avec Qdrant pour TechnicIA",
    version="1.0.0"
)

# Configuration Qdrant
QDRANT_HOST = os.getenv("QDRANT_HOST", "qdrant")
QDRANT_PORT = int(os.getenv("QDRANT_PORT", "6333"))
COLLECTION_NAME = os.getenv("COLLECTION_NAME", "technicia")
VECTOR_SIZE = 1024  # Taille des vecteurs VoyageAI

# Configuration VoyageAI
VOYAGE_API_KEY = os.getenv("VOYAGE_API_KEY")
VOYAGE_BASE_URL = "https://api.voyageai.com/v1"

# Modèle utilisé pour les embeddings texte
VOYAGE_TEXT_MODEL = "voyage-large-2"

# Modèles Pydantic pour la validation des données
class TextItem(BaseModel):
    text: str = Field(..., description="Texte à vectoriser")
    metadata: Optional[Dict[str, Any]] = Field(default=None, description="Métadonnées associées au texte")

class SearchQuery(BaseModel):
    query: str = Field(..., description="Requête de recherche")
    limit: int = Field(default=5, description="Nombre maximum de résultats")
    filter: Optional[Dict[str, Any]] = Field(default=None, description="Filtre pour la recherche")

class ImageItem(BaseModel):
    image_url: str = Field(..., description="URL de l'image à vectoriser")
    metadata: Optional[Dict[str, Any]] = Field(default=None, description="Métadonnées associées à l'image")

class VectorRecord(BaseModel):
    id: str = Field(..., description="Identifiant du vecteur")
    vector: List[float] = Field(..., description="Vecteur d'embeddings")
    metadata: Dict[str, Any] = Field(..., description="Métadonnées associées")

class VectorStoreService:
    """Service de gestion des embeddings et interface avec Qdrant."""

    def __init__(self, host: str, port: int, collection_name: str, vector_size: int):
        """
        Initialise le service de gestion des embeddings.
        
        Args:
            host: Hôte Qdrant
            port: Port Qdrant
            collection_name: Nom de la collection
            vector_size: Taille des vecteurs
        """
        self.qdrant_client = QdrantClient(host=host, port=port)
        self.collection_name = collection_name
        self.vector_size = vector_size

        # Vérifier et créer la collection si nécessaire
        self._ensure_collection_exists()

    def _ensure_collection_exists(self):
        """Vérifie que la collection existe et la crée si nécessaire."""
        try:
            collections = self.qdrant_client.get_collections()
            if self.collection_name not in [c.name for c in collections.collections]:
                self.qdrant_client.create_collection(
                    collection_name=self.collection_name,
                    vectors_config=models.VectorParams(
                        size=self.vector_size,
                        distance=models.Distance.COSINE
                    )
                )
                logger.info(f"Collection {self.collection_name} créée avec succès")
            else:
                logger.info(f"Collection {self.collection_name} existe déjà")
        except Exception as e:
            logger.error(f"Erreur lors de la vérification/création de la collection: {str(e)}")
            raise

    async def create_text_embedding(self, text: str) -> List[float]:
        """
        Crée un embedding à partir d'un texte en utilisant VoyageAI.
        
        Args:
            text: Texte à vectoriser
            
        Returns:
            Le vecteur d'embedding
        """
        if not VOYAGE_API_KEY:
            raise HTTPException(
                status_code=500,
                detail="Clé API VoyageAI non configurée"
            )

        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    f"{VOYAGE_BASE_URL}/embeddings",
                    headers={
                        "Authorization": f"Bearer {VOYAGE_API_KEY}",
                        "Content-Type": "application/json"
                    },
                    json={
                        "model": VOYAGE_TEXT_MODEL,
                        "input": text,
                        "input_type": "search_document"
                    },
                    timeout=30.0
                )

                if response.status_code != 200:
                    logger.error(f"Erreur API VoyageAI: {response.text}")
                    raise HTTPException(
                        status_code=response.status_code,
                        detail=f"Erreur API VoyageAI: {response.text}"
                    )

                data = response.json()
                return data["data"][0]["embedding"]
        except httpx.HTTPError as e:
            logger.error(f"Erreur HTTP lors de l'appel à VoyageAI: {str(e)}")
            raise HTTPException(
                status_code=500,
                detail=f"Erreur HTTP lors de l'appel à VoyageAI: {str(e)}"
            )
        except Exception as e:
            logger.error(f"Erreur lors de la création de l'embedding: {str(e)}")
            raise HTTPException(
                status_code=500,
                detail=f"Erreur lors de la création de l'embedding: {str(e)}"
            )

    async def create_image_embedding(self, image_url: str) -> List[float]:
        """
        Crée un embedding à partir d'une image en utilisant VoyageAI.
        
        Args:
            image_url: URL de l'image à vectoriser
            
        Returns:
            Le vecteur d'embedding
        """
        if not VOYAGE_API_KEY:
            raise HTTPException(
                status_code=500,
                detail="Clé API VoyageAI non configurée"
            )

        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    f"{VOYAGE_BASE_URL}/embeddings",
                    headers={
                        "Authorization": f"Bearer {VOYAGE_API_KEY}",
                        "Content-Type": "application/json"
                    },
                    json={
                        "model": "voyage-large-2",
                        "input": image_url,
                        "input_type": "image_url"
                    },
                    timeout=30.0
                )

                if response.status_code != 200:
                    logger.error(f"Erreur API VoyageAI: {response.text}")
                    raise HTTPException(
                        status_code=response.status_code,
                        detail=f"Erreur API VoyageAI: {response.text}"
                    )

                data = response.json()
                return data["data"][0]["embedding"]
        except httpx.HTTPError as e:
            logger.error(f"Erreur HTTP lors de l'appel à VoyageAI: {str(e)}")
            raise HTTPException(
                status_code=500,
                detail=f"Erreur HTTP lors de l'appel à VoyageAI: {str(e)}"
            )
        except Exception as e:
            logger.error(f"Erreur lors de la création de l'embedding: {str(e)}")
            raise HTTPException(
                status_code=500,
                detail=f"Erreur lors de la création de l'embedding: {str(e)}"
            )

    def upsert_vectors(self, vectors: List[VectorRecord]) -> Dict[str, Any]:
        """
        Insère ou met à jour des vecteurs dans Qdrant.
        
        Args:
            vectors: Liste des vecteurs à insérer ou mettre à jour
            
        Returns:
            Résultat de l'opération
        """
        try:
            points = []
            for vector_record in vectors:
                points.append(
                    models.PointStruct(
                        id=vector_record.id,
                        vector=vector_record.vector,
                        payload=vector_record.metadata
                    )
                )

            operation_result = self.qdrant_client.upsert(
                collection_name=self.collection_name,
                points=points
            )

            return {"status": "success", "operation_id": str(operation_result.operation_id)}
        except Exception as e:
            logger.error(f"Erreur lors de l'upsert des vecteurs: {str(e)}")
            raise HTTPException(
                status_code=500,
                detail=f"Erreur lors de l'upsert des vecteurs: {str(e)}"
            )

    async def search_vectors(self, query: str, limit: int = 5, filter: Optional[Dict[str, Any]] = None) -> List[Dict[str, Any]]:
        """
        Recherche des vecteurs similaires à partir d'une requête.
        
        Args:
            query: Requête de recherche
            limit: Nombre maximum de résultats
            filter: Filtre pour la recherche
            
        Returns:
            Liste des résultats
        """
        try:
            # Créer un embedding pour la requête
            query_vector = await self.create_text_embedding(query)

            # Convertir le filtre en format Qdrant si nécessaire
            qdrant_filter = None
            if filter:
                # Construction du filtre Qdrant
                qdrant_filter = models.Filter(**filter)

            # Effectuer la recherche
            search_result = self.qdrant_client.search(
                collection_name=self.collection_name,
                query_vector=query_vector,
                limit=limit,
                query_filter=qdrant_filter
            )

            # Formater les résultats
            results = []
            for result in search_result:
                results.append({
                    "id": result.id,
                    "score": result.score,
                    "metadata": result.payload
                })

            return results
        except Exception as e:
            logger.error(f"Erreur lors de la recherche de vecteurs: {str(e)}")
            raise HTTPException(
                status_code=500,
                detail=f"Erreur lors de la recherche de vecteurs: {str(e)}"
            )

# Créer une instance du service
vector_store = VectorStoreService(
    host=QDRANT_HOST,
    port=QDRANT_PORT,
    collection_name=COLLECTION_NAME,
    vector_size=VECTOR_SIZE
)

@app.get("/health")
async def health_check():
    """Vérification de l'état du service."""
    try:
        # Vérifier que Qdrant est accessible
        collections = vector_store.qdrant_client.get_collections()
        collection_exists = COLLECTION_NAME in [c.name for c in collections.collections]

        return {
            "status": "healthy",
            "qdrant_connected": True,
            "collection_exists": collection_exists,
            "voyage_api_configured": bool(VOYAGE_API_KEY)
        }
    except Exception as e:
        logger.error(f"Erreur de santé: {str(e)}")
        return JSONResponse(
            status_code=500,
            content={"status": "error", "message": str(e)}
        )

@app.post("/embed-text")
async def embed_text(item: TextItem):
    """
    Crée un embedding à partir d'un texte.
    
    Args:
        item: Texte à vectoriser et métadonnées associées
        
    Returns:
        Le vecteur d'embedding et l'identifiant généré
    """
    try:
        # Créer l'embedding
        vector = await vector_store.create_text_embedding(item.text)
        
        # Générer un identifiant unique
        id = str(uuid.uuid4())
        
        # Préparer les métadonnées
        metadata = item.metadata or {}
        metadata["text"] = item.text
        metadata["type"] = "text"
        
        # Créer l'enregistrement vectoriel
        vector_record = VectorRecord(
            id=id,
            vector=vector,
            metadata=metadata
        )
        
        # Insérer dans Qdrant
        result = vector_store.upsert_vectors([vector_record])
        
        return {
            "id": id,
            "status": "success",
            "vector_length": len(vector),
            "operation_result": result
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erreur lors de la vectorisation du texte: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Erreur lors de la vectorisation du texte: {str(e)}"
        )

@app.post("/embed-image")
async def embed_image(item: ImageItem):
    """
    Crée un embedding à partir d'une image.
    
    Args:
        item: URL de l'image à vectoriser et métadonnées associées
        
    Returns:
        Le vecteur d'embedding et l'identifiant généré
    """
    try:
        # Créer l'embedding
        vector = await vector_store.create_image_embedding(item.image_url)
        
        # Générer un identifiant unique
        id = str(uuid.uuid4())
        
        # Préparer les métadonnées
        metadata = item.metadata or {}
        metadata["image_url"] = item.image_url
        metadata["type"] = "image"
        
        # Créer l'enregistrement vectoriel
        vector_record = VectorRecord(
            id=id,
            vector=vector,
            metadata=metadata
        )
        
        # Insérer dans Qdrant
        result = vector_store.upsert_vectors([vector_record])
        
        return {
            "id": id,
            "status": "success",
            "vector_length": len(vector),
            "operation_result": result
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erreur lors de la vectorisation de l'image: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Erreur lors de la vectorisation de l'image: {str(e)}"
        )

@app.post("/search")
async def search(query: SearchQuery):
    """
    Recherche des vecteurs similaires à partir d'une requête.
    
    Args:
        query: Requête de recherche
        
    Returns:
        Liste des résultats
    """
    try:
        results = await vector_store.search_vectors(
            query=query.query,
            limit=query.limit,
            filter=query.filter
        )
        
        return {
            "query": query.query,
            "results": results,
            "count": len(results)
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erreur lors de la recherche: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Erreur lors de la recherche: {str(e)}"
        )

@app.post("/upsert")
async def upsert_vector(vector: VectorRecord):
    """
    Insère ou met à jour un vecteur dans Qdrant.
    
    Args:
        vector: Vecteur à insérer ou mettre à jour
        
    Returns:
        Résultat de l'opération
    """
    try:
        result = vector_store.upsert_vectors([vector])
        
        return {
            "id": vector.id,
            "status": "success",
            "operation_result": result
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erreur lors de l'upsert du vecteur: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Erreur lors de l'upsert du vecteur: {str(e)}"
        )

@app.post("/upsert-batch")
async def upsert_vectors_batch(vectors: List[VectorRecord]):
    """
    Insère ou met à jour plusieurs vecteurs dans Qdrant.
    
    Args:
        vectors: Liste des vecteurs à insérer ou mettre à jour
        
    Returns:
        Résultat de l'opération
    """
    try:
        result = vector_store.upsert_vectors(vectors)
        
        return {
            "status": "success",
            "count": len(vectors),
            "operation_result": result
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erreur lors de l'upsert des vecteurs: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Erreur lors de l'upsert des vecteurs: {str(e)}"
        )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
