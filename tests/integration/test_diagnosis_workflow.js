const axios = require('axios');

// Configuration
const config = {
  baseUrl: process.env.API_URL || 'http://localhost:80',
  startDiagnosisEndpoint: '/api/start-diagnosis',
  diagnosisStepEndpoint: '/api/diagnosis-step',
  timeout: 45000, // 45 secondes
  testScenario: {
    equipmentId: 'hydraulic-system',
    equipmentType: 'Système hydraulique',
    initialSymptoms: 'Pression hydraulique trop faible et bruit anormal près de la pompe principale. La pression chute progressivement pendant l\'utilisation.',
    // Réponses pré-définies pour simuler un scénario complet
    stepResponses: [
      "La pression mesurée est de 120 bar, alors qu'elle devrait être entre 150-200 bar selon les spécifications.",
      "Le niveau d'huile est correct mais l'huile semble plus foncée que d'habitude et contient des particules en suspension.",
      "Oui, la pompe émet un bruit de grincement inhabituel et sa température est plus élevée que la normale.",
      "Les filtres sont partiellement colmatés, avec des débris métalliques visibles.",
      "Les soupapes se déclenchent à 140 bar au lieu de 180 bar indiqué dans les spécifications."
    ]
  }
};

// Fonction principale de test
async function testDiagnosisWorkflow() {
  console.log('=== Test du workflow de diagnostic guidé ===');
  
  try {
    // Étape 1: Démarrer un nouveau diagnostic
    console.log('\n=== Étape 1: Démarrage du diagnostic ===');
    
    const startRequest = {
      equipmentId: config.testScenario.equipmentId,
      equipmentType: config.testScenario.equipmentType,
      initialSymptoms: config.testScenario.initialSymptoms,
      userId: 'test-user'
    };
    
    console.log(`Envoi de la requête à ${config.baseUrl}${config.startDiagnosisEndpoint}...`);
    console.log('Symptômes initiaux:', config.testScenario.initialSymptoms);
    
    const startResponse = await axios.post(
      `${config.baseUrl}${config.startDiagnosisEndpoint}`,
      startRequest,
      { timeout: config.timeout }
    );
    
    if (startResponse.status !== 200) {
      throw new Error(`Démarrage du diagnostic échoué: ${startResponse.status}`);
    }
    
    console.log('✅ Diagnostic démarré avec succès');
    
    // Extraction des données du diagnostic
    const diagnosisData = startResponse.data;
    const diagnosisId = diagnosisData.diagnosisId;
    const totalSteps = diagnosisData.progress.totalSteps;
    
    console.log(`ID du diagnostic: ${diagnosisId}`);
    console.log(`Nombre total d'étapes: ${totalSteps}`);
    console.log(`Étape actuelle: ${diagnosisData.progress.currentStep}`);
    
    // Vérification que le diagnostic a bien démarré
    if (!diagnosisId || !diagnosisData.currentStepData) {
      throw new Error('Format de réponse invalide pour le démarrage du diagnostic');
    }
    
    // Étape 2: Progression à travers les étapes du diagnostic
    console.log('\n=== Étape 2: Progression à travers le diagnostic ===');
    
    let currentStep = diagnosisData.progress.currentStep;
    let stepData = diagnosisData.currentStepData;
    let isCompleted = false;
    
    // Boucle à travers les étapes du diagnostic
    while (!isCompleted) {
      console.log(`\n> Étape ${currentStep}/${totalSteps}: ${stepData.title}`);
      console.log(`Question: ${stepData.question}`);
      
      // Récupérer la réponse prédéfinie pour cette étape
      const responseIndex = currentStep - 1;
      const stepResponse = responseIndex < config.testScenario.stepResponses.length 
        ? config.testScenario.stepResponses[responseIndex]
        : "Test de réponse générique";
      
      console.log(`Réponse: ${stepResponse}`);
      
      // Envoi de la réponse à l'étape actuelle
      const stepRequest = {
        diagnosisId,
        stepNumber: currentStep,
        response: stepResponse,
        notes: `Note de test pour l'étape ${currentStep}`
      };
      
      const stepResponseResult = await axios.post(
        `${config.baseUrl}${config.diagnosisStepEndpoint}`,
        stepRequest,
        { timeout: config.timeout }
      );
      
      if (stepResponseResult.status !== 200) {
        throw new Error(`Étape de diagnostic échouée: ${stepResponseResult.status}`);
      }
      
      // Mise à jour des données pour la prochaine étape
      const stepResponseData = stepResponseResult.data;
      
      // Vérifier si le diagnostic est terminé
      if (stepResponseData.status === 'completed') {
        isCompleted = true;
        console.log('\n✅ Diagnostic complété avec succès');
        
        // Vérifier le rapport de diagnostic
        if (stepResponseData.report && stepResponseData.report.content) {
          const reportLength = stepResponseData.report.content.length;
          console.log(`Rapport généré: ${reportLength} caractères`);
          
          // Afficher un extrait du rapport
          console.log('\nExtrait du rapport:');
          console.log('------------------');
          console.log(stepResponseData.report.content.substring(0, 200) + '...');
          console.log('------------------');
        } else {
          console.warn('⚠️ Aucun rapport de diagnostic n\'a été généré');
        }
        
        break;
      }
      
      // Passer à l'étape suivante
      currentStep = stepResponseData.progress.currentStep;
      stepData = stepResponseData.currentStepData;
      
      // Vérification de progression
      if (currentStep > totalSteps) {
        throw new Error('Le numéro d\'étape a dépassé le nombre total d\'étapes');
      }
    }
    
    // Afficher le succès du test complet
    console.log('\n=== Récapitulatif du test ===');
    console.log(`✅ Test du workflow de diagnostic complété avec succès`);
    console.log(`Nombre d'étapes parcourues: ${totalSteps}`);
    
    return { success: true };
    
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

// Exécution du test
testDiagnosisWorkflow().catch(console.error);
