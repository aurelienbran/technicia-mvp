FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Set environment variables
ENV PORT=8004 \
    ANTHROPIC_API_KEY="" \
    CLAUDE_MODEL="claude-3-5-sonnet-20240620" \
    OPENAI_API_KEY="" \
    OPENAI_MODEL="gpt-4o"

# Expose port for API
EXPOSE ${PORT}

# Start the application
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8004"]
