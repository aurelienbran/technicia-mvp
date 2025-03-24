import React, { useState, useCallback } from 'react';
import { useDropzone } from 'react-dropzone';
import axios from 'axios';

const DocumentUploadPage = () => {
  // États pour gérer le téléversement et les statuts
  const [uploadedFiles, setUploadedFiles] = useState([]);
  const [uploadStatus, setUploadStatus] = useState({});
  const [isUploading, setIsUploading] = useState(false);
  const [errorMessage, setErrorMessage] = useState('');
  const [processingDetails, setProcessingDetails] = useState(null);

  // Configuration de l'API
  const API_ENDPOINT = '/api/upload';

  // Callback de l'accept du dropzone
  const onDrop = useCallback((acceptedFiles) => {
    // Filtrer les fichiers pour n'accepter que les PDF
    const pdfFiles = acceptedFiles.filter(file => file.type === 'application/pdf');
    
    // Vérifier si tous les fichiers sont des PDF
    if (pdfFiles.length !== acceptedFiles.length) {
      setErrorMessage('Certains fichiers ont été ignorés. Seuls les fichiers PDF sont acceptés.');
    } else {
      setErrorMessage('');
    }
    
    // Préparation des fichiers pour l'affichage et l'upload
    const newFiles = pdfFiles.map(file => {
      // Créer une URL pour la prévisualisation
      const preview = URL.createObjectURL(file);
      
      return {
        file,
        preview,
        id: `${file.name}-${Date.now()}`,
        name: file.name,
        size: file.size,
        type: file.type,
        status: 'pending'
      };
    });
    
    setUploadedFiles(prev => [...prev, ...newFiles]);
  }, []);

  // Configuration du dropzone
  const { getRootProps, getInputProps, isDragActive } = useDropzone({
    onDrop,
    accept: {
      'application/pdf': ['.pdf']
    },
    maxSize: 150 * 1024 * 1024, // 150 MB
    multiple: true
  });

  // Fonction pour formater la taille du fichier
  const formatFileSize = (bytes) => {
    if (bytes < 1024) return bytes + ' B';
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(2) + ' KB';
    return (bytes / (1024 * 1024)).toFixed(2) + ' MB';
  };

  // Fonction pour téléverser un fichier
  const uploadFile = async (fileObj) => {
    // Mise à jour du statut
    setUploadStatus(prev => ({ ...prev, [fileObj.id]: 'uploading' }));
    
    try {
      // Création du FormData
      const formData = new FormData();
      formData.append('file', fileObj.file);
      
      // Envoi du fichier
      const response = await axios.post(API_ENDPOINT, formData, {
        headers: {
          'Content-Type': 'multipart/form-data'
        },
        onUploadProgress: (progressEvent) => {
          // Calcul de la progression
          const percentCompleted = Math.round((progressEvent.loaded * 100) / progressEvent.total);
          console.log(`${fileObj.name} upload progress: ${percentCompleted}%`);
        }
      });
      
      // Mise à jour du statut en cas de succès
      setUploadStatus(prev => ({ ...prev, [fileObj.id]: 'success' }));
      setProcessingDetails(response.data);
      
      return response.data;
    } catch (error) {
      // Gestion des erreurs
      console.error('Error uploading file:', error);
      setUploadStatus(prev => ({ ...prev, [fileObj.id]: 'error' }));
      setErrorMessage(error.response?.data?.message || 'Une erreur est survenue lors du téléversement');
      throw error;
    }
  };

  // Fonction pour téléverser tous les fichiers
  const handleUploadAll = async () => {
    // Filtrer les fichiers en attente
    const pendingFiles = uploadedFiles.filter(f => !uploadStatus[f.id] || uploadStatus[f.id] === 'pending');
    
    if (pendingFiles.length === 0) {
      setErrorMessage('Aucun nouveau fichier à téléverser');
      return;
    }
    
    setIsUploading(true);
    setErrorMessage('');
    
    try {
      // Téléverser les fichiers un par un
      for (const fileObj of pendingFiles) {
        await uploadFile(fileObj);
      }
    } catch (error) {
      console.error('Error in batch upload:', error);
    } finally {
      setIsUploading(false);
    }
  };

  // Fonction pour supprimer un fichier de la liste
  const removeFile = (id) => {
    setUploadedFiles(uploadedFiles.filter(f => f.id !== id));
    setUploadStatus(prev => {
      const newStatus = { ...prev };
      delete newStatus[id];
      return newStatus;
    });
  };

  // Fonction pour obtenir la couleur du statut
  const getStatusColor = (status) => {
    switch (status) {
      case 'success': return 'text-green-600';
      case 'error': return 'text-red-600';
      case 'uploading': return 'text-blue-600';
      default: return 'text-gray-600';
    }
  };

  // Fonction pour obtenir le texte du statut
  const getStatusText = (status) => {
    switch (status) {
      case 'success': return 'Téléversé';
      case 'error': return 'Erreur';
      case 'uploading': return 'En cours...';
      default: return 'En attente';
    }
  };

  return (
    <div className="max-w-4xl mx-auto">
      <h1 className="text-2xl font-bold mb-6">Téléverser des documents techniques</h1>
      
      {/* Zone de glisser-déposer */}
      <div
        {...getRootProps()}
        className={`border-2 border-dashed rounded-lg p-8 text-center mb-6 cursor-pointer transition-colors ${
          isDragActive ? 'border-primary-500 bg-primary-50' : 'border-gray-300 hover:border-primary-400'
        }`}
      >
        <input {...getInputProps()} />
        
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" className="w-12 h-12 text-gray-400 mx-auto mb-4">
          <path fillRule="evenodd" d="M5.625 1.5H9a3.75 3.75 0 013.75 3.75v1.875c0 1.036.84 1.875 1.875 1.875H16.5a3.75 3.75 0 013.75 3.75v7.875c0 1.035-.84 1.875-1.875 1.875H5.625a1.875 1.875 0 01-1.875-1.875V3.375c0-1.036.84-1.875 1.875-1.875zm6.905 9.97a.75.75 0 00-1.06 0l-3 3a.75.75 0 101.06 1.06l1.72-1.72V18a.75.75 0 001.5 0v-4.19l1.72 1.72a.75.75 0 101.06-1.06l-3-3z" clipRule="evenodd" />
          <path d="M14.25 5.25a5.23 5.23 0 00-1.279-3.434 9.768 9.768 0 016.963 6.963A5.23 5.23 0 0016.5 7.5h-1.875a.375.375 0 01-.375-.375V5.25z" />
        </svg>

        {isDragActive ? (
          <p className="text-lg">Déposez les fichiers ici...</p>
        ) : (
          <div>
            <p className="text-lg mb-2">Glissez-déposez des fichiers PDF ici</p>
            <p className="text-sm text-gray-500">ou cliquez pour sélectionner des fichiers</p>
            <p className="text-xs text-gray-400 mt-2">Taille maximale: 150 MB</p>
          </div>
        )}
      </div>
      
      {/* Message d'erreur */}
      {errorMessage && (
        <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-md mb-6">
          {errorMessage}
        </div>
      )}
      
      {/* Liste des fichiers */}
      {uploadedFiles.length > 0 && (
        <div className="bg-white rounded-lg shadow overflow-hidden mb-6">
          <div className="px-4 py-3 bg-gray-50 border-b border-gray-200">
            <h2 className="font-semibold">Documents à téléverser</h2>
          </div>
          
          <ul className="divide-y divide-gray-200">
            {uploadedFiles.map((fileObj) => (
              <li key={fileObj.id} className="px-4 py-3 flex items-center">
                <div className="flex-shrink-0 mr-3">
                  <svg xmlns="http://www.w3.org/2000/svg" className="h-6 w-6 text-red-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7 21h10a2 2 0 002-2V9.414a1 1 0 00-.293-.707l-5.414-5.414A1 1 0 0012.586 3H7a2 2 0 00-2 2v14a2 2 0 002 2z" />
                  </svg>
                </div>
                
                <div className="flex-grow min-w-0">
                  <p className="text-sm font-medium text-gray-900 truncate">
                    {fileObj.name}
                  </p>
                  <p className="text-xs text-gray-500">
                    {formatFileSize(fileObj.size)}
                  </p>
                </div>
                
                <div className={`flex-shrink-0 ml-4 ${getStatusColor(uploadStatus[fileObj.id])}`}>
                  {getStatusText(uploadStatus[fileObj.id])}
                </div>
                
                <button
                  onClick={() => removeFile(fileObj.id)}
                  disabled={isUploading && uploadStatus[fileObj.id] === 'uploading'}
                  className="ml-4 text-gray-400 hover:text-red-500 disabled:opacity-50"
                >
                  <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                    <path fillRule="evenodd" d="M9 2a1 1 0 00-.894.553L7.382 4H4a1 1 0 000 2v10a2 2 0 002 2h8a2 2 0 002-2V6a1 1 0 100-2h-3.382l-.724-1.447A1 1 0 0011 2H9zM7 8a1 1 0 012 0v6a1 1 0 11-2 0V8zm5-1a1 1 0 00-1 1v6a1 1 0 102 0V8a1 1 0 00-1-1z" clipRule="evenodd" />
                  </svg>
                </button>
              </li>
            ))}
          </ul>
          
          <div className="px-4 py-3 bg-gray-50 border-t border-gray-200 flex justify-end">
            <button
              onClick={handleUploadAll}
              disabled={isUploading}
              className="btn btn-primary"
            >
              {isUploading ? (
                <>
                  <svg className="animate-spin -ml-1 mr-2 h-4 w-4 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                    <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                    <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                  </svg>
                  Traitement en cours...
                </>
              ) : (
                'Téléverser tous les documents'
              )}
            </button>
          </div>
        </div>
      )}
      
      {/* Détails du traitement */}
      {processingDetails && (
        <div className="bg-green-50 border border-green-200 rounded-lg p-4 mb-6">
          <h3 className="text-green-800 font-semibold mb-2">Traitement terminé avec succès</h3>
          
          <div className="text-sm text-green-700">
            <p>Document: <span className="font-medium">{processingDetails.document_name}</span></p>
            <p className="mt-1">Fragments de texte traités: <span className="font-medium">{processingDetails.text_chunks_count}</span></p>
            <p>Images/Schémas extraits: <span className="font-medium">{processingDetails.images_count}</span></p>
            <p className="mt-2 italic">Ce document est maintenant disponible pour les requêtes via le chat et le diagnostic.</p>
          </div>
        </div>
      )}
      
      {/* Instructions */}
      <div className="bg-gray-50 rounded-lg p-6 border border-gray-200">
        <h2 className="text-lg font-semibold mb-4">Instructions</h2>
        
        <div className="space-y-3 text-sm text-gray-600">
          <p>1. Téléversez vos documents techniques au format PDF (manuels, schémas, guides, etc.)</p>
          <p>2. Les documents seront automatiquement traités pour extraire le texte et les schémas</p>
          <p>3. Le processus peut prendre quelques minutes selon la taille et la complexité des documents</p>
          <p>4. Une fois traité, le contenu sera indexé et disponible pour les recherches</p>
          <p className="text-red-600 font-medium">Note: Chaque fichier est limité à 150 MB maximum</p>
        </div>
      </div>
    </div>
  );
};

export default DocumentUploadPage;
