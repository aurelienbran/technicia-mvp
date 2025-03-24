const axios = require('axios');
const fs = require('fs');
const FormData = require('form-data');
const path = require('path');

// Configuration
const config = {
  baseUrl: process.env.API_URL || 'http://localhost:80',
  uploadEndpoint: '/api/upload',
  testPdfPath: path.join(__dirname, '../samples/test_doc.pdf'),
  timeout: 60000 // 60 secondes
};

// Fonction principale de test
async function testUploadWorkflow() {
  console.log('=== Test du workflow d\'upload de document ===');
  
  try {
    // Vérifier que le fichier de test existe
    if (!fs.existsSync(config.testPdfPath)) {
      throw new Error(`Fichier de test introuvable: ${config.testPdfPath}`);
    }
    
    console.log(`Utilisation du fichier: ${config.testPdfPath}`);
    
    // Préparation du FormData avec le fichier
    const formData = new FormData();
    formData.append('file', fs.createReadStream(config.testPdfPath));
    
    // Afficher la taille du fichier
    const stats = fs.statSync(config.testPdfPath);
    console.log(`Taille du fichier: ${(stats.size / 1024).toFixed(2)} KB`);
    
    // Envoyer la requête
    console.log(`Envoi du fichier à ${config.baseUrl}${config.uploadEndpoint}...`);
    const startTime = Date.now();
    
    const response = await axios.post(`${config.baseUrl}${config.uploadEndpoint}`, formData, {
      headers: {
        ...formData.getHeaders()
      },
      timeout: config.timeout
    });
    
    const endTime = Date.now();
    const duration = (endTime - startTime) / 1000;
    
    // Vérification des résultats
    console.log(`Status de la réponse: ${response.status}`);
    console.log(`Durée: ${duration.toFixed(2)} secondes`);
    
    if (response.status === 200) {
      console.log('Réponse du serveur:', JSON.stringify(response.data, null, 2));
      console.log('✅ Test réussi: Le document a été téléversé et traité avec succès');
      
      // Vérification des données de la réponse
      const data = response.data;
      if (data.success && data.document_name && data.text_chunks_count > 0) {
        console.log(`Nombre de fragments de texte extraits: ${data.text_chunks_count}`);
        console.log(`Nombre d'images/schémas extraits: ${data.images_count}`);
      } else {
        console.warn('⚠️ La réponse est valide mais le format n\'est pas celui attendu');
      }
    } else {
      console.error('❌ Test échoué: Status de réponse inattendu');
    }
  } catch (error) {
    console.error('❌ Test échoué:', error.message);
    
    if (error.response) {
      console.error('Détails de la réponse:', {
        status: error.response.status,
        data: error.response.data
      });
    }
  }
}

// Exécution du test
testUploadWorkflow().catch(console.error);
