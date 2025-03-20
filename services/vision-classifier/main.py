"""
Service de classification d'images pour TechnicIA.
Utilise Google Vision AI pour détecter et classifier les schémas techniques.
"""
from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.responses import JSONResponse
from google.cloud import vision
from enum import Enum
import asyncio
import os
import base64
import logging
import io
from typing import Dict, List, Any, Optional
import time

# Configuration du logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Configuration de l'application
app = FastAPI(
    title="Vision Classifier Service",
    description="Service de classification d'images pour TechnicIA",
    version="1.0.0"
)

class SchemaType(str, Enum):
    """Types de schémas techniques."""
    ELECTRICAL = "electrical"
    HYDRAULIC = "hydraulic"
    PNEUMATIC = "pneumatic"
    MECHANICAL = "mechanical"
    UNKNOWN = "unknown"

class VisionClassifier:
    """Classe pour la classification des images avec Vision AI."""
    
    def __init__(self):
        """Initialise le classificateur Vision."""
        self.client = vision.ImageAnnotatorClient()
        
        # Définition des features pour chaque type de schéma
        self.schema_features = {
            SchemaType.ELECTRICAL: ["circuit", "electrical", "wiring", "schematic", "diagram", "electronic"],
            SchemaType.HYDRAULIC: ["hydraulic", "fluid", "pump", "valve", "cylinder", "pressure", "water"],
            SchemaType.PNEUMATIC: ["pneumatic", "air", "compressor", "valve", "cylinder", "pressure", "gas"],
            SchemaType.MECHANICAL: ["mechanical", "gear", "assembly", "machine", "part", "engine", "motor"]
        }
    
    async def classify_image(self, image_content: bytes) -> Dict[str, Any]:
        """
        Classifie une image avec Vision AI.
        
        Args:
            image_content: Le contenu binaire de l'image
            
        Returns:
            Un dictionnaire avec les résultats de classification
        """
        try:
            # Créer l'objet Image
            image = vision.Image(content=image_content)
            
            # Exécuter les différentes analyses en parallèle pour optimiser
            features = [
                vision.Feature(type_=vision.Feature.Type.LABEL_DETECTION, max_results=20),
                vision.Feature(type_=vision.Feature.Type.TEXT_DETECTION),
                vision.Feature(type_=vision.Feature.Type.DOCUMENT_TEXT_DETECTION),
                vision.Feature(type_=vision.Feature.Type.IMAGE_PROPERTIES)
            ]
            
            # Créer la requête d'annotation
            request = vision.AnnotateImageRequest(image=image, features=features)
            
            # Envoyer la requête
            response = await asyncio.to_thread(
                self.client.annotate_image,
                request=request
            )
            
            # Extraire les résultats
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
            
            # Extraire le texte détecté (utiliser document_text si disponible, sinon text)
            detected_text = ""
            if response.document_text_annotation and response.document_text_annotation.text:
                detected_text = response.document_text_annotation.text
            elif response.text_annotations and response.text_annotations[0].description:
                detected_text = response.text_annotations[0].description
            
            # Déterminer le type de schéma
            label_descriptions = [label["description"] for label in labels]
            schema_type = self._determine_schema_type(label_descriptions, detected_text)
            
            # Vérifier si c'est un schéma technique
            is_technical = self._is_technical_diagram(label_descriptions, detected_text)
            
            # Calculer la confiance
            confidence = self._calculate_confidence(schema_type, label_descriptions, detected_text)
            
            # Analyser les couleurs dominantes
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
            
            return {
                "is_technical_diagram": is_technical,
                "schema_type": schema_type.value,
                "confidence": confidence,
                "labels": labels,
                "detected_text": detected_text,
                "dominant_colors": colors,
                "processing_time": time.time()
            }
            
        except Exception as e:
            logger.error(f"Erreur lors de la classification de l'image: {str(e)}")
            raise HTTPException(
                status_code=500,
                detail=f"Erreur lors de la classification: {str(e)}"
            )
    
    def _is_technical_diagram(self, labels: List[str], text: str) -> bool:
        """
        Détermine si l'image est un schéma technique.
        
        Args:
            labels: Liste des labels détectés
            text: Texte détecté dans l'image
            
        Returns:
            True si l'image est un schéma technique, False sinon
        """
        # Indicateurs de schémas techniques
        technical_indicators = [
            "diagram", "schematic", "blueprint", "technical drawing", "circuit",
            "plan", "design", "drawing", "schematics", "technical", "engineering"
        ]
        
        # Vérifier si les labels ou le texte contiennent des indicateurs
        if any(indicator in labels for indicator in technical_indicators):
            return True
            
        # Vérifier dans le texte détecté
        text_lower = text.lower()
        if any(indicator in text_lower for indicator in technical_indicators):
            return True
            
        return False
    
    def _determine_schema_type(self, labels: List[str], text: str) -> SchemaType:
        """
        Détermine le type de schéma technique.
        
        Args:
            labels: Liste des labels détectés
            text: Texte détecté dans l'image
            
        Returns:
            Le type de schéma
        """
        # Combiner les labels et le texte pour une meilleure détection
        text_lower = text.lower()
        combined_text = " ".join(labels) + " " + text_lower
        
        scores = {}
        for schema_type, features in self.schema_features.items():
            # Calculer le score basé sur le nombre de features détectées
            score = sum(1 for feature in features if feature in combined_text)
            scores[schema_type] = score
        
        # Déterminer le type avec le score le plus élevé
        if not scores or max(scores.values()) == 0:
            return SchemaType.UNKNOWN
            
        return max(scores.items(), key=lambda x: x[1])[0]
    
    def _calculate_confidence(self, schema_type: SchemaType, labels: List[str], text: str) -> float:
        """
        Calcule le niveau de confiance pour le type de schéma déterminé.
        
        Args:
            schema_type: Le type de schéma déterminé
            labels: Liste des labels détectés
            text: Texte détecté dans l'image
            
        Returns:
            Le niveau de confiance entre 0 et 1
        """
        if schema_type == SchemaType.UNKNOWN:
            return 0.0
            
        text_lower = text.lower()
        combined_text = " ".join(labels) + " " + text_lower
        features = self.schema_features[schema_type]
        
        # Calculer le nombre de features détectées
        detected = sum(1 for feature in features if feature in combined_text)
        
        # Calculer le ratio de features détectées
        confidence = detected / len(features)
        
        # Bonus si plusieurs features sont détectées
        if detected > 2:
            confidence = min(1.0, confidence * 1.2)
            
        return confidence

# Créer une instance du classificateur
classifier = VisionClassifier()

@app.get("/health")
async def health_check():
    """Vérification de l'état du service."""
    try:
        # Vérifier que Vision AI est configuré
        return {
            "status": "healthy",
            "google_vision_initialized": True
        }
    except Exception as e:
        logger.error(f"Erreur de santé: {str(e)}")
        return JSONResponse(
            status_code=500,
            content={"status": "error", "message": str(e)}
        )

@app.post("/classify")
async def classify_image(file: UploadFile = File(...)):
    """
    Classifie une image avec Vision AI.
    
    Args:
        file: Le fichier image à classifier
        
    Returns:
        Les résultats de classification
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
        
        # Classifier l'image
        results = await classifier.classify_image(image_content)
        
        return results
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erreur lors de la classification: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Erreur lors de la classification: {str(e)}"
        )

@app.post("/classify-base64")
async def classify_image_base64(data: Dict[str, str]):
    """
    Classifie une image encodée en base64.
    
    Args:
        data: Dictionnaire contenant l'image encodée en base64
        
    Returns:
        Les résultats de classification
    """
    try:
        # Vérifier que les données sont présentes
        if "image" not in data:
            raise HTTPException(
                status_code=400,
                detail="Données manquantes. Le champ 'image' est requis."
            )
        
        # Décoder l'image base64
        try:
            image_data = data["image"]
            # Supprimer le préfixe data:image/... si présent
            if "base64," in image_data:
                image_data = image_data.split("base64,")[1]
                
            image_content = base64.b64decode(image_data)
        except Exception as e:
            raise HTTPException(
                status_code=400,
                detail=f"Erreur lors du décodage de l'image: {str(e)}"
            )
        
        # Classifier l'image
        results = await classifier.classify_image(image_content)
        
        return results
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erreur lors de la classification base64: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Erreur lors de la classification: {str(e)}"
        )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
