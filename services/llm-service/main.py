import os
import json
import time
from typing import Dict, List, Optional, Union, Any
from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from dotenv import load_dotenv
import anthropic
import openai
from tenacity import retry, stop_after_attempt, wait_exponential
from cachetools import TTLCache

# Load environment variables
load_dotenv()

# Configure API keys
ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY", "")
CLAUDE_MODEL = os.getenv("CLAUDE_MODEL", "claude-3-5-sonnet-20240620")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")
OPENAI_MODEL = os.getenv("OPENAI_MODEL", "gpt-4o")

# Initialize clients
anthropic_client = anthropic.Anthropic(api_key=ANTHROPIC_API_KEY) if ANTHROPIC_API_KEY else None
if OPENAI_API_KEY:
    openai.api_key = OPENAI_API_KEY

# Set up response cache (TTL: 1 hour)
cache = TTLCache(maxsize=1000, ttl=3600)

# Initialize FastAPI
app = FastAPI(
    title="TechnicIA LLM Service",
    description="API for generating responses from LLMs for TechnicIA assistant",
    version="1.0.0"
)

# Enable CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Define data models
class Message(BaseModel):
    role: str
    content: str

class ClaudeRequest(BaseModel):
    system: str
    messages: List[Message]
    model: str = CLAUDE_MODEL
    max_tokens: int = 4000
    temperature: float = 0.2
    cache_key: Optional[str] = None

class OpenAIRequest(BaseModel):
    system: str
    messages: List[Message]
    model: str = OPENAI_MODEL
    max_tokens: int = 4000
    temperature: float = 0.2
    cache_key: Optional[str] = None

class GenericLLMRequest(BaseModel):
    system: str
    messages: List[Dict[str, str]]
    model: str
    max_tokens: int = 4000
    temperature: float = 0.2
    provider: str = "anthropic"  # "anthropic" or "openai"
    cache_key: Optional[str] = None

class ResponseModel(BaseModel):
    content: str
    model: str
    provider: str
    tokens_used: Optional[int] = None
    processing_time: float
    cached: bool = False

# Helper function to generate cache key
def generate_cache_key(request_data):
    if request_data.cache_key:
        return request_data.cache_key
    
    # Create a deterministic string representation for caching
    key_data = {
        "system": request_data.system,
        "messages": [dict(m) for m in request_data.messages],
        "model": request_data.model,
        "temperature": request_data.temperature
    }
    return f"{hash(json.dumps(key_data, sort_keys=True))}"

# Claude API call with retry logic
@retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=2, max=10))
async def call_claude(request_data: ClaudeRequest):
    start_time = time.time()
    
    if not anthropic_client:
        raise HTTPException(status_code=500, detail="Anthropic API not configured")
    
    # Check cache
    cache_key = generate_cache_key(request_data)
    if cache_key in cache:
        cached_response = cache[cache_key]
        cached_response["processing_time"] = 0.01  # Negligible processing time for cached responses
        cached_response["cached"] = True
        return cached_response
    
    messages = [{"role": m.role, "content": m.content} for m in request_data.messages]
    
    try:
        response = anthropic_client.messages.create(
            model=request_data.model,
            system=request_data.system,
            messages=messages,
            max_tokens=request_data.max_tokens,
            temperature=request_data.temperature
        )
        
        result = {
            "content": response.content[0].text,
            "model": request_data.model,
            "provider": "anthropic",
            "tokens_used": response.usage.output_tokens + response.usage.input_tokens,
            "processing_time": time.time() - start_time,
            "cached": False
        }
        
        # Store in cache
        cache[cache_key] = result
        return result
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error calling Claude API: {str(e)}")

# OpenAI API call with retry logic
@retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=2, max=10))
async def call_openai(request_data: OpenAIRequest):
    start_time = time.time()
    
    if not OPENAI_API_KEY:
        raise HTTPException(status_code=500, detail="OpenAI API not configured")
    
    # Check cache
    cache_key = generate_cache_key(request_data)
    if cache_key in cache:
        cached_response = cache[cache_key]
        cached_response["processing_time"] = 0.01
        cached_response["cached"] = True
        return cached_response
    
    try:
        messages = [{"role": "system", "content": request_data.system}]
        messages.extend([{"role": m.role, "content": m.content} for m in request_data.messages])
        
        response = openai.ChatCompletion.create(
            model=request_data.model,
            messages=messages,
            max_tokens=request_data.max_tokens,
            temperature=request_data.temperature
        )
        
        result = {
            "content": response.choices[0].message.content,
            "model": request_data.model,
            "provider": "openai",
            "tokens_used": response.usage.total_tokens,
            "processing_time": time.time() - start_time,
            "cached": False
        }
        
        # Store in cache
        cache[cache_key] = result
        return result
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error calling OpenAI API: {str(e)}")

# Generic endpoint that can use either provider
@app.post("/api/generate", response_model=ResponseModel)
async def generate_response(request: GenericLLMRequest, background_tasks: BackgroundTasks):
    if request.provider.lower() == "anthropic":
        claude_request = ClaudeRequest(
            system=request.system,
            messages=[Message(role=m["role"], content=m["content"]) for m in request.messages],
            model=request.model,
            max_tokens=request.max_tokens,
            temperature=request.temperature,
            cache_key=request.cache_key
        )
        return await call_claude(claude_request)
    
    elif request.provider.lower() == "openai":
        openai_request = OpenAIRequest(
            system=request.system,
            messages=[Message(role=m["role"], content=m["content"]) for m in request.messages],
            model=request.model,
            max_tokens=request.max_tokens,
            temperature=request.temperature,
            cache_key=request.cache_key
        )
        return await call_openai(openai_request)
    
    else:
        raise HTTPException(status_code=400, detail=f"Unsupported provider: {request.provider}")

# Dedicated Claude endpoint
@app.post("/api/claude", response_model=ResponseModel)
async def claude_endpoint(request: ClaudeRequest):
    return await call_claude(request)

# Dedicated OpenAI endpoint
@app.post("/api/openai", response_model=ResponseModel)
async def openai_endpoint(request: OpenAIRequest):
    return await call_openai(request)

# Health check endpoint
@app.get("/health")
async def health_check():
    providers = []
    
    if ANTHROPIC_API_KEY:
        providers.append("anthropic")
    
    if OPENAI_API_KEY:
        providers.append("openai")
    
    if not providers:
        return {
            "status": "degraded",
            "message": "No LLM providers configured"
        }
    
    return {
        "status": "operational",
        "providers": providers,
        "default_models": {
            "anthropic": CLAUDE_MODEL,
            "openai": OPENAI_MODEL
        },
        "cache_size": len(cache),
        "timestamp": time.time()
    }

# Root endpoint with documentation info
@app.get("/")
async def root():
    return {
        "name": "TechnicIA LLM Service",
        "version": "1.0.0",
        "documentation": "/docs",
        "healthcheck": "/health"
    }

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8004))
    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=True)
