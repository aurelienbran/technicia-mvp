"""
Service d'analyse de schémas techniques pour TechnicIA.
Utilise Google Vision AI pour classifier et extraire du texte des schémas techniques.
"""
from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.responses import JSONResponse
from google.cloud import vision
from enum import Enum
import asyncio
import os
import logging
import time
import json
from pathlib import Path
from typing import Dict, List, Any, Optional
from pydantic import BaseModel, Field

# Configuration du logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Configuration de l'application
app = FastAPI(
    title="Schema Analyzer Service",
    description="Service d'analyse de schémas techniques pour TechnicIA",
    version="1.0.0"
)

class SchemaType(str, Enum):
    """Types de schémas techniques."""
    ELECTRICAL = "electrical"
    HYDRAULIC = "hydraulic"
    PNEUMATIC = "pneumatic"
    MECHANICAL = "mechanical"
    UNKNOWN = "unknown"

# Modèle pour la requête d'analyse
class AnalyzeRequest(BaseModel):
    documentId: str = Field(..., description="Identifiant du document")
    images: List[Dict[str, Any]] = Field(..., description="Liste des images à analyser")
    basePath: str = Field(..., description="Répertoire de base du document")

# Modèle pour l'analyse d'une image par chemin
class ImagePathAnalysisRequest(BaseModel):
    imagePath: str = Field(..., description="Chemin vers l'image à analyser")
    imageId: Optional[str] = Field(None, description="Identifiant unique de l'image")
    documentId: Optional[str] = Field(None, description="Identifiant du document parent")
    page: Optional[int] = Field(None, description="Numéro de page où se trouve l'image")

class SchemaAnalyzer:
    """Classe pour l'analyse des schémas techniques avec Vision AI."""
    
    def __init__(self):
        """Initialise l'analyseur de schémas."""
        self.client = vision.ImageAnnotatorClient()
        
        # Définition des features pour chaque type de schéma
        self.schema_features = {
            SchemaType.ELECTRICAL: ["circuit", "electrical", "wiring", "schematic", "diagram", "electronic"],
            SchemaType.HYDRAULIC: ["hydraulic", "fluid", "pump", "valve", "cylinder", "pressure", "water"],
            SchemaType.PNEUMATIC: ["pneumatic", "air", "compressor", "valve", "cylinder", "pressure", "gas"],
            SchemaType.MECHANICAL: ["mechanical", "gear", "assembly", "machine", "part", "engine", "motor"]
        }
    
    async def analyze_image_from_path(self, image_path: str) -> Dict[str, Any]:
        """
        Analyse une image à partir de son chemin.
        
        Args:
            image_path: Chemin vers l'image à analyser
            
        Returns:
            Résultats de l'analyse
        """
        try:
            # Vérifier si le fichier existe
            if not os.path.exists(image_path):
                raise HTTPException(
                    status_code=404,
                    detail=f"Image non trouvée: {image_path}"
                )
            
            # Lire le contenu de l'image
            with open(image_path, "rb") as image_file:
                content = image_file.read()
            
            return await self._analyze_image_content(content)
            
        except Exception as e:
            logger.error(f"Erreur lors de l'analyse de l'image {image_path}: {str(e)}")
            raise
    
    async def _analyze_image_content(self, image_content: bytes) -> Dict[str, Any]:
        """
        Analyse le contenu d'une image avec Vision AI.
        
        Args:
            image_content: Contenu binaire de l'image
            
        Returns:
            Résultats de l'analyse
        """
        try:
            # Créer l'objet Image
            image = vision.Image(content=image_content)
            
            # Définir les fonctionnalités à analyser
            features = [
                vision.Feature(type_=vision.Feature.Type.LABEL_DETECTION, max_results=20),
                vision.Feature(type_=vision.Feature.Type.TEXT_DETECTION),
                vision.Feature(type_=vision.Feature.Type.DOCUMENT_TEXT_DETECTION),
                vision.Feature(type_=vision.Feature.Type.IMAGE_PROPERTIES)
            ]
            
            # Créer la requête d'annotation
            request = vision.AnnotateImageRequest(image=image, features=features)
            
            # Envoyer la requête (en asynchrone pour ne pas bloquer)
            response = await asyncio.to_thread(
                self.client.annotate_image,
                request=request
            )
            
            # Extraire les étiquettes
            labels = []
            if response.label_annotations:
                labels = [
                    {
                        "description": label.description.lower(),
                        "score": label.score,
                        "topicality": label.topicality
                    }
                    for label in response.label_annotations
                ]
            
            # Extraire le texte (OCR)
            detected_text = ""
            if response.document_text_annotation and response.document_text_annotation.text:
                detected_text = response.document_text_annotation.text
            elif response.text_annotations and response.text_annotations[0].description:
                detected_text = response.text_annotations[0].description
            
            # Déterminer le type de schéma et si c'est un schéma technique
            label_descriptions = [label["description"] for label in labels]
            is_technical = self._is_technical_diagram(label_descriptions, detected_text)
            schema_type = self._determine_schema_type(label_descriptions, detected_text)
            confidence = self._calculate_confidence(schema_type, label_descriptions, detected_text)
            
            # Extraire les couleurs dominantes
            colors = []
            if response.image_properties and response.image_properties.dominant_colors:
                colors = [
                    {
                        "red": color.color.red,
                        "green": color.color.green,
                        "blue": color.color.blue,
                        "score": color.score,
                        "pixel_fraction": color.pixel_fraction
                    }
                    for color in response.image_properties.dominant_colors.colors[:5]
                ]
            
            # Classification finale
            classification = "technical_diagram" if is_technical else "decorative"
            
            return {
                "classification": classification,
                "schemaType": schema_type.value,
                "confidence": confidence,
                "ocrText": detected_text if detected_text else None,
                "labels": labels,
                "dominantColors": colors,
                "processingTime": time.time()
            }
            
        except Exception as e:
            logger.error(f"Erreur lors de l'analyse de l'image: {str(e)}")
            raise
    
    def _is_technical_diagram(self, labels: List[str], text: str) -> bool:
        """
        Détermine si l'image est un schéma technique.
        
        Args:
            labels: Liste des étiquettes détectées
            text: Texte détecté dans l'image
            
        Returns:
            True si c'est un schéma technique, False sinon
        """
        # Indicateurs de schémas techniques
        technical_indicators = [
            "diagram", "schematic", "blueprint", "technical drawing", "circuit",
            "plan", "design", "drawing", "schematics", "technical", "engineering"
        ]
        
        # Vérifier dans les étiquettes
        if any(indicator in label for label in labels for indicator in technical_indicators):
            return True
            
        # Vérifier dans le texte
        text_lower = text.lower()
        if any(indicator in text_lower for indicator in technical_indicators):
            return True
            
        return False
    
    def _determine_schema_type(self, labels: List[str], text: str) -> SchemaType:
        """
        Détermine le type de schéma technique.
        
        Args:
            labels: Liste des étiquettes détectées
            text: Texte détecté dans l'image
            
        Returns:
            Type de schéma
        """
        # Combiner les étiquettes et le texte
        text_lower = text.lower()
        combined_text = " ".join(labels) + " " + text_lower
        
        scores = {}
        for schema_type, features in self.schema_features.items():
            score = sum(1 for feature in features if feature in combined_text)
            scores[schema_type] = score
        
        # Déterminer le type avec le score le plus élevé
        if not scores or max(scores.values()) == 0:
            return SchemaType.UNKNOWN
            
        return max(scores.items(), key=lambda x: x[1])[0]
    
    def _calculate_confidence(self, schema_type: SchemaType, labels: List[str], text: str) -> float:
        """
        Calcule la confiance dans la classification.
        
        Args:
            schema_type: Type de schéma déterminé
            labels: Liste des étiquettes détectées
            text: Texte détecté dans l'image
            
        Returns:
            Score de confiance entre 0 et 1
        """
        if schema_type == SchemaType.UNKNOWN:
            return 0.0
            
        text_lower = text.lower()
        combined_text = " ".join(labels) + " " + text_lower
        features = self.schema_features[schema_type]
        
        # Calculer le nombre de caractéristiques détectées
        detected = sum(1 for feature in features if feature in combined_text)
        
        # Calculer le ratio
        confidence = detected / len(features)
        
        # Bonus si plusieurs caractéristiques sont détectées
        if detected > 2:
            confidence = min(1.0, confidence * 1.2)
            
        return confidence

# Créer une instance de l'analyseur
analyzer = SchemaAnalyzer()

@app.get("/health")
async def health_check():
    """Vérification de l'état du service."""
    try:
        return {
            "status": "healthy",
            "google_vision_configured": True
        }
    except Exception as e:
        logger.error(f"Erreur de santé: {str(e)}")
        return JSONResponse(
            status_code=500,
            content={"status": "error", "message": str(e)}
        )

@app.post("/api/analyze")
async def analyze_document_images(request: AnalyzeRequest):
    """
    Analyse les images d'un document.
    
    Args:
        request: Informations sur les images à analyser
        
    Returns:
        Résultats de l'analyse pour chaque image
    """
    try:
        logger.info(f"Analyse des images pour le document {request.documentId}")
        
        results = []
        failed_images = []
        
        # Traiter chaque image
        for image_info in request.images:
            try:
                # Récupérer le chemin de l'image
                image_path = image_info.get("path")
                if not image_path:
                    logger.warning(f"Chemin d'image manquant: {image_info}")
                    failed_images.append({
                        "id": image_info.get("id", "unknown"),
                        "error": "Chemin d'image manquant"
                    })
                    continue
                
                # Si le chemin est relatif, le rendre absolu par rapport au basePath
                if not os.path.isabs(image_path):
                    image_path = os.path.join(request.basePath, image_path)
                
                # Analyser l'image
                analysis_result = await analyzer.analyze_image_from_path(image_path)
                
                # Ajouter les informations de l'image
                analysis_result.update({
                    "id": image_info.get("id", f"img-{len(results)}"),
                    "path": image_path,
                    "page": image_info.get("page"),
                    "width": image_info.get("width"),
                    "height": image_info.get("height")
                })
                
                results.append(analysis_result)
                
            except Exception as e:
                logger.error(f"Erreur lors de l'analyse de l'image {image_info.get('id', 'unknown')}: {str(e)}")
                failed_images.append({
                    "id": image_info.get("id", "unknown"),
                    "path": image_info.get("path", "unknown"),
                    "error": str(e)
                })
        
        return {
            "success": True,
            "documentId": request.documentId,
            "images": results,
            "failedImages": failed_images,
            "processingTimestamp": time.time(),
            "stats": {
                "totalImages": len(request.images),
                "processedImages": len(results),
                "failedImages": len(failed_images),
                "technicalDiagrams": sum(1 for img in results if img["classification"] == "technical_diagram")
            }
        }
        
    except Exception as e:
        logger.error(f"Erreur lors de l'analyse des images: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Erreur lors de l'analyse des images: {str(e)}"
        )

@app.post("/api/analyze-image")
async def analyze_single_image(request: ImagePathAnalysisRequest):
    """
    Analyse une seule image par son chemin.
    
    Args:
        request: Informations sur l'image à analyser
        
    Returns:
        Résultats de l'analyse de l'image
    """
    try:
        logger.info(f"Analyse de l'image: {request.imagePath}")
        
        # Analyser l'image
        analysis_result = await analyzer.analyze_image_from_path(request.imagePath)
        
        # Ajouter les informations de l'image
        analysis_result.update({
            "id": request.imageId or f"img-{int(time.time())}",
            "path": request.imagePath,
            "documentId": request.documentId,
            "page": request.page
        })
        
        return {
            "success": True,
            "image": analysis_result,
            "processingTimestamp": time.time()
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erreur lors de l'analyse de l'image: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Erreur lors de l'analyse de l'image: {str(e)}"
        )

@app.post("/classify")
async def classify_image(file: UploadFile = File(...)):
    """
    Classifie une image uploadée.
    
    Args:
        file: Fichier image à classifier
        
    Returns:
        Résultats de la classification
    """
    try:
        # Vérifier le type de fichier
        content_type = file.content_type or ""
        if not content_type.startswith("image/"):
            raise HTTPException(
                status_code=400,
                detail="Type de fichier non supporté. Seules les images sont acceptées."
            )
        
        # Lire le contenu de l'image
        image_content = await file.read()
        
        # Analyser l'image
        analysis_result = await analyzer._analyze_image_content(image_content)
        
        return {
            "success": True,
            "filename": file.filename,
            "classification": analysis_result
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erreur lors de la classification de l'image: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Erreur lors de la classification de l'image: {str(e)}"
        )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8002, reload=True)
