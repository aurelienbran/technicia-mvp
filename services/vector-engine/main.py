"""
Service de vectorisation et d'indexation pour TechnicIA.
Utilise VoyageAI pour générer des embeddings et Qdrant pour la recherche vectorielle.
"""
from fastapi import FastAPI, HTTPException, Body
from fastapi.responses import JSONResponse
import httpx
import os
import logging
import json
import time
import uuid
from typing import Dict, List, Any, Optional, Union
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
    title="Vector Engine Service",
    description="Service de vectorisation et d'indexation pour TechnicIA",
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
VOYAGE_TEXT_MODEL = "voyage-large-2"

# Modèles de données
class TextBlock(BaseModel):
    text: str = Field(..., description="Texte du bloc")
    page: Optional[int] = Field(None, description="Numéro de page")
    confidence: Optional[float] = Field(None, description="Score de confiance")
    id: Optional[str] = Field(None, description="Identifiant unique du bloc")

class ImageInfo(BaseModel):
    id: str = Field(..., description="Identifiant unique de l'image")
    path: str = Field(..., description="Chemin vers l'image")
    page: Optional[int] = Field(None, description="Numéro de page")
    classification: str = Field(..., description="Classification de l'image")
    schemaType: Optional[str] = Field(None, description="Type de schéma")
    ocrText: Optional[str] = Field(None, description="Texte extrait de l'image par OCR")

class ProcessRequest(BaseModel):
    documentId: str = Field(..., description="Identifiant unique du document")
    textBlocks: List[Dict[str, Any]] = Field([], description="Blocs de texte à traiter")
    images: List[Dict[str, Any]] = Field([], description="Images à traiter")
    metadata: Optional[Dict[str, Any]] = Field({}, description="Métadonnées du document")

class SearchQuery(BaseModel):
    query: str = Field(..., description="Requête de recherche")
    documentId: Optional[str] = Field(None, description="Filtrer par document spécifique")
    limit: int = Field(5, description="Nombre maximum de résultats")
    includeImages: bool = Field(True, description="Inclure les images dans les résultats")
    includeText: bool = Field(True, description="Inclure le texte dans les résultats")

class VectorEngineService:
    """Service de vectorisation et d'indexation."""
    
    def __init__(self, qdrant_host: str, qdrant_port: int, collection_name: str, vector_size: int):
        """
        Initialise le service.
        
        Args:
            qdrant_host: Hôte Qdrant
            qdrant_port: Port Qdrant
            collection_name: Nom de la collection
            vector_size: Taille des vecteurs
        """
        self.qdrant_client = QdrantClient(host=qdrant_host, port=qdrant_port)
        self.collection_name = collection_name
        self.vector_size = vector_size
        
        # Assurer que la collection existe
        self._ensure_collection_exists()
    
    def _ensure_collection_exists(self):
        """Crée la collection si elle n'existe pas déjà."""
        try:
            collections = self.qdrant_client.get_collections()
            if self.collection_name not in [c.name for c in collections.collections]:
                logger.info(f"Création de la collection {self.collection_name}")
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
        Crée un embedding à partir d'un texte.
        
        Args:
            text: Texte à vectoriser
            
        Returns:
            Vecteur d'embedding
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
        except Exception as e:
            logger.error(f"Erreur lors de la création de l'embedding texte: {str(e)}")
            raise
    
    async def create_image_embedding(self, image_path: str) -> List[float]:
        """
        Crée un embedding à partir d'une image.
        
        Args:
            image_path: Chemin vers l'image
            
        Returns:
            Vecteur d'embedding
        """
        if not VOYAGE_API_KEY:
            raise HTTPException(
                status_code=500,
                detail="Clé API VoyageAI non configurée"
            )
        
        if not os.path.exists(image_path):
            raise HTTPException(
                status_code=404,
                detail=f"Image non trouvée: {image_path}"
            )
        
        try:
            # Pour les besoins du MVP, nous allons utiliser un embedding aléatoire
            # En production, nous utiliserions l'API VoyageAI pour les images
            
            # Simuler un embedding d'image (1024 dimensions, valeurs entre -1 et 1)
            import random
            random.seed(image_path)  # Pour avoir des embeddings consistants
            embedding = [random.uniform(-1, 1) for _ in range(self.vector_size)]
            
            return embedding
            
            # Code réel pour l'API VoyageAI (commenté pour le MVP)
            '''
            async with httpx.AsyncClient() as client:
                # Lire le fichier image en binaire
                with open(image_path, "rb") as f:
                    files = {"image": f}
                    
                    response = await client.post(
                        f"{VOYAGE_BASE_URL}/embeddings",
                        headers={"Authorization": f"Bearer {VOYAGE_API_KEY}"},
                        files=files,
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
            '''
        except Exception as e:
            logger.error(f"Erreur lors de la création de l'embedding image: {str(e)}")
            raise
    
    async def process_text_blocks(self, document_id: str, text_blocks: List[Dict[str, Any]]) -> List[str]:
        """
        Traite et indexe des blocs de texte.
        
        Args:
            document_id: Identifiant du document
            text_blocks: Liste des blocs de texte
            
        Returns:
            Liste des identifiants générés
        """
        ids = []
        points = []
        
        for block in text_blocks:
            # Extraire le texte et autres informations
            text = block.get("text", "")
            if not text.strip():
                continue
            
            # Générer un identifiant unique
            block_id = block.get("id") or f"txt-{document_id}-{str(uuid.uuid4())}"
            ids.append(block_id)
            
            # Créer l'embedding
            embedding = await self.create_text_embedding(text)
            
            # Préparer les métadonnées
            metadata = {
                "type": "text",
                "documentId": document_id,
                "text": text,
                "page": block.get("page"),
                "confidence": block.get("confidence")
            }
            
            # Créer le point Qdrant
            point = models.PointStruct(
                id=block_id,
                vector=embedding,
                payload=metadata
            )
            
            points.append(point)
        
        # Insérer les points dans Qdrant
        if points:
            self.qdrant_client.upsert(
                collection_name=self.collection_name,
                points=points
            )
        
        return ids
    
    async def process_images(self, document_id: str, images: List[Dict[str, Any]]) -> List[str]:
        """
        Traite et indexe des images.
        
        Args:
            document_id: Identifiant du document
            images: Liste des informations d'images
            
        Returns:
            Liste des identifiants générés
        """
        ids = []
        points = []
        
        for image in images:
            # Vérifier le type de classification
            classification = image.get("classification")
            if classification != "technical_diagram":
                logger.info(f"Image {image.get('id')} ignorée: non technique")
                continue
            
            # Récupérer le chemin de l'image
            image_path = image.get("path")
            if not image_path:
                logger.warning(f"Chemin d'image manquant: {image}")
                continue
            
            # Utiliser l'ID existant ou en générer un nouveau
            image_id = image.get("id") or f"img-{document_id}-{str(uuid.uuid4())}"
            ids.append(image_id)
            
            # Créer l'embedding
            embedding = await self.create_image_embedding(image_path)
            
            # Préparer les métadonnées
            metadata = {
                "type": "image",
                "documentId": document_id,
                "path": image_path,
                "page": image.get("page"),
                "schemaType": image.get("schemaType"),
                "ocrText": image.get("ocrText"),
                "classification": classification
            }
            
            # Créer le point Qdrant
            point = models.PointStruct(
                id=image_id,
                vector=embedding,
                payload=metadata
            )
            
            points.append(point)
        
        # Insérer les points dans Qdrant
        if points:
            self.qdrant_client.upsert(
                collection_name=self.collection_name,
                points=points
            )
        
        return ids
    
    async def search(self, query: str, limit: int = 5, document_id: Optional[str] = None, 
                     include_images: bool = True, include_text: bool = True) -> List[Dict[str, Any]]:
        """
        Recherche des éléments similaires à la requête.
        
        Args:
            query: Requête de recherche
            limit: Nombre maximum de résultats
            document_id: Filtrer par document
            include_images: Inclure les images dans les résultats
            include_text: Inclure le texte dans les résultats
            
        Returns:
            Liste des résultats
        """
        # Créer l'embedding de la requête
        query_vector = await self.create_text_embedding(query)
        
        # Construire le filtre
        filter_params = {}
        if document_id:
            filter_params["must"] = [{
                "key": "documentId",
                "match": {"value": document_id}
            }]
        
        if not include_images or not include_text:
            must_not = []
            if not include_images:
                must_not.append({"key": "type", "match": {"value": "image"}})
            if not include_text:
                must_not.append({"key": "type", "match": {"value": "text"}})
            
            if "must" not in filter_params:
                filter_params["must"] = []
            
            filter_params["must_not"] = must_not
        
        # Convertir en modèle Qdrant
        qdrant_filter = models.Filter(**filter_params) if filter_params else None
        
        # Effectuer la recherche
        search_results = self.qdrant_client.search(
            collection_name=self.collection_name,
            query_vector=query_vector,
            limit=limit,
            query_filter=qdrant_filter
        )
        
        # Formater les résultats
        results = []
        for result in search_results:
            payload = result.payload
            result_type = payload.get("type")
            
            formatted_result = {
                "id": result.id,
                "score": result.score,
                "type": result_type,
                "documentId": payload.get("documentId")
            }
            
            if result_type == "text":
                formatted_result["text"] = payload.get("text")
                formatted_result["page"] = payload.get("page")
            elif result_type == "image":
                formatted_result["path"] = payload.get("path")
                formatted_result["page"] = payload.get("page")
                formatted_result["schemaType"] = payload.get("schemaType")
                formatted_result["ocrText"] = payload.get("ocrText")
            
            results.append(formatted_result)
        
        return results
    
    async def get_document_status(self, document_id: str) -> Dict[str, Any]:
        """
        Récupère l'état d'indexation d'un document.
        
        Args:
            document_id: Identifiant du document
            
        Returns:
            État d'indexation
        """
        # Construire le filtre
        filter_params = {
            "must": [{
                "key": "documentId",
                "match": {"value": document_id}
            }]
        }
        
        qdrant_filter = models.Filter(**filter_params)
        
        # Compter les éléments
        text_count = self.qdrant_client.count(
            collection_name=self.collection_name,
            count_filter=models.Filter(
                **{
                    "must": [
                        {"key": "documentId", "match": {"value": document_id}},
                        {"key": "type", "match": {"value": "text"}}
                    ]
                }
            )
        ).count
        
        image_count = self.qdrant_client.count(
            collection_name=self.collection_name,
            count_filter=models.Filter(
                **{
                    "must": [
                        {"key": "documentId", "match": {"value": document_id}},
                        {"key": "type", "match": {"value": "image"}}
                    ]
                }
            )
        ).count
        
        return {
            "documentId": document_id,
            "indexed": True,
            "textCount": text_count,
            "imageCount": image_count,
            "totalCount": text_count + image_count,
            "indexedAt": time.time()
        }

# Créer une instance du service
vector_engine = VectorEngineService(
    qdrant_host=QDRANT_HOST,
    qdrant_port=QDRANT_PORT,
    collection_name=COLLECTION_NAME,
    vector_size=VECTOR_SIZE
)

@app.get("/health")
async def health_check():
    """Vérification de l'état du service."""
    try:
        # Vérifier que Qdrant est accessible
        collections = vector_engine.qdrant_client.get_collections()
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

@app.post("/api/process")
async def process_document(request: ProcessRequest):
    """
    Traite et indexe le contenu d'un document.
    
    Args:
        request: Informations sur le document à traiter
        
    Returns:
        Résultats du traitement
    """
    try:
        logger.info(f"Traitement du document: {request.documentId}")
        
        # Traiter les blocs de texte
        text_ids = await vector_engine.process_text_blocks(
            document_id=request.documentId,
            text_blocks=request.textBlocks
        )
        
        # Traiter les images
        image_ids = await vector_engine.process_images(
            document_id=request.documentId,
            images=request.images
        )
        
        # Indexer les métadonnées du document
        if request.metadata:
            # Générer un identifiant unique pour les métadonnées
            metadata_id = f"meta-{request.documentId}"
            
            # Créer un embedding à partir d'une description du document
            description = f"Document {request.documentId} {request.metadata.get('fileName', '')}"
            metadata_embedding = await vector_engine.create_text_embedding(description)
            
            # Préparer les métadonnées
            metadata_payload = {
                "type": "metadata",
                "documentId": request.documentId,
                **request.metadata
            }
            
            # Créer le point Qdrant
            metadata_point = models.PointStruct(
                id=metadata_id,
                vector=metadata_embedding,
                payload=metadata_payload
            )
            
            # Insérer le point dans Qdrant
            vector_engine.qdrant_client.upsert(
                collection_name=vector_engine.collection_name,
                points=[metadata_point]
            )
        
        return {
            "success": True,
            "documentId": request.documentId,
            "stats": {
                "totalTextBlocks": len(request.textBlocks),
                "indexedTextBlocks": len(text_ids),
                "totalImages": len(request.images),
                "indexedImages": len(image_ids),
                "chunksCount": len(text_ids) + len(image_ids),
                "indexedCount": len(text_ids) + len(image_ids)
            },
            "searchEndpoint": "/api/search",
            "processingTimestamp": time.time()
        }
        
    except Exception as e:
        logger.error(f"Erreur lors du traitement du document: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Erreur lors du traitement du document: {str(e)}"
        )

@app.post("/api/search")
async def search(query: SearchQuery):
    """
    Recherche des éléments similaires à la requête.
    
    Args:
        query: Paramètres de recherche
        
    Returns:
        Résultats de la recherche
    """
    try:
        logger.info(f"Recherche: '{query.query}'")
        
        results = await vector_engine.search(
            query=query.query,
            limit=query.limit,
            document_id=query.documentId,
            include_images=query.includeImages,
            include_text=query.includeText
        )
        
        return {
            "success": True,
            "query": query.query,
            "results": results,
            "count": len(results),
            "timestamp": time.time()
        }
        
    except Exception as e:
        logger.error(f"Erreur lors de la recherche: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Erreur lors de la recherche: {str(e)}"
        )

@app.get("/api/document/{document_id}/status")
async def get_document_status(document_id: str):
    """
    Récupère l'état d'indexation d'un document.
    
    Args:
        document_id: Identifiant du document
        
    Returns:
        État d'indexation
    """
    try:
        logger.info(f"Récupération du statut du document: {document_id}")
        
        status = await vector_engine.get_document_status(document_id)
        
        return {
            "success": True,
            "documentId": document_id,
            "status": status,
            "timestamp": time.time()
        }
        
    except Exception as e:
        logger.error(f"Erreur lors de la récupération du statut: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Erreur lors de la récupération du statut: {str(e)}"
        )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8003, reload=True)
