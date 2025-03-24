import React, { useState } from 'react';
import ReactMarkdown from 'react-markdown';
import axios from 'axios';

const DiagnosticPage = () => {
  // États pour le diagnostic
  const [step, setStep] = useState('initial'); // 'initial', 'in_progress', 'completed'
  const [equipment, setEquipment] = useState('');
  const [symptoms, setSymptoms] = useState('');
  const [diagnosisId, setDiagnosisId] = useState(null);
  const [diagnosisData, setDiagnosisData] = useState(null);
  const [currentStepData, setCurrentStepData] = useState(null);
  const [stepResponse, setStepResponse] = useState('');
  const [stepNotes, setStepNotes] = useState('');
  const [report, setReport] = useState(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState(null);
  
  // Configuration des endpoints
  const START_DIAGNOSIS_ENDPOINT = '/api/start-diagnosis';
  const DIAGNOSIS_STEP_ENDPOINT = '/api/diagnosis-step';

  // Options d'équipement (à remplacer par des données réelles)
  const equipmentOptions = [
    { id: 'hydraulic-system', name: 'Système hydraulique' },
    { id: 'pneumatic-circuit', name: 'Circuit pneumatique' },
    { id: 'electrical-system', name: 'Système électrique' },
    { id: 'mechanical-drive', name: 'Transmission mécanique' }
  ];

  // Fonction pour démarrer un diagnostic
  const startDiagnosis = async () => {
    if (!equipment || !symptoms.trim()) {
      setError('Veuillez sélectionner un équipement et décrire les symptômes observés.');
      return;
    }

    setIsLoading(true);
    setError(null);

    try {
      // Appel à l'API pour démarrer le diagnostic
      const response = await axios.post(START_DIAGNOSIS_ENDPOINT, {
        equipmentId: equipment,
        equipmentType: equipmentOptions.find(e => e.id === equipment)?.name || equipment,
        initialSymptoms: symptoms,
        userId: 'user-123', // À remplacer par un ID utilisateur réel
      });

      // Traitement de la réponse
      setDiagnosisId(response.data.diagnosisId);
      setDiagnosisData(response.data);
      setCurrentStepData(response.data.currentStepData);
      setStep('in_progress');
    } catch (err) {
      console.error('Error starting diagnosis:', err);
      setError('Une erreur est survenue lors du démarrage du diagnostic. Veuillez réessayer.');
    } finally {
      setIsLoading(false);
    }
  };

  // Fonction pour soumettre une réponse à une étape
  const submitStepResponse = async () => {
    if (!stepResponse.trim()) {
      setError('Veuillez fournir une réponse pour cette étape.');
      return;
    }

    setIsLoading(true);
    setError(null);

    try {
      // Appel à l'API pour soumettre la réponse
      const response = await axios.post(DIAGNOSIS_STEP_ENDPOINT, {
        diagnosisId,
        stepNumber: currentStepData.stepNumber,
        response: stepResponse,
        notes: stepNotes,
      });

      // Traitement de la réponse
      if (response.data.status === 'completed') {
        setReport(response.data.report);
        setStep('completed');
      } else {
        setDiagnosisData(response.data);
        setCurrentStepData(response.data.currentStepData);
        // Réinitialiser les champs pour la prochaine étape
        setStepResponse('');
        setStepNotes('');
      }
    } catch (err) {
      console.error('Error submitting step response:', err);
      setError('Une erreur est survenue lors de la soumission de votre réponse. Veuillez réessayer.');
    } finally {
      setIsLoading(false);
    }
  };

  // Fonction pour recommencer un diagnostic
  const restartDiagnosis = () => {
    setStep('initial');
    setEquipment('');
    setSymptoms('');
    setDiagnosisId(null);
    setDiagnosisData(null);
    setCurrentStepData(null);
    setStepResponse('');
    setStepNotes('');
    setReport(null);
    setError(null);
  };

  // Rendu du formulaire initial
  const renderInitialForm = () => (
    <div className="bg-white rounded-lg shadow-md p-6">
      <h2 className="text-xl font-semibold mb-4">Démarrer un diagnostic guidé</h2>
      
      <div className="space-y-6">
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">
            Type d'équipement
          </label>
          <select
            value={equipment}
            onChange={(e) => setEquipment(e.target.value)}
            className="w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500"
            disabled={isLoading}
          >
            <option value="">Sélectionnez un équipement</option>
            {equipmentOptions.map(option => (
              <option key={option.id} value={option.id}>
                {option.name}
              </option>
            ))}
          </select>
        </div>
        
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">
            Symptômes observés
          </label>
          <textarea
            value={symptoms}
            onChange={(e) => setSymptoms(e.target.value)}
            placeholder="Décrivez les symptômes observés aussi précisément que possible..."
            className="w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500"
            rows={5}
            disabled={isLoading}
          />
          <p className="mt-1 text-sm text-gray-500">
            Exemple : "La pression hydraulique chute progressivement et un bruit inhabituel est perceptible près de la pompe principale."
          </p>
        </div>
        
        <div className="flex justify-end">
          <button
            onClick={startDiagnosis}
            disabled={isLoading || !equipment || !symptoms.trim()}
            className="btn btn-primary"
          >
            {isLoading ? (
              <>
                <svg className="animate-spin -ml-1 mr-2 h-4 w-4 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                  <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                  <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                </svg>
                Préparation du diagnostic...
              </>
            ) : (
              'Démarrer le diagnostic'
            )}
          </button>
        </div>
      </div>
    </div>
  );

  // Rendu de l'étape de diagnostic en cours
  const renderDiagnosticStep = () => (
    <div className="bg-white rounded-lg shadow-md overflow-hidden">
      {/* En-tête avec la progression */}
      <div className="bg-primary-700 px-6 py-4 text-white">
        <div className="flex justify-between items-center">
          <h2 className="text-xl font-semibold">Diagnostic en cours</h2>
          <div className="text-sm">
            Étape {diagnosisData.progress.currentStep} sur {diagnosisData.progress.totalSteps}
          </div>
        </div>
        
        {/* Barre de progression */}
        <div className="w-full bg-primary-600 rounded-full h-2.5 mt-2">
          <div
            className="bg-white h-2.5 rounded-full"
            style={{ width: `${diagnosisData.progress.percentComplete}%` }}
          ></div>
        </div>
      </div>
      
      {/* Contenu de l'étape */}
      <div className="p-6">
        <div className="mb-6">
          <h3 className="text-lg font-semibold mb-2">{currentStepData.title}</h3>
          <p className="text-gray-700 mb-4">{currentStepData.description}</p>
          
          <div className="bg-gray-50 border-l-4 border-primary-400 p-4 mb-4">
            <p className="font-medium">Instructions :</p>
            <p className="text-gray-700">{currentStepData.instructions}</p>
          </div>
          
          <div className="bg-gray-50 border-l-4 border-secondary-400 p-4">
            <p className="font-medium">Résultats attendus :</p>
            <p className="text-gray-700">{currentStepData.expectedResults}</p>
          </div>
        </div>
        
        <div className="mb-4">
          <label className="block text-sm font-medium text-gray-700 mb-1">
            {currentStepData.question}
          </label>
          <textarea
            value={stepResponse}
            onChange={(e) => setStepResponse(e.target.value)}
            placeholder="Votre réponse..."
            className="w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500"
            rows={3}
            disabled={isLoading}
          />
        </div>
        
        <div className="mb-6">
          <label className="block text-sm font-medium text-gray-700 mb-1">
            Notes additionnelles (optionnel)
          </label>
          <textarea
            value={stepNotes}
            onChange={(e) => setStepNotes(e.target.value)}
            placeholder="Précisions, observations particulières..."
            className="w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500"
            rows={2}
            disabled={isLoading}
          />
        </div>
        
        <div className="flex justify-end">
          <button
            onClick={submitStepResponse}
            disabled={isLoading || !stepResponse.trim()}
            className="btn btn-primary"
          >
            {isLoading ? (
              <>
                <svg className="animate-spin -ml-1 mr-2 h-4 w-4 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                  <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                  <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                </svg>
                Traitement...
              </>
            ) : (
              'Continuer'
            )}
          </button>
        </div>
      </div>
    </div>
  );

  // Rendu du rapport de diagnostic final
  const renderDiagnosticReport = () => (
    <div className="bg-white rounded-lg shadow-md overflow-hidden">
      <div className="bg-green-700 px-6 py-4 text-white">
        <h2 className="text-xl font-semibold">Diagnostic complété</h2>
        <p className="text-sm mt-1">
          ID: {diagnosisId} | Durée: {report.diagnosisDuration}
        </p>
      </div>
      
      <div className="p-6">
        <div className="prose prose-sm max-w-none">
          <ReactMarkdown>
            {report.content}
          </ReactMarkdown>
        </div>
        
        <div className="mt-8 flex justify-end">
          <button
            onClick={restartDiagnosis}
            className="btn btn-outline mr-4"
          >
            Nouveau diagnostic
          </button>
          <button
            onClick={() => window.print()}
            className="btn btn-primary"
          >
            Imprimer le rapport
          </button>
        </div>
      </div>
    </div>
  );

  return (
    <div className="max-w-4xl mx-auto">
      <div className="mb-6">
        <h1 className="text-2xl font-bold">Diagnostic guidé</h1>
        <p className="text-gray-600">Diagnostic pas à pas pour résoudre les problèmes techniques</p>
      </div>
      
      {/* Affichage des erreurs */}
      {error && (
        <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-md mb-6">
          {error}
        </div>
      )}
      
      {/* Affichage conditionnel selon l'étape */}
      {step === 'initial' && renderInitialForm()}
      {step === 'in_progress' && renderDiagnosticStep()}
      {step === 'completed' && renderDiagnosticReport()}
      
      {/* Instructions */}
      {step === 'initial' && (
        <div className="bg-gray-50 rounded-lg p-6 border border-gray-200 mt-6">
          <h2 className="text-lg font-semibold mb-4">Comment fonctionne le diagnostic guidé ?</h2>
          
          <div className="space-y-3 text-sm text-gray-600">
            <p>1. <span className="font-medium">Sélectionnez l'équipement</span> concerné et décrivez précisément les symptômes observés</p>
            <p>2. <span className="font-medium">Suivez les étapes</span> proposées par l'assistant de diagnostic</p>
            <p>3. <span className="font-medium">Réalisez les tests</span> recommandés et entrez les résultats observés</p>
            <p>4. <span className="font-medium">Obtenez un rapport complet</span> avec analyse des causes probables et recommandations</p>
            <p className="text-primary-600 font-medium mt-4">Note: Le diagnostic s'appuie sur la documentation technique préalablement téléversée dans le système.</p>
          </div>
        </div>
      )}
    </div>
  );
};

export default DiagnosticPage;
