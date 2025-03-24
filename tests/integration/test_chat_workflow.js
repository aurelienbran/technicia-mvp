const axios = require('axios');

// Configuration
const config = {
  baseUrl: process.env.API_URL || 'http://localhost:80',
  chatEndpoint: '/api/question',
  timeout: 30000, // 30 secondes
  testQuestions: [
    "Comment fonctionne le système hydraulique principal ?",
    "Quel est le processus de diagnostic d'une pompe défectueuse ?",
    "Où se trouve le schéma du circuit électrique principal ?"
  ]
};

// Fonction de test pour une question spécifique
async function testSingleQuestion(question) {
  console.log(`\n=== Test de la question: "${question}" ===`);
  
  try {
    // Préparation des données
    const requestData = {
      question,
      userId: 'test-user',
      sessionId: `test-session-${Date.now()}`
    };
    
    console.log(`Envoi de la requête à ${config.baseUrl}${config.chatEndpoint}...`);
    const startTime = Date.now();
    
    // Envoyer la requête
    const response = await axios.post(`${config.baseUrl}${config.chatEndpoint}`, requestData, {
      timeout: config.timeout
    });
    
    const endTime = Date.now();
    const duration = (endTime - startTime) / 1000;
    
    // Vérification des résultats
    console.log(`Status de la réponse: ${response.status}`);
    console.log(`Durée: ${duration.toFixed(2)} secondes`);
    
    if (response.status === 200) {
      const { answer, images } = response.data;
      
      console.log(`Longueur de la réponse: ${answer.length} caractères`);
      console.log(`Nombre d'images/schémas: ${images ? images.length : 0}`);
      
      // Affichage d'un extrait de la réponse
      if (answer) {
        console.log('Extrait de la réponse:');
        console.log('-------------------');
        console.log(answer.substring(0, 150) + '...');
        console.log('-------------------');
      }
      
      // Vérification basique de la qualité de la réponse
      if (answer && answer.length > 50) {  // Une réponse minimale devrait avoir au moins 50 caractères
        console.log('✅ Test réussi: Une réponse pertinente a été reçue');
      } else {
        console.warn('⚠️ La réponse est trop courte ou vide');
      }
      
      return {
        success: true,
        duration,
        hasImages: images && images.length > 0
      };
    } else {
      console.error('❌ Test échoué: Status de réponse inattendu');
      return { success: false };
    }
  } catch (error) {
    console.error('❌ Test échoué:', error.message);
    
    if (error.response) {
      console.error('Détails de la réponse:', {
        status: error.response.status,
        data: error.response.data
      });
    }
    
    return { success: false, error: error.message };
  }
}

// Fonction principale de test
async function testChatWorkflow() {
  console.log('=== Test du workflow de chat/questions ===');
  
  const results = [];
  
  // Tester chaque question
  for (const question of config.testQuestions) {
    const result = await testSingleQuestion(question);
    results.push({
      question,
      ...result
    });
  }
  
  // Afficher le récapitulatif
  console.log('\n=== Récapitulatif des tests ===');
  console.log(`Total des questions testées: ${results.length}`);
  
  const successCount = results.filter(r => r.success).length;
  console.log(`Tests réussis: ${successCount}/${results.length}`);
  
  const avgDuration = results
    .filter(r => r.success)
    .reduce((sum, r) => sum + r.duration, 0) / successCount || 0;
  
  console.log(`Durée moyenne des réponses: ${avgDuration.toFixed(2)} secondes`);
  
  const imagesCount = results.filter(r => r.hasImages).length;
  console.log(`Réponses incluant des images: ${imagesCount}/${results.length}`);
  
  // Verdict final
  if (successCount === results.length) {
    console.log('\n✅ Tous les tests ont réussi!');
  } else {
    console.log(`\n⚠️ ${results.length - successCount} test(s) ont échoué`);
  }
}

// Exécution du test
testChatWorkflow().catch(console.error);
