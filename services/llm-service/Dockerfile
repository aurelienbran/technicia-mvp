FROM python:3.9-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Healthcheck pour le service
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:${LLM_SERVICE_PORT:-8005}/health || exit 1

# Exposition du port API
EXPOSE ${LLM_SERVICE_PORT:-8005}

CMD ["python", "app.py"]
