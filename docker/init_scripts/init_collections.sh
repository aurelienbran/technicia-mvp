#!/bin/bash
# Script d'initialisation des collections Qdrant
# A exécuter après le démarrage de Qdrant

set -e

echo "Attente du démarrage complet de Qdrant..."
# Attendre que Qdrant soit disponible
max_attempts=30
counter=0
while ! curl -s http://qdrant:6333/collections > /dev/null 2>&1; do
    counter=$((counter+1))
    if [ $counter -eq $max_attempts ]; then
        echo "Qdrant n'est pas disponible après $max_attempts tentatives. Abandon."
        exit 1
    fi
    echo "Qdrant n'est pas encore disponible. Tentative $counter/$max_attempts..."
    sleep 2
done

echo "Qdrant est disponible. Initialisation des collections..."

# Exécuter le script Python d'initialisation
python3 /app/scripts/init_qdrant.py

echo "Initialisation des collections terminée."
