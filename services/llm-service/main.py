import os
import time
import json
import logging
from typing import List, Dict, Any, Optional
from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from dotenv import load_dotenv
from cachetools import TTLCache
import anthropic
import openai

# Configuration des logs
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler()]
)
logger = logging.getLogger("llm-service")

# Chargement des variables d'environnement
load_dotenv()

# Initialisation du cache pour les réponses
# 1000 items, expiration après 1 heure
response_cache = TTLCache(maxsize=1000, ttl=3600)

# Initialisation de l'application FastAPI
app = FastAPI(
    title="TechnicIA LLM Service",
    description="Service de gestion des interactions avec les modèles de langage pour TechnicIA",
    version="1.0.0"
)

# Activation du CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Modèles de données
class Message(BaseModel):
    role: str = Field(..., example="user")
    content: str = Field(..., example="Comment fonctionne le circuit hydraulique?")

class GenerateRequest(BaseModel):
    system: str = Field(..., example="Tu es un assistant technique spécialisé...")
    messages: List[Message]
    model: Optional[str] = Field(None, example="claude-3-5-sonnet-20240620")
    temperature: Optional[float] = Field(0.2, ge=0, le=1)
    max_tokens: Optional[int] = Field(2000, ge=1, le=4096)
    provider: Optional[str] = Field("anthropic", example="anthropic")
    cache: Optional[bool] = Field(True)

class GenerateResponse(BaseModel):
    content: str
    model: str
    usage: Dict[str, Any]
    cached: bool = False
    provider: str
    processing_time: float

# Fonction pour initialiser les clients LLM
def get_anthropic_client():
    api_key = os.getenv("ANTHROPIC_API_KEY")
    if not api_key:
        raise ValueError("ANTHROPIC_API_KEY non définie")
    return anthropic.Anthropic(api_key=api_key)

def get_openai_client():
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise ValueError("OPENAI_API_KEY non définie")
    return openai.OpenAI(api_key=api_key)

# Endpoints
@app.get("/health")
def health_check():
    """Vérifie l'état du service"""
    providers = []
    
    # Vérifier Anthropic
    if os.getenv("ANTHROPIC_API_KEY"):
        providers.append("anthropic")
    
    # Vérifier OpenAI
    if os.getenv("OPENAI_API_KEY"):
        providers.append("openai")
    
    if not providers:
        return {
            "status": "degraded",
            "message": "Aucun fournisseur LLM configuré"
        }
    
    return {
        "status": "operational",
        "providers": providers,
        "timestamp": time.time()
    }

@app.post("/generate", response_model=GenerateResponse)
def generate_response(request: GenerateRequest):
    """
    Génère une réponse à partir du LLM spécifié avec le contexte fourni
    """
    start_time = time.time()
    
    # Génération d'une clé de cache basée sur la requête
    if request.cache:
        cache_key = json.dumps({
            "system": request.system,
            "messages": [{"role": m.role, "content": m.content} for m in request.messages],
            "model": request.model,
            "temperature": request.temperature,
            "provider": request.provider
        })
        
        # Vérification du cache
        if cache_key in response_cache:
            cached_response = response_cache[cache_key]
            cached_response["cached"] = True
            cached_response["processing_time"] = time.time() - start_time
            return cached_response
    
    # Configuration du modèle par défaut selon le fournisseur
    provider = request.provider.lower() if request.provider else "anthropic"
    
    if provider == "anthropic":
        default_model = os.getenv("CLAUDE_MODEL", "claude-3-5-sonnet-20240620")
        model = request.model or default_model
        response = generate_with_anthropic(request.system, request.messages, model, request.temperature, request.max_tokens)
        provider_name = "anthropic"
    elif provider == "openai":
        default_model = os.getenv("OPENAI_MODEL", "gpt-4")
        model = request.model or default_model
        response = generate_with_openai(request.system, request.messages, model, request.temperature, request.max_tokens)
        provider_name = "openai"
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Fournisseur LLM non supporté: {provider}"
        )
    
    # Formatage de la réponse
    result = {
        "content": response["content"],
        "model": response["model"],
        "usage": response["usage"],
        "cached": False,
        "provider": provider_name,
        "processing_time": time.time() - start_time
    }
    
    # Mise en cache si activé
    if request.cache:
        response_cache[cache_key] = result
    
    return result

def generate_with_anthropic(system: str, messages: List[Message], model: str, temperature: float, max_tokens: int):
    """Génère une réponse avec l'API Anthropic Claude"""
    try:
        client = get_anthropic_client()
        
        # Formatage des messages pour l'API Anthropic
        formatted_messages = [{"role": m.role, "content": m.content} for m in messages]
        
        # Appel à l'API
        response = client.messages.create(
            model=model,
            system=system,
            messages=formatted_messages,
            temperature=temperature,
            max_tokens=max_tokens
        )
        
        # Extraction du contenu de la réponse
        content = response.content[0].text if response.content else ""
        
        return {
            "content": content,
            "model": model,
            "usage": {
                "input_tokens": response.usage.input_tokens,
                "output_tokens": response.usage.output_tokens
            }
        }
    except Exception as e:
        logger.error(f"Erreur lors de l'appel à Anthropic: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Erreur lors de l'appel à l'API Anthropic: {str(e)}"
        )

def generate_with_openai(system: str, messages: List[Message], model: str, temperature: float, max_tokens: int):
    """Génère une réponse avec l'API OpenAI"""
    try:
        client = get_openai_client()
        
        # Formatage des messages pour l'API OpenAI
        formatted_messages = [{"role": "system", "content": system}]
        formatted_messages.extend([{"role": m.role, "content": m.content} for m in messages])
        
        # Appel à l'API
        response = client.chat.completions.create(
            model=model,
            messages=formatted_messages,
            temperature=temperature,
            max_tokens=max_tokens
        )
        
        # Extraction du contenu de la réponse
        content = response.choices[0].message.content if response.choices else ""
        
        return {
            "content": content,
            "model": model,
            "usage": {
                "input_tokens": response.usage.prompt_tokens,
                "output_tokens": response.usage.completion_tokens
            }
        }
    except Exception as e:
        logger.error(f"Erreur lors de l'appel à OpenAI: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Erreur lors de l'appel à l'API OpenAI: {str(e)}"
        )

# Endpoint pour l'aide sur la configuration des systèmes prompts
@app.get("/prompts/templates")
def get_prompt_templates():
    """Renvoie des templates prédéfinis de system prompts pour différents cas d'usage"""
    return {
        "templates": [
            {
                "name": "question_answering",
                "description": "Template pour répondre à des questions basées sur un contexte",
                "template": "Tu es TechnicIA, un assistant de maintenance technique spécialisé dans l'analyse de documentation technique industrielle. Tu dois répondre aux questions en te basant uniquement sur le contexte fourni, qui contient des extraits de documentation et des références à des schémas techniques.\n\nInstructions spécifiques:\n- Utilise uniquement les informations dans le CONTEXTE fourni\n- Si le contexte ne contient pas l'information demandée, indique-le clairement\n- Cite les numéros de page des sources quand c'est pertinent\n- Quand tu mentionnes un schéma, réfère-toi au numéro du SCHÉMA ([SCHÉMA X])\n- Présente les informations techniques de manière claire et précise\n- Adapte ton niveau de détail technique à la question posée"
            },
            {
                "name": "diagnostic",
                "description": "Template pour créer un plan de diagnostic technique",
                "template": "Tu es TechnicIA, un assistant de diagnostic technique pour les équipements industriels. Tu dois créer un plan de diagnostic structuré en étapes, basé sur les symptômes initiaux et le contexte fourni. Ce plan sera utilisé pour guider un technicien dans un processus de diagnostic pas à pas.\n\nTon plan de diagnostic doit :\n\n1. Comprendre entre 5 et 7 étapes logiques\n2. Suivre une approche méthodique d'élimination des causes\n3. Aller du plus probable au moins probable\n4. Inclure pour chaque étape :\n   - Un titre court descriptif\n   - Une description détaillée de ce qu'il faut vérifier\n   - Des instructions précises pour les tests à effectuer\n   - Les résultats attendus (normal vs. anormal)\n   - Une question spécifique à poser au technicien"
            },
            {
                "name": "maintenance_procedure",
                "description": "Template pour générer des procédures de maintenance",
                "template": "Tu es TechnicIA, un expert en maintenance industrielle. À partir du contexte fourni, génère une procédure de maintenance détaillée et structurée. La procédure doit être précise, suivre les recommandations du fabricant, et inclure les précautions de sécurité nécessaires.\n\nLa procédure doit inclure:\n1. Outils et équipements nécessaires\n2. Équipements de protection individuelle requis\n3. Étapes préliminaires (mise hors tension, etc.)\n4. Procédure pas à pas numérotée\n5. Tests de validation après intervention\n6. Remarques et avertissements importants"
            }
        ]
    }

# Point d'entrée principal
if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("LLM_SERVICE_PORT", "8004"))
    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=True)
