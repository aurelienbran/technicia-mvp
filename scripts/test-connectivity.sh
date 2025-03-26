#!/bin/bash

# Script de test de connectivité pour TechnicIA MVP
# Ce script vérifie la connectivité entre les différents services du projet

echo "=== TechnicIA - Test de connectivité ==="
echo ""

# Tester NGINX
echo "Vérification de NGINX..."
if curl -s -o /dev/null -w "%{http_code}" http://localhost:80 > /dev/null; then
  echo "✅ NGINX est opérationnel sur le port 80"
else
  echo "❌ NGINX n'est pas accessible sur le port 80"
fi

# Tester n8n
echo ""
echo "Vérification de n8n..."
if curl -s -o /dev/null -w "%{http_code}" http://localhost:5678 > /dev/null; then
  echo "✅ n8n est opérationnel sur le port 5678"
else
  echo "❌ n8n n'est pas accessible sur le port 5678"
fi

# Tester le webhook d'upload
echo ""
echo "Vérification du webhook d'upload..."
if curl -s -o /dev/null -w "%{http_code}" http://localhost:5678/webhook/upload -F "test=true" > /dev/null; then
  echo "✅ Le webhook d'upload répond sur /webhook/upload"
else
  echo "❌ Le webhook d'upload n'est pas accessible sur /webhook/upload"
fi

# Tester la redirection NGINX pour /api/upload
echo ""
echo "Vérification de la redirection NGINX pour /api/upload..."
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/api/upload -F "test=true")
if [ "$RESPONSE" = "200" ] || [ "$RESPONSE" = "400" ]; then
  echo "✅ La redirection de /api/upload vers webhook fonctionne ($RESPONSE)"
else
  echo "❌ La redirection de /api/upload ne fonctionne pas (code $RESPONSE)"
fi

# Tester le microserveur document-processor
echo ""
echo "Vérification du microserveur document-processor..."
if curl -s -o /dev/null -w "%{http_code}" http://technicia-document-processor:8000/health > /dev/null; then
  echo "✅ Le microserveur document-processor est opérationnel sur le port 8000"
else
  echo "❌ Le microserveur document-processor n'est pas accessible"
  
  # Tester depuis n8n
  echo "   Tentative de test de connexion depuis n8n..."
  RESPONSE=$(curl -s http://localhost:5678/webhook/test-processor -F "test=true")
  echo "   Réponse de n8n: $RESPONSE"
fi

echo ""
echo "Tests terminés."
echo "Si des problèmes ont été détectés, vérifiez que tous les services sont démarrés et correctement configurés."
