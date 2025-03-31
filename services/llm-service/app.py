import os
import json
import logging
import time
from typing import Dict, List, Optional, Union, Any

from fastapi import FastAPI, HTTPException, Request, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
import httpx
import uvicorn

# Configuration du logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler()]
)
logger = logging.getLogger(__name__)

# Modèles Pydantic
class ChatMessage(BaseModel):
    role: str
    content: str

class ChatRequest(BaseModel):
    system: Optional[str] = None
    messages: List[ChatMessage]
    model: Optional[str] = None
    temperature: Optional[float] = 0.2
    max_tokens: Optional[int] = 4000

class PromptRequest(BaseModel):
    prompt: str
    context: Optional[str] = None
    model: Optional[str] = None
    temperature: Optional[float] = 0.2
    max_tokens: Optional[int] = 4000

class HealthResponse(BaseModel):
    status: str
    version: str = "1.0.0"
    model: str

# Initialisation de l'application FastAPI
app = FastAPI(title="TechnicIA LLM Service", description="Service de génération de texte pour TechnicIA")

# Configuration CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Variables d'environnement
ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY")
CLAUDE_MODEL = os.getenv("CLAUDE_MODEL", "claude-3-5-sonnet-20240620")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
OPENAI_MODEL = os.getenv("OPENAI_MODEL", "gpt-4-turbo")

# Déterminer le LLM à utiliser
USE_CLAUDE = ANTHROPIC_API_KEY is not None
USE_OPENAI = not USE_CLAUDE and OPENAI_API_KEY is not None

if not (USE_CLAUDE or USE_OPENAI):
    logger.warning("Aucune clé API LLM n'a été trouvée. Le service fonctionnera en mode simulation.")

# Cache simple en mémoire pour les réponses (peut être remplacé par Redis dans une version production)
response_cache = {}

async def chat_with_claude(request: ChatRequest) -> Dict:
    """Fonction pour interagir avec l'API Claude d'Anthropic"""
    try:
        async with httpx.AsyncClient(timeout=60.0) as client:
            headers = {
                "x-api-key": ANTHROPIC_API_KEY,
                "anthropic-version": "2023-06-01",
                "content-type": "application/json",
            }

            # Format attendu par l'API Anthropic
            messages = [{"role": msg.role, "content": msg.content} for msg in request.messages]
            
            # Corps de la requête
            payload = {
                "model": request.model or CLAUDE_MODEL,
                "messages": messages,
                "max_tokens": request.max_tokens,
                "temperature": request.temperature,
            }
            
            # Ajout du system prompt si fourni
            if request.system:
                payload["system"] = request.system

            # Envoi de la requête
            response = await client.post(
                "https://api.anthropic.com/v1/messages",
                headers=headers,
                json=payload
            )
            
            response.raise_for_status()
            return response.json()
            
    except httpx.HTTPStatusError as e:
        logger.error(f"Erreur HTTP lors de l'appel à Claude: {e}")
        raise HTTPException(status_code=e.response.status_code, detail=str(e))
    except Exception as e:
        logger.error(f"Erreur lors de l'appel à Claude: {e}")
        raise HTTPException(status_code=500, detail=str(e))

async def chat_with_openai(request: ChatRequest) -> Dict:
    """Fonction pour interagir avec l'API OpenAI"""
    try:
        async with httpx.AsyncClient(timeout=60.0) as client:
            headers = {
                "Authorization": f"Bearer {OPENAI_API_KEY}",
                "Content-Type": "application/json",
            }
            
            # Format attendu par OpenAI
            messages = []
            if request.system:
                messages.append({"role": "system", "content": request.system})
            
            # Ajout des messages de la conversation
            for msg in request.messages:
                messages.append({"role": msg.role, "content": msg.content})
            
            # Corps de la requête
            payload = {
                "model": request.model or OPENAI_MODEL,
                "messages": messages,
                "max_tokens": request.max_tokens,
                "temperature": request.temperature,
            }
            
            # Envoi de la requête
            response = await client.post(
                "https://api.openai.com/v1/chat/completions",
                headers=headers,
                json=payload
            )
            
            response.raise_for_status()
            openai_response = response.json()
            
            # Conversion au format attendu par l'application (similaire à Claude)
            return {
                "content": [{"text": openai_response["choices"][0]["message"]["content"]}],
                "model": openai_response["model"],
                "usage": openai_response["usage"]
            }
            
    except httpx.HTTPStatusError as e:
        logger.error(f"Erreur HTTP lors de l'appel à OpenAI: {e}")
        raise HTTPException(status_code=e.response.status_code, detail=str(e))
    except Exception as e:
        logger.error(f"Erreur lors de l'appel à OpenAI: {e}")
        raise HTTPException(status_code=500, detail=str(e))

def format_prompt_with_context(prompt: str, context: Optional[str]) -> List[ChatMessage]:
    """Formater un prompt simple avec contexte optionnel en messages de chat"""
    messages = []
    
    if context:
        messages.append(ChatMessage(role="user", content=f"Contexte:\n{context}"))
    
    messages.append(ChatMessage(role="user", content=prompt))
    return messages

def generate_cache_key(request_data: Dict) -> str:
    """Génère une clé de cache unique pour une requête"""
    # Simplification pour l'exemple - une implémentation robuste utiliserait un hachage
    return json.dumps(request_data, sort_keys=True)

@app.post("/api/chat")
async def chat(request: ChatRequest, background_tasks: BackgroundTasks):
    """Endpoint pour les conversations au format chat"""
    # Cache check
    cache_key = generate_cache_key(request.dict())
    if cache_key in response_cache:
        logger.info("Réponse trouvée dans le cache")
        return response_cache[cache_key]
    
    try:
        if USE_CLAUDE:
            response = await chat_with_claude(request)
        elif USE_OPENAI:
            response = await chat_with_openai(request)
        else:
            # Mode simulation
            response = {
                "content": [{"text": f"Réponse simulée pour: {request.messages[-1].content[:100]}..."}],
                "model": "simulation",
            }
            time.sleep(1)  # Simuler un délai
        
        # Mettre en cache avec une durée de vie limitée
        response_cache[cache_key] = response
        background_tasks.add_task(lambda: response_cache.pop(cache_key, None) if time.time() > time.time() + 3600 else None)
        
        return response
        
    except Exception as e:
        logger.error(f"Erreur lors du traitement de la requête chat: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/prompt")
async def prompt(request: PromptRequest, background_tasks: BackgroundTasks):
    """Endpoint simplifié pour les requêtes avec prompt simple"""
    # Conversion en format de chat
    messages = format_prompt_with_context(request.prompt, request.context)
    
    # Création d'une requête de chat équivalente
    chat_request = ChatRequest(
        messages=messages,
        model=request.model,
        temperature=request.temperature,
        max_tokens=request.max_tokens
    )
    
    # Utilisation de l'endpoint de chat
    return await chat(chat_request, background_tasks)

@app.get("/health")
async def health_check():
    """Endpoint de vérification de santé du service"""
    if USE_CLAUDE:
        model = CLAUDE_MODEL
    elif USE_OPENAI:
        model = OPENAI_MODEL
    else:
        model = "simulation"
        
    return HealthResponse(status="operational", model=model)

if __name__ == "__main__":
    port = int(os.getenv("LLM_SERVICE_PORT", 8005))
    uvicorn.run("app:app", host="0.0.0.0", port=port, reload=True)
