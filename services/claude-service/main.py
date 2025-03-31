"""
Service d'interaction avec l'API Claude d'Anthropic pour TechnicIA.
Fournit une couche d'abstraction robuste pour les appels à Claude avec gestion d'erreurs avancée.
"""
from fastapi import FastAPI, HTTPException, Body
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.openapi.utils import get_openapi
import httpx
import os
import logging
import json
import time
from typing import Dict, List, Any, Optional, Union
from pydantic import BaseModel, Field
from tenacity import retry, stop_after_attempt, wait_exponential, retry_if_exception_type

# Configuration du logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Configuration de l'application
app = FastAPI(
    title="Claude Service",
    description="Service d'interaction avec l'API Claude d'Anthropic pour TechnicIA",
    version="1.0.0"
)

# Configuration CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Configuration Anthropic
ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY")
ANTHROPIC_MODEL = os.getenv("ANTHROPIC_MODEL", "claude-3-5-sonnet-20240620")
ANTHROPIC_BASE_URL = "https://api.anthropic.com/v1"

# Modèles Pydantic pour la validation des données
class Message(BaseModel):
    role: str = Field(..., description="Rôle du message (user ou assistant)")
    content: str = Field(..., description="Contenu du message")

class CompletionRequest(BaseModel):
    system: Optional[str] = Field(None, description="Instructions système pour Claude")
    messages: List[Message] = Field(..., description="Liste des messages dans la conversation")
    model: Optional[str] = Field(ANTHROPIC_MODEL, description="Modèle Claude à utiliser")
    max_tokens: Optional[int] = Field(4000, description="Nombre maximum de tokens pour la réponse")
    temperature: Optional[float] = Field(0.2, description="Température pour la génération de texte")
    stream: Optional[bool] = Field(False, description="Mode streaming")

class CompletionWithPromptRequest(BaseModel):
    system_prompt: str = Field(..., description="Instructions système pour Claude")
    context: str = Field(..., description="Contexte à fournir à Claude")
    question: str = Field(..., description="Question utilisateur")
    model: Optional[str] = Field(ANTHROPIC_MODEL, description="Modèle Claude à utiliser")
    max_tokens: Optional[int] = Field(4000, description="Nombre maximum de tokens pour la réponse")
    temperature: Optional[float] = Field(0.2, description="Température pour la génération de texte")

class DiagnosticPlanRequest(BaseModel):
    system_prompt: str = Field(..., description="Instructions système pour Claude")
    equipment_type: str = Field(..., description="Type d'équipement")
    initial_symptoms: str = Field(..., description="Symptômes initiaux")
    context: str = Field(..., description="Contexte technique")
    model: Optional[str] = Field(ANTHROPIC_MODEL, description="Modèle Claude à utiliser")
    max_tokens: Optional[int] = Field(4000, description="Nombre maximum de tokens pour la réponse")
    temperature: Optional[float] = Field(0.1, description="Température pour la génération de texte")

class DiagnosisReportRequest(BaseModel):
    system_prompt: str = Field(..., description="Instructions système pour Claude")
    equipment_type: str = Field(..., description="Type d'équipement")
    initial_symptoms: str = Field(..., description="Symptômes initiaux")
    collected_data: Dict[str, Any] = Field(..., description="Données recueillies pendant le diagnostic")
    context: str = Field(..., description="Contexte technique")
    steps: List[Dict[str, Any]] = Field(..., description="Étapes du diagnostic")
    model: Optional[str] = Field(ANTHROPIC_MODEL, description="Modèle Claude à utiliser")
    max_tokens: Optional[int] = Field(4000, description="Nombre maximum de tokens pour la réponse")
    temperature: Optional[float] = Field(0.1, description="Température pour la génération de texte")

class ClaudeService:
    """Service d'interaction avec l'API Claude d'Anthropic."""
    
    def __init__(self, api_key: str, base_url: str, default_model: str):
        """
        Initialise le service Claude.
        
        Args:
            api_key: Clé API Anthropic
            base_url: URL de base de l'API
            default_model: Modèle par défaut à utiliser
        """
        self.api_key = api_key
        self.base_url = base_url
        self.default_model = default_model
        
        if not self.api_key:
            logger.error("Clé API Anthropic non configurée")
    
    @retry(
        retry=retry_if_exception_type((httpx.HTTPError, httpx.TimeoutException)),
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=2, max=10),
        reraise=True
    )
    async def _call_claude_api(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        """
        Appelle l'API Claude avec gestion de retry.
        
        Args:
            payload: Charge utile de la requête
            
        Returns:
            Réponse de l'API
        """
        if not self.api_key:
            raise HTTPException(
                status_code=500,
                detail="Clé API Anthropic non configurée"
            )
        
        try:
            start_time = time.time()
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    f"{self.base_url}/messages",
                    headers={
                        "x-api-key": self.api_key,
                        "Content-Type": "application/json",
                        "anthropic-version": "2023-06-01"
                    },
                    json=payload,
                    timeout=60.0  # Timeout plus long pour les réponses complexes
                )
                
                if response.status_code != 200:
                    logger.error(f"Erreur API Claude: {response.text}")
                    raise HTTPException(
                        status_code=response.status_code,
                        detail=f"Erreur API Claude: {response.text}"
                    )
                
                processing_time = time.time() - start_time
                response_data = response.json()
                
                # Ajouter des métriques de performance
                response_data["metrics"] = {
                    "processing_time_seconds": processing_time
                }
                
                return response_data
        except httpx.HTTPError as e:
            logger.error(f"Erreur HTTP lors de l'appel à Claude: {str(e)}")
            raise
        except Exception as e:
            logger.error(f"Erreur lors de l'appel à Claude: {str(e)}")
            raise HTTPException(
                status_code=500,
                detail=f"Erreur lors de l'appel à Claude: {str(e)}"
            )
    
    async def complete(self, request: CompletionRequest) -> Dict[str, Any]:
        """
        Génère une complétion avec Claude.
        
        Args:
            request: Paramètres de la requête
            
        Returns:
            Réponse de Claude
        """
        try:
            payload = {
                "model": request.model or self.default_model,
                "max_tokens": request.max_tokens,
                "temperature": request.temperature,
                "messages": [{"role": msg.role, "content": msg.content} for msg in request.messages]
            }
            
            if request.system:
                payload["system"] = request.system
            
            response = await self._call_claude_api(payload)
            return response
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Erreur lors de la génération de complétion: {str(e)}")
            raise HTTPException(
                status_code=500,
                detail=f"Erreur lors de la génération de complétion: {str(e)}"
            )
    
    async def question_answering(self, request: CompletionWithPromptRequest) -> Dict[str, Any]:
        """
        Génère une réponse à une question avec contexte.
        
        Args:
            request: Paramètres de la requête
            
        Returns:
            Réponse de Claude
        """
        try:
            messages = [
                {
                    "role": "user",
                    "content": f"{request.context}\n\nQUESTION:\n{request.question}"
                }
            ]
            
            payload = {
                "model": request.model or self.default_model,
                "max_tokens": request.max_tokens,
                "temperature": request.temperature,
                "system": request.system_prompt,
                "messages": messages
            }
            
            response = await self._call_claude_api(payload)
            return response
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Erreur lors de la génération de réponse: {str(e)}")
            raise HTTPException(
                status_code=500,
                detail=f"Erreur lors de la génération de réponse: {str(e)}"
            )
    
    async def generate_diagnostic_plan(self, request: DiagnosticPlanRequest) -> Dict[str, Any]:
        """
        Génère un plan de diagnostic.
        
        Args:
            request: Paramètres de la requête
            
        Returns:
            Plan de diagnostic
        """
        try:
            message_content = (
                f"Je dois diagnostiquer un problème sur un équipement de type {request.equipment_type} "
                f"avec les symptômes suivants :\n\n"
                f"{request.initial_symptoms}\n\n"
                f"Voici le contexte extrait de la documentation technique :\n\n"
                f"{request.context}\n\n"
                f"Crée un plan de diagnostic structuré pour m'aider à identifier et résoudre ce problème."
            )
            
            messages = [{"role": "user", "content": message_content}]
            
            payload = {
                "model": request.model or self.default_model,
                "max_tokens": request.max_tokens,
                "temperature": request.temperature,
                "system": request.system_prompt,
                "messages": messages
            }
            
            response = await self._call_claude_api(payload)
            return response
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Erreur lors de la génération du plan de diagnostic: {str(e)}")
            raise HTTPException(
                status_code=500,
                detail=f"Erreur lors de la génération du plan de diagnostic: {str(e)}"
            )
    
    async def generate_diagnosis_report(self, request: DiagnosisReportRequest) -> Dict[str, Any]:
        """
        Génère un rapport de diagnostic.
        
        Args:
            request: Paramètres de la requête
            
        Returns:
            Rapport de diagnostic
        """
        try:
            # Formatage des données recueillies
            collected_data_formatted = ""
            for key, value in request.collected_data.items():
                step_number = key.replace('step', '')
                step_info = next((s for s in request.steps if s.get("stepNumber") == int(step_number)), None)
                
                if step_info:
                    collected_data_formatted += f"\nÉtape {step_number} - {step_info.get('title')}:\n"
                    collected_data_formatted += f"Question: {step_info.get('question')}\n"
                    collected_data_formatted += f"Réponse: {value.get('response')}\n"
                    
                    if value.get('notes'):
                        collected_data_formatted += f"Notes: {value.get('notes')}\n"
            
            message_content = (
                f"Génère un rapport de diagnostic technique complet basé sur les informations suivantes :\n\n"
                f"Équipement : {request.equipment_type}\n"
                f"Symptômes initiaux : {request.initial_symptoms}\n\n"
                f"Données recueillies durant le diagnostic :\n{collected_data_formatted}\n\n"
                f"Contexte technique (documentation) :\n{request.context}\n\n"
                f"Prépare un rapport de diagnostic complet avec analyse des causes et recommandations."
            )
            
            messages = [{"role": "user", "content": message_content}]
            
            payload = {
                "model": request.model or self.default_model,
                "max_tokens": request.max_tokens,
                "temperature": request.temperature,
                "system": request.system_prompt,
                "messages": messages
            }
            
            response = await self._call_claude_api(payload)
            return response
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"Erreur lors de la génération du rapport de diagnostic: {str(e)}")
            raise HTTPException(
                status_code=500,
                detail=f"Erreur lors de la génération du rapport de diagnostic: {str(e)}"
            )

# Personnalisation du schéma OpenAPI
def custom_openapi():
    if app.openapi_schema:
        return app.openapi_schema
    
    openapi_schema = get_openapi(
        title="TechnicIA Claude Service API",
        version="1.0.0",
        description="Service d'interaction avec l'API Claude (Anthropic) pour TechnicIA",
        routes=app.routes,
    )
    
    # Charger le schéma OpenAPI personnalisé si le fichier existe
    schema_path = os.path.join(os.path.dirname(__file__), "openapi.yaml")
    if os.path.exists(schema_path):
        try:
            import yaml
            with open(schema_path, 'r') as f:
                openapi_schema = yaml.safe_load(f)
                logger.info("Schéma OpenAPI personnalisé chargé depuis openapi.yaml")
        except Exception as e:
            logger.warning(f"Impossible de charger le schéma OpenAPI personnalisé: {e}")
    
    app.openapi_schema = openapi_schema
    return app.openapi_schema

app.openapi = custom_openapi

# Créer une instance du service
claude_service = ClaudeService(
    api_key=ANTHROPIC_API_KEY,
    base_url=ANTHROPIC_BASE_URL,
    default_model=ANTHROPIC_MODEL
)

@app.get("/health")
async def health_check():
    """Vérification de l'état du service."""
    try:
        return {
            "status": "healthy",
            "anthropic_api_configured": bool(ANTHROPIC_API_KEY),
            "model": ANTHROPIC_MODEL,
            "version": "1.0.0"
        }
    except Exception as e:
        logger.error(f"Erreur de santé: {str(e)}")
        return JSONResponse(
            status_code=500,
            content={"status": "error", "message": str(e)}
        )

@app.post("/v1/complete")
async def complete(request: CompletionRequest):
    """
    Génère une complétion avec Claude.
    
    Args:
        request: Paramètres de la requête
        
    Returns:
        Réponse de Claude
    """
    try:
        response = await claude_service.complete(request)
        return response
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erreur lors de la génération de complétion: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Erreur lors de la génération de complétion: {str(e)}"
        )

@app.post("/v1/question")
async def question_answering(request: CompletionWithPromptRequest):
    """
    Génère une réponse à une question avec contexte.
    
    Args:
        request: Paramètres de la requête
        
    Returns:
        Réponse de Claude
    """
    try:
        start_time = time.time()
        response = await claude_service.question_answering(request)
        
        # Ajouter des métriques de performance
        processing_time = time.time() - start_time
        
        return {
            **response,
            "metrics": {
                "processing_time_seconds": processing_time
            }
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erreur lors de la génération de réponse: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Erreur lors de la génération de réponse: {str(e)}"
        )

@app.post("/v1/diagnostic-plan")
async def generate_diagnostic_plan(request: DiagnosticPlanRequest):
    """
    Génère un plan de diagnostic.
    
    Args:
        request: Paramètres de la requête
        
    Returns:
        Plan de diagnostic
    """
    try:
        response = await claude_service.generate_diagnostic_plan(request)
        return response
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erreur lors de la génération du plan de diagnostic: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Erreur lors de la génération du plan de diagnostic: {str(e)}"
        )

@app.post("/v1/diagnosis-report")
async def generate_diagnosis_report(request: DiagnosisReportRequest):
    """
    Génère un rapport de diagnostic.
    
    Args:
        request: Paramètres de la requête
        
    Returns:
        Rapport de diagnostic
    """
    try:
        response = await claude_service.generate_diagnosis_report(request)
        return response
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erreur lors de la génération du rapport de diagnostic: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Erreur lors de la génération du rapport de diagnostic: {str(e)}"
        )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8004, reload=True)
