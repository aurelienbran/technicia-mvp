FROM python:3.9-slim

WORKDIR /app

# Installation des dépendances
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copie du code source
COPY . .

# Variables d'environnement par défaut
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8003 \
    QDRANT_HOST=qdrant \
    QDRANT_PORT=6333 \
    COLLECTION_NAME=technicia

# Exposition du port
EXPOSE 8003

# Commande de démarrage
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8003"]
