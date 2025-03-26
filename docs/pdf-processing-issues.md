# Guide de résolution des problèmes liés au traitement PDF

Ce document se concentre spécifiquement sur les problèmes liés au traitement des fichiers PDF dans TechnicIA et propose des solutions détaillées.

## Table des matières

1. [Problèmes lors du téléversement](#problèmes-lors-du-téléversement)
2. [Problèmes d'extraction de texte](#problèmes-dextraction-de-texte)
3. [Problèmes d'extraction d'images](#problèmes-dextraction-dimages)
4. [Problèmes de traitement des fichiers volumineux](#problèmes-de-traitement-des-fichiers-volumineux)
5. [Problèmes d'intégration avec Google Document AI](#problèmes-dintégration-avec-google-document-ai)
6. [Problèmes de performance](#problèmes-de-performance)
7. [Problèmes avec les contenus protégés](#problèmes-avec-les-contenus-protégés)
8. [Dépannage du workflow n8n](#dépannage-du-workflow-n8n)

## Problèmes lors du téléversement

### Webhook n'accepte pas le fichier PDF

**Symptôme**: Le téléversement échoue avec "Aucune donnée binaire reçue" ou une erreur similaire.

**Causes possibles**:
1. Mauvaise configuration du webhook n8n
2. Format multipart/form-data incorrect
3. Nom de champ de fichier incorrect

**Solutions**:
1. Vérifiez la configuration du webhook dans n8n:
   - Assurez-vous que la méthode HTTP est POST
   - Activez l'option "Binary Data" dans les paramètres du webhook
   - Définissez "Body Content Type" à "multipart-form-data"

2. Pour tester correctement l'upload avec curl:
   ```bash
   curl -X POST -F "file=@/chemin/vers/fichier.pdf" http://localhost:5678/webhook/upload
   ```

3. Si vous utilisez un formulaire HTML, assurez-vous que le champ file a bien l'attribut `name="file"` et que l'attribut `enctype="multipart/form-data"` est présent dans la balise form.

### Le fichier est rejeté

**Symptôme**: Le service renvoie une erreur indiquant que le fichier est rejeté.

**Causes possibles**:
1. Le fichier n'est pas un PDF valide
2. Le fichier dépasse la taille maximale autorisée
3. Le serveur n'a pas les permissions d'écriture dans le répertoire temporaire

**Solutions**:
1. Vérifiez le format du fichier:
   ```bash
   file votre_fichier.pdf
   ```
   La sortie devrait inclure "PDF document"

2. Pour les problèmes de taille:
   - Vérifiez la taille du fichier: `ls -lh votre_fichier.pdf`
   - Réduisez la taille du PDF avec des outils comme `ghostscript` si nécessaire:
     ```bash
     gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dPDFSETTINGS=/ebook -dNOPAUSE -dQUIET -dBATCH -sOutputFile=output.pdf input.pdf
     ```

3. Pour les problèmes de permissions:
   - Vérifiez que le répertoire temp existe et que l'utilisateur Docker a les droits d'écriture:
     ```bash
     docker exec -it technicia-document-processor mkdir -p /tmp/technicia && chmod 777 /tmp/technicia
     ```

## Problèmes d'extraction de texte

### Aucun texte n'est extrait

**Symptôme**: Le service renvoie des pages vides ou aucun contenu textuel.

**Causes possibles**:
1. Le PDF contient des images sans texte
2. Le PDF utilise des polices non standard ou incorporées
3. Document AI n'est pas correctement configuré

**Solutions**:
1. Vérifiez si le PDF contient du texte extractible:
   ```bash
   pdftotext votre_fichier.pdf - | grep .
   ```
   Si cette commande ne produit aucune sortie, le PDF ne contient probablement pas de texte extractible.

2. Configurez Document AI pour utiliser l'OCR:
   - Assurez-vous d'utiliser un processor Document AI qui supporte l'OCR
   - Vérifiez que l'OCR est activé dans la configuration

3. Pour les polices incorporées, essayez un outil de prétraitement comme `pdf2text` avant de soumettre à Document AI.

### Le texte extrait est incorrect ou incomplet

**Symptôme**: Le texte extrait ne correspond pas au contenu visible du PDF, contient des caractères étranges ou est incomplet.

**Causes possibles**:
1. Problèmes de reconnaissance des polices
2. PDF de mauvaise qualité
3. Mise en page complexe

**Solutions**:
1. Améliorez la qualité du PDF source si possible
2. Augmentez le niveau de détails dans les logs pour diagnostiquer:
   ```python
   logging.getLogger('google.cloud.documentai').setLevel(logging.DEBUG)
   ```
3. Testez avec le processeur OCR avancé de Document AI qui gère mieux les mises en page complexes

## Problèmes d'extraction d'images

### Les images ne sont pas extraites

**Symptôme**: Aucune image n'est extraite du PDF ou les images sont manquantes.

**Causes possibles**:
1. Document AI n'est pas configuré pour extraire les images
2. Les images sont dans un format non supporté
3. La qualité des images est trop basse pour être détectée

**Solutions**:
1. Activez l'extraction d'images dans Document AI:
   - Utilisez un processor qui supporte l'extraction d'images
   - Vérifiez les options d'extraction dans la configuration

2. Vérifiez que les images sont présentes dans le PDF:
   ```bash
   pdfimages -list votre_fichier.pdf
   ```

3. Pour certains PDF complexes, utilisez un outil dédié d'extraction:
   ```bash
   pdfimages -all votre_fichier.pdf prefix
   ```
   Puis traitez manuellement les images extraites.

### Images extraites de mauvaise qualité

**Symptôme**: Les images extraites sont de basse qualité, floues ou inutilisables.

**Causes possibles**:
1. Images de faible résolution dans le PDF original
2. Compression excessive des images dans le PDF
3. Format non optimal pour l'extraction

**Solutions**:
1. Si possible, utilisez un PDF source de meilleure qualité
2. Modifiez le code pour extraire les images à leur résolution originale:
   ```python
   # Extrait les images à résolution maximale
   for page in document.pages:
       for image in page.images:
           image_bytes = image.content
           # Sauvegarde avec la résolution originale
           with open(f"image_{image.image_id}.png", "wb") as f:
               f.write(image_bytes)
   ```

## Problèmes de traitement des fichiers volumineux

### Timeout lors du traitement

**Symptôme**: Le traitement de fichiers volumineux échoue avec une erreur de timeout.

**Causes possibles**:
1. Timeout HTTP trop court dans n8n
2. Ressources insuffisantes allouées au service document-processor
3. Document AI a des limitations de taille

**Solutions**:
1. Augmentez les timeouts dans n8n:
   - Dans le nœud HTTP Request, augmentez le timeout à 300000 (5 minutes) ou plus
   - Ajoutez un nœud Wait entre les appels pour donner plus de temps

2. Augmentez les ressources Docker:
   ```yaml
   # Dans docker-compose.yml
   services:
     document-processor:
       deploy:
         resources:
           limits:
             memory: 4G
             cpus: "2"
   ```

3. Pour les PDF extrêmement volumineux, divisez-les en plusieurs fichiers plus petits:
   ```bash
   pdfseparate input.pdf page-%d.pdf
   ```

### Erreur de mémoire insuffisante

**Symptôme**: Le service document-processor se termine avec une erreur "Out of memory" ou similaire.

**Causes possibles**:
1. Fichier PDF trop volumineux pour la RAM disponible
2. Fuites de mémoire dans le traitement
3. Limites de mémoire Docker trop basses

**Solutions**:
1. Augmentez la mémoire allouée au conteneur:
   ```yaml
   # Dans docker-compose.yml
   services:
     document-processor:
       deploy:
         resources:
           limits:
             memory: 4G
   ```

2. Implémentez un traitement par lots:
   ```python
   # Traitement par lots de pages
   batch_size = 10
   for i in range(0, doc.page_count, batch_size):
       batch_pages = doc.pages[i:i+batch_size]
       # Traiter le lot de pages
       process_batch(batch_pages)
   ```

3. Utilisez un stockage temporaire sur disque plutôt qu'en mémoire pour les données intermédiaires.

## Problèmes d'intégration avec Google Document AI

### Erreur d'authentification

**Symptôme**: Les appels à Document AI échouent avec des erreurs d'authentification.

**Causes possibles**:
1. Fichier de credentials manquant ou incorrect
2. Permissions insuffisantes pour le compte de service
3. Projet Google Cloud mal configuré

**Solutions**:
1. Vérifiez le fichier de credentials:
   ```bash
   docker exec -it technicia-document-processor cat /app/credentials/google-credentials.json
   ```
   Assurez-vous que le fichier existe et qu'il est valide.

2. Vérifiez que le compte de service a les rôles appropriés:
   - `roles/documentai.user`
   - `roles/documentai.editor`

3. Assurez-vous que l'API Document AI est activée:
   ```bash
   gcloud services enable documentai.googleapis.com
   ```

### Processor Document AI non trouvé

**Symptôme**: Erreur indiquant que le processor Document AI n'existe pas ou n'est pas accessible.

**Causes possibles**:
1. ID de processor incorrect
2. Processor supprimé ou désactivé
3. Projet ou région mal configurés

**Solutions**:
1. Vérifiez l'ID du processor et la région:
   ```bash
   gcloud documentai processors list --project=VOTRE_PROJET --region=VOTRE_REGION
   ```

2. Créez un nouveau processor si nécessaire:
   ```bash
   gcloud documentai processors create \
     --project=VOTRE_PROJET \
     --region=VOTRE_REGION \
     --display-name="TechnicIA PDF Processor" \
     --type=DOCUMENT_PROCESSOR_TYPE
   ```

3. Mettez à jour les variables d'environnement dans docker-compose.yml avec les valeurs correctes.

## Problèmes de performance

### Traitement PDF lent

**Symptôme**: Le traitement des PDF prend beaucoup plus de temps que prévu.

**Causes possibles**:
1. Document AI est lent pour les fichiers complexes
2. Images nombreuses ou de haute résolution
3. Réseau lent ou limitations d'API

**Solutions**:
1. Parallélisez le traitement des pages ou des sections:
   ```python
   from concurrent.futures import ThreadPoolExecutor
   
   def process_page(page):
       # Code de traitement d'une page
       return result
   
   with ThreadPoolExecutor(max_workers=4) as executor:
       results = list(executor.map(process_page, document.pages))
   ```

2. Optimisez les PDF avant de les traiter:
   ```bash
   gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dPDFSETTINGS=/default -dNOPAUSE -dQUIET -dBATCH -sOutputFile=optimized.pdf input.pdf
   ```

3. Utilisez des files d'attente pour le traitement asynchrone:
   - Implémentez un système de file d'attente comme RabbitMQ ou Redis
   - Traitez les documents en arrière-plan avec des workers dédiés

## Problèmes avec les contenus protégés

### PDF protégés par mot de passe

**Symptôme**: L'extraction échoue avec des erreurs d'accès ou le contenu extrait est vide.

**Causes possibles**:
1. PDF protégé par mot de passe
2. PDF avec restrictions de copie
3. DRM ou autres protections

**Solutions**:
1. Détectez les PDF protégés et informez l'utilisateur:
   ```python
   import fitz  # PyMuPDF
   
   def is_pdf_encrypted(pdf_path):
       try:
           doc = fitz.open(pdf_path)
           is_encrypted = doc.is_encrypted
           needs_password = doc.needs_password
           doc.close()
           return is_encrypted or needs_password
       except Exception:
           return True  # En cas de doute, considérer comme protégé
   ```

2. Si vous avez le mot de passe, déverrouillez le PDF avant traitement:
   ```python
   doc = fitz.open(pdf_path)
   if doc.is_encrypted:
       success = doc.authenticate(password)
       if not success:
           raise ValueError("Mot de passe incorrect")
   ```

3. Pour les PDF avec restrictions de copie sans mot de passe, envisagez des outils spécialisés comme `qpdf` ou `pikepdf` pour supprimer ces restrictions (si légalement autorisé).

## Dépannage du workflow n8n

### Échec lors de la lecture des propriétés binaires

**Symptôme**: Le workflow n8n échoue lors de l'accès aux propriétés binaires du fichier PDF.

**Causes possibles**:
1. Format incorrectement manipulé dans les nœuds Function
2. Perte des données binaires entre les étapes
3. Problème de transfert de données entre les services

**Solutions**:
1. Vérifiez le format des données binaires dans n8n:
   ```javascript
   // Nœud Function pour inspecter le contenu binaire
   console.log('Binary properties:', Object.keys($input.item.binary || {}));
   if ($input.item.binary) {
     const binaryKey = Object.keys($input.item.binary)[0];
     console.log('Binary key:', binaryKey);
     console.log('File name:', $input.item.binary[binaryKey].fileName);
     console.log('MIME type:', $input.item.binary[binaryKey].mimeType);
     console.log('File size:', $input.item.binary[binaryKey].fileSize);
   }
   return $input.item;
   ```

2. Utilisez des nœuds intermédiaires pour déboguer:
   - Ajoutez un nœud "Write Binary File" pour vérifier que le binaire est bien préservé
   - Ajoutez un nœud "HTTP Request" vers un service de débogage comme webhook.site

3. Examinez les journaux n8n en temps réel:
   ```bash
   docker logs -f technicia-n8n
   ```

### Les résultats du traitement ne sont pas transmis correctement

**Symptôme**: Le workflow n8n semble s'exécuter, mais les résultats du traitement ne sont pas disponibles dans les étapes suivantes.

**Causes possibles**:
1. Structure de données incompatible entre les services
2. Échec silencieux des appels d'API
3. Problème de passage de variables entre les nœuds n8n

**Solutions**:
1. Transformez explicitement les données entre les nœuds:
   ```javascript
   // Nœud Function pour normaliser les données
   const result = $input.item.json;
   const documentId = result.document_id || result.task_id || `doc-${Date.now()}`;
   
   return {
     document_id: documentId,
     text_content: result.document_data ? result.document_data.document_text : "",
     page_count: result.document_data ? result.document_data.page_count : 0,
     extracted_at: new Date().toISOString()
   };
   ```

2. Ajoutez des vérifications d'erreur explicites:
   ```javascript
   // Nœud Function pour vérifier les erreurs
   const data = $input.item.json;
   
   if (data.error || (data.status && data.status >= 400)) {
     console.error('Error detected:', data.error || data.message || JSON.stringify(data));
     return {
       success: false,
       error: data.error || data.message || "Unknown error",
       original_data: data
     };
   }
   
   return $input.item;
   ```

---

Si vous rencontrez des problèmes spécifiques non couverts par ce guide, consultez également:
- [Guide de débogage des microservices](microservices-debugging.md)
- [Guide de gestion des logs](log-management.md)
- [Guide de dépannage des webhooks](webhook-troubleshooting.md)
