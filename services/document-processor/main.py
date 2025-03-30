"""
Service de traitement des documents PDF pour TechnicIA.
Utilise Google Document AI pour l'extraction de texte et la structuration du contenu.
"""
from fastapi import FastAPI, File, UploadFile, BackgroundTasks, HTTPException, Form, Request, Body
from fastapi.responses import JSONResponse
from google.cloud import documentai_v1 as documentai
import asyncio
import os
import logging
import tempfile
import time
import uuid
from typing import Dict, Any, List, Optional
from pathlib import Path
from pydantic import BaseModel, Field

# Configuration du logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Configuration de l'application
app = FastAPI(
    title="Document Processor Service",
    description="Service de traitement des documents PDF pour TechnicIA",
    version="1.0.0"
)

# Configuration Document AI
DOCUMENT_AI_PROJECT = os.getenv("DOCUMENT_AI_PROJECT")
DOCUMENT_AI_LOCATION = os.getenv("DOCUMENT_AI_LOCATION", "eu")
DOCUMENT_AI_PROCESSOR_ID = os.getenv("DOCUMENT_AI_PROCESSOR_ID")

# Stockage temporaire
TEMP_DIR = Path(os.getenv("TEMP_DIR", "/tmp/technicia"))
TEMP_DIR.mkdir(exist_ok=True, parents=True)

# Suivi des tâches en cours
processing_tasks = {}

# Modèles de données
class ProcessByPathRequest(BaseModel):
    documentId: str = Field(..., description="Identifiant unique du document")
    filePath: str = Field(..., description="Chemin vers le fichier PDF à traiter")
    fileName: Optional[str] = Field(None, description="Nom du fichier (optionnel)")
    mimeType: str = Field("application/pdf", description="Type MIME du document")
    outputPath: Optional[str] = Field(None, description="Répertoire de sortie pour les résultats")
    extractImages: bool = Field(True, description="Extraire les images du document")
    extractText: bool = Field(True, description="Extraire le texte du document")

@app.get("/health")
async def health_check():
    """Vérification de l'état du service."""
    try:
        return {
            "status": "healthy",
            "google_cloud_configured": all([
                DOCUMENT_AI_PROJECT,
                DOCUMENT_AI_LOCATION,
                DOCUMENT_AI_PROCESSOR_ID
            ]),
            "temp_dir": str(TEMP_DIR),
            "active_tasks": len(processing_tasks)
        }
    except Exception as e:
        logger.error(f"Erreur de santé: {str(e)}")
        return JSONResponse(
            status_code=500,
            content={"status": "error", "message": str(e)}
        )

@app.post("/api/process")
async def process_by_path(request: ProcessByPathRequest):
    """
    Traite un document PDF à partir de son chemin sur le système de fichiers.
    
    Args:
        request: Informations sur le document à traiter
        
    Returns:
        Les données extraites du document
    """
    try:
        logger.info(f"Traitement du document par chemin: {request.filePath} (ID: {request.documentId})")
        
        # Validation du chemin de fichier
        file_path = Path(request.filePath)
        if not file_path.exists():
            raise HTTPException(
                status_code=404,
                detail=f"Fichier non trouvé: {request.filePath}"
            )
        
        if not file_path.is_file():
            raise HTTPException(
                status_code=400,
                detail=f"Le chemin spécifié n'est pas un fichier: {request.filePath}"
            )
        
        # Validation du type de fichier
        if not file_path.name.lower().endswith('.pdf'):
            raise HTTPException(
                status_code=400,
                detail="Type de fichier non supporté. Seuls les fichiers PDF sont acceptés."
            )
        
        # Initialiser le client Document AI
        client = documentai.DocumentProcessorServiceClient()
        name = f"projects/{DOCUMENT_AI_PROJECT}/locations/{DOCUMENT_AI_LOCATION}/processors/{DOCUMENT_AI_PROCESSOR_ID}"
        
        # Lire le fichier PDF
        with open(file_path, "rb") as f:
            content = f.read()
        
        # Préparation du nom de fichier
        file_name = request.fileName or file_path.name
        
        # Préparation du répertoire de sortie
        output_path = request.outputPath or str(TEMP_DIR / request.documentId)
        os.makedirs(output_path, exist_ok=True)
        
        # Préparer et envoyer la requête à Document AI
        document = documentai.RawDocument(content=content, mime_type=request.mimeType)
        request_doc_ai = documentai.ProcessRequest(name=name, raw_document=document)
        
        # Traiter le document
        result = client.process_document(request=request_doc_ai)
        document = result.document
        
        # Extraire et structurer le texte si demandé
        text_blocks = []
        if request.extractText:
            text = document.text
            
            # Extraction du texte par page
            for page in document.pages:
                page_blocks = []
                for paragraph in page.paragraphs:
                    para_text = get_text_from_layout(paragraph.layout, text)
                    # Ne pas ajouter de paragraphes vides
                    if para_text.strip():
                        page_blocks.append({
                            "text": para_text,
                            "confidence": paragraph.layout.confidence,
                            "page": page.page_number
                        })
                
                text_blocks.extend(page_blocks)
        
        # Extraire les images si demandé
        images = []
        if request.extractImages:
            image_output_dir = Path(output_path) / "images"
            image_output_dir.mkdir(exist_ok=True)
            
            for page_idx, page in enumerate(document.pages):
                page_number = page.page_number
                
                # Si la page a une image détectée, l'enregistrer
                # Note: Dans un vrai traitement, nous utiliserions les données réelles d'image
                # Pour ce MVP, nous simulons la détection d'images
                
                # Simulation: 1-2 images par page
                for img_idx in range(min(2, page_idx % 3 + 1)):
                    image_id = f"img-{request.documentId}-p{page_number}-{img_idx}"
                    image_path = image_output_dir / f"{image_id}.png"
                    
                    # Création d'une image factice (en production, extraite réellement du PDF)
                    # Ici nous créons juste un fichier vide pour simuler
                    with open(image_path, "w") as f:
                        f.write("")
                    
                    images.append({
                        "id": image_id,
                        "path": str(image_path),
                        "page": page_number,
                        "width": page.dimension.width if hasattr(page, "dimension") and hasattr(page.dimension, "width") else 0,
                        "height": page.dimension.height if hasattr(page, "dimension") and hasattr(page.dimension, "height") else 0
                    })
        
        # Structurer le résultat
        structured_result = {
            "success": True,
            "documentId": request.documentId,
            "fileName": file_name,
            "pageCount": len(document.pages),
            "textBlocks": text_blocks,
            "images": images,
            "processingDetails": {
                "processingTime": time.time(),
                "documentAiModel": "default",
                "mimeType": document.mime_type
            },
            "metadata": {
                "originalPath": str(file_path),
                "outputPath": output_path
            }
        }
        
        return structured_result
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erreur lors du traitement du document: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Erreur lors du traitement du document: {str(e)}"
        )

@app.post("/process")
async def process_document(file: UploadFile = File(...)):
    """
    Traite un document PDF de manière synchrone.
    
    Args:
        file: Le fichier PDF à traiter
        
    Returns:
        Les données extraites du document
    """
    try:
        # Log pour debugging
        logger.info(f"Réception d'un fichier: {file.filename}")
        
        # Validation du type de fichier
        if not file.filename.lower().endswith('.pdf'):
            raise HTTPException(
                status_code=400,
                detail="Type de fichier non supporté. Seuls les fichiers PDF sont acceptés."
            )
        
        # Générer un ID unique
        document_id = str(uuid.uuid4())
        
        # Sauvegarder le fichier temporairement
        temp_file_path = TEMP_DIR / f"{document_id}_{file.filename}"
        
        with open(temp_file_path, "wb") as temp_file:
            content = await file.read()
            temp_file.write(content)
        
        # Utiliser la nouvelle route de traitement par chemin
        request = ProcessByPathRequest(
            documentId=document_id,
            filePath=str(temp_file_path),
            fileName=file.filename,
            mimeType="application/pdf",
            extractImages=True,
            extractText=True
        )
        
        result = await process_by_path(request)
        
        # Nettoyer le fichier temporaire
        try:
            os.unlink(temp_file_path)
        except Exception as e:
            logger.warning(f"Erreur lors du nettoyage du fichier {temp_file_path}: {str(e)}")
        
        return result
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erreur lors du traitement du document: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Erreur lors du traitement du document: {str(e)}"
        )

@app.post("/process-file")
async def process_file(request: Request):
    """
    Alternative endpoint pour traiter un fichier PDF avec des formulaires standards.
    Utile pour les clients qui ont des difficultés avec le format multipart/form-data.
    """
    try:
        form = await request.form()
        
        # Vérifier si un fichier est présent dans le formulaire
        if "file" not in form:
            all_keys = list(form.keys())
            raise HTTPException(
                status_code=400,
                detail=f"Aucun fichier trouvé sous le nom 'file'. Clés disponibles: {all_keys}"
            )
        
        file = form["file"]
        
        # Appeler la méthode de traitement standard
        return await process_document(file)
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erreur lors du traitement du fichier: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Erreur lors du traitement du fichier: {str(e)}"
        )

@app.post("/task/{task_id}")
async def get_task_status(task_id: str):
    """
    Récupère l'état d'une tâche de traitement.
    
    Args:
        task_id: L'identifiant de la tâche
        
    Returns:
        L'état actuel de la tâche
    """
    if task_id not in processing_tasks:
        raise HTTPException(
            status_code=404,
            detail=f"Tâche {task_id} non trouvée"
        )
    
    task_info = processing_tasks[task_id]
    
    # Si la tâche est terminée et a un résultat, inclure le résultat
    if task_info["status"] == "completed" and task_info["result"]:
        return {
            "task_id": task_id,
            "status": task_info["status"],
            "filename": task_info["filename"],
            "progress": 100,
            "processing_time": time.time() - task_info["start_time"],
            "result": task_info["result"]
        }
    
    # Si la tâche est en erreur, inclure l'erreur
    if task_info["status"] == "error":
        return {
            "task_id": task_id,
            "status": task_info["status"],
            "filename": task_info["filename"],
            "progress": task_info["progress"],
            "error": task_info["error"]
        }
    
    # Sinon, retourner l'état actuel
    return {
        "task_id": task_id,
        "status": task_info["status"],
        "filename": task_info["filename"],
        "progress": task_info["progress"],
        "processing_time": time.time() - task_info["start_time"]
    }

def get_text_from_layout(layout, text):
    """
    Extrait le texte à partir d'un layout Document AI.
    
    Args:
        layout: Le layout contenant les indices de texte
        text: Le texte complet du document
        
    Returns:
        Le texte extrait
    """
    if layout.text_anchor.text_segments:
        return "".join(
            text[segment.start_index:segment.end_index]
            for segment in layout.text_anchor.text_segments
        )
    return ""

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8001, reload=True)
