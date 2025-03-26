"""
Service de traitement des documents PDF pour TechnicIA.
Utilise Google Document AI pour l'extraction de texte et la structuration du contenu.
"""
from fastapi import FastAPI, File, UploadFile, BackgroundTasks, HTTPException, Form, Request
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
        
        # Initialiser le client Document AI
        client = documentai.DocumentProcessorServiceClient()
        name = f"projects/{DOCUMENT_AI_PROJECT}/locations/{DOCUMENT_AI_LOCATION}/processors/{DOCUMENT_AI_PROCESSOR_ID}"
        
        # Lire le fichier PDF
        with open(temp_file_path, "rb") as f:
            content = f.read()
        
        # Préparer et envoyer la requête à Document AI
        document = documentai.RawDocument(content=content, mime_type="application/pdf")
        request = documentai.ProcessRequest(name=name, raw_document=document)
        
        # Traiter le document
        result = client.process_document(request=request)
        document = result.document
        
        # Extraire et structurer le texte
        text = document.text
        
        # Extraire les pages et paragraphes
        pages = []
        for page in document.pages:
            paragraphs = []
            for paragraph in page.paragraphs:
                para_text = get_text_from_layout(paragraph.layout, text)
                paragraphs.append({
                    "text": para_text,
                    "confidence": paragraph.layout.confidence
                })
            
            # Extraire les images de la page (simulation)
            images = []
            for image in page.image_detection_params:
                image_path = f"{TEMP_DIR}/{document_id}_page{page.page_number}_image{len(images)}.png"
                images.append({
                    "id": f"img-{uuid.uuid4()}",
                    "path": image_path,
                    "page_number": page.page_number
                })
            
            pages.append({
                "page_number": page.page_number,
                "paragraphs": paragraphs,
                "width": page.dimension.width,
                "height": page.dimension.height,
                "images": images
            })
        
        # Extraire les entités
        entities = []
        for entity in document.entities:
            entities.append({
                "type": entity.type,
                "mention_text": entity.mention_text,
                "confidence": entity.confidence
            })
        
        # Structurer le résultat
        structured_result = {
            "document_id": document_id,
            "document_text": text,
            "pages": pages,
            "entities": entities,
            "mime_type": document.mime_type,
            "page_count": len(document.pages),
            "images": [], # À remplacer par des images réelles extraites du document
            "filename": file.filename
        }
        
        # Nettoyer le fichier temporaire
        try:
            os.unlink(temp_file_path)
        except Exception as e:
            logger.warning(f"Erreur lors du nettoyage du fichier {temp_file_path}: {str(e)}")
        
        return structured_result
        
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

@app.post("/process-large-file")
async def process_large_file(
    file: UploadFile = File(...),
    background_tasks: BackgroundTasks = None
):
    """
    Traite un fichier PDF volumineux de manière asynchrone.
    
    Args:
        file: Le fichier PDF à traiter
        background_tasks: Tâches d'arrière-plan
        
    Returns:
        Un identifiant de tâche pour suivre le traitement
    """
    try:
        # Validation du type de fichier
        if not file.filename.lower().endswith('.pdf'):
            raise HTTPException(
                status_code=400,
                detail="Type de fichier non supporté. Seuls les fichiers PDF sont acceptés."
            )
        
        # Générer un ID de tâche unique
        task_id = str(uuid.uuid4())
        
        # Sauvegarder le fichier temporairement
        temp_file_path = TEMP_DIR / f"{task_id}_{file.filename}"
        
        with open(temp_file_path, "wb") as temp_file:
            content = await file.read()
            temp_file.write(content)
        
        # Initialiser l'état de la tâche
        processing_tasks[task_id] = {
            "status": "pending",
            "filename": file.filename,
            "file_path": str(temp_file_path),
            "start_time": time.time(),
            "progress": 0,
            "result": None,
            "error": None
        }
        
        # Lancer le traitement en arrière-plan
        if background_tasks:
            background_tasks.add_task(
                process_with_document_ai,
                task_id,
                str(temp_file_path)
            )
        else:
            # Pour les tests ou le débogage, démarrage immédiat
            asyncio.create_task(
                process_with_document_ai(task_id, str(temp_file_path))
            )
        
        return {
            "task_id": task_id,
            "status": "processing",
            "message": f"Traitement du fichier {file.filename} en cours"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erreur lors du traitement du fichier: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Erreur lors du traitement du fichier: {str(e)}"
        )

@app.get("/task/{task_id}")
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

@app.post("/debug-upload")
async def debug_upload(request: Request):
    """
    Endpoint de débogage pour tester l'upload de fichiers.
    Affiche tous les détails sur la requête reçue pour faciliter le débogage.
    """
    try:
        # Extraire les headers
        headers = dict(request.headers.items())
        
        # Essayer de parser le formulaire
        form_data = {}
        try:
            form = await request.form()
            for key in form:
                if hasattr(form[key], "filename"):  # C'est un fichier
                    form_data[key] = {
                        "filename": form[key].filename,
                        "content_type": form[key].content_type,
                        "size": len(await form[key].read())
                    }
                else:  # C'est une valeur standard
                    form_data[key] = form[key]
        except Exception as form_error:
            form_data = {"error": str(form_error)}
        
        # Essayer de lire le body brut
        body = None
        try:
            body = await request.body()
            body = f"Taille du corps: {len(body)} octets"
        except Exception as body_error:
            body = {"error": str(body_error)}
        
        # Produire un rapport de débogage
        debug_info = {
            "request_method": request.method,
            "url": str(request.url),
            "headers": headers,
            "form_data": form_data,
            "body": body,
            "client": request.client.host if request.client else None
        }
        
        return debug_info
        
    except Exception as e:
        logger.error(f"Erreur lors du débogage de l'upload: {str(e)}")
        return {
            "status": "error",
            "message": str(e)
        }

async def process_with_document_ai(task_id: str, file_path: str):
    """
    Traite un document avec Document AI.
    
    Args:
        task_id: L'identifiant de la tâche
        file_path: Le chemin vers le fichier PDF
    """
    try:
        # Mettre à jour l'état
        processing_tasks[task_id]["status"] = "processing"
        processing_tasks[task_id]["progress"] = 10
        
        # Initialiser le client Document AI
        client = documentai.DocumentProcessorServiceClient()
        name = f"projects/{DOCUMENT_AI_PROJECT}/locations/{DOCUMENT_AI_LOCATION}/processors/{DOCUMENT_AI_PROCESSOR_ID}"
        
        # Lire le fichier PDF
        with open(file_path, "rb") as f:
            content = f.read()
        
        # Mettre à jour l'état
        processing_tasks[task_id]["progress"] = 30
        
        # Préparer et envoyer la requête à Document AI
        document = documentai.RawDocument(content=content, mime_type="application/pdf")
        request = documentai.ProcessRequest(name=name, raw_document=document)
        
        # Traiter le document
        result = client.process_document(request=request)
        document = result.document
        
        # Mettre à jour l'état
        processing_tasks[task_id]["progress"] = 70
        
        # Extraire et structurer le texte
        text = document.text
        
        # Extraire les pages et paragraphes
        pages = []
        for page in document.pages:
            paragraphs = []
            for paragraph in page.paragraphs:
                para_text = get_text_from_layout(paragraph.layout, text)
                paragraphs.append({
                    "text": para_text,
                    "confidence": paragraph.layout.confidence
                })
            
            # Extraire les images de la page (simulation)
            images = []
            for i in range(2):  # Simulation de 2 images par page
                image_path = f"{TEMP_DIR}/{task_id}_page{page.page_number}_image{i}.png"
                images.append({
                    "id": f"img-{uuid.uuid4()}",
                    "path": image_path,
                    "page_number": page.page_number
                })
            
            pages.append({
                "page_number": page.page_number,
                "paragraphs": paragraphs,
                "width": page.dimension.width,
                "height": page.dimension.height,
                "images": images
            })
        
        # Extraire les entités
        entities = []
        for entity in document.entities:
            entities.append({
                "type": entity.type,
                "mention_text": entity.mention_text,
                "confidence": entity.confidence
            })
        
        # Structurer le résultat
        structured_result = {
            "document_text": text,
            "pages": pages,
            "entities": entities,
            "mime_type": document.mime_type,
            "page_count": len(document.pages),
            "images": [], # À remplacer par les images réelles extraites du document
            "processing_time": time.time() - processing_tasks[task_id]["start_time"]
        }
        
        # Mettre à jour l'état avec le résultat
        processing_tasks[task_id]["status"] = "completed"
        processing_tasks[task_id]["progress"] = 100
        processing_tasks[task_id]["result"] = structured_result
        
        # Nettoyer le fichier temporaire
        try:
            os.unlink(file_path)
        except Exception as e:
            logger.warning(f"Erreur lors du nettoyage du fichier {file_path}: {str(e)}")
        
    except Exception as e:
        logger.error(f"Erreur lors du traitement avec Document AI: {str(e)}")
        processing_tasks[task_id]["status"] = "error"
        processing_tasks[task_id]["error"] = str(e)
        
        # Nettoyer le fichier temporaire en cas d'erreur
        try:
            os.unlink(file_path)
        except Exception as cleanup_error:
            logger.warning(f"Erreur lors du nettoyage du fichier {file_path}: {str(cleanup_error)}")

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
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
