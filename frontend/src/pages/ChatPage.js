import React, { useState, useRef, useEffect } from 'react';
import ReactMarkdown from 'react-markdown';
import axios from 'axios';

const ChatPage = () => {
  // États pour la conversation
  const [messages, setMessages] = useState([]);
  const [inputMessage, setInputMessage] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState(null);
  const messagesEndRef = useRef(null);
  
  // Configuration des endpoints
  const CHAT_ENDPOINT = '/api/question';
  
  // Scroll automatique vers le bas de la conversation
  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };
  
  useEffect(() => {
    scrollToBottom();
  }, [messages]);
  
  // Fonction pour envoyer un message
  const sendMessage = async () => {
    if (!inputMessage.trim()) return;
    
    // Ajouter le message de l'utilisateur
    const userMessage = {
      id: Date.now(),
      content: inputMessage,
      sender: 'user',
      timestamp: new Date().toISOString(),
    };
    
    setMessages(prev => [...prev, userMessage]);
    setInputMessage('');
    setIsLoading(true);
    setError(null);
    
    try {
      // Appel à l'API
      const response = await axios.post(CHAT_ENDPOINT, {
        question: inputMessage,
        userId: 'user-123', // À remplacer par un ID utilisateur réel
        sessionId: `session-${Date.now()}`,
      });
      
      // Traitement de la réponse
      const assistantMessage = {
        id: Date.now() + 1,
        content: response.data.answer || "Je n'ai pas pu trouver d'information pertinente sur ce sujet.",
        sender: 'assistant',
        timestamp: new Date().toISOString(),
        images: response.data.images || [],
      };
      
      setMessages(prev => [...prev, assistantMessage]);
    } catch (err) {
      console.error('Error sending message:', err);
      setError('Une erreur est survenue lors de l'envoi du message. Veuillez réessayer.');
      
      // Message d'erreur
      const errorMessage = {
        id: Date.now() + 1,
        content: "Désolé, je n'ai pas pu traiter votre demande. Veuillez réessayer ultérieurement.",
        sender: 'assistant',
        timestamp: new Date().toISOString(),
        isError: true,
      };
      
      setMessages(prev => [...prev, errorMessage]);
    } finally {
      setIsLoading(false);
    }
  };
  
  // Gestion de la soumission du formulaire
  const handleSubmit = (e) => {
    e.preventDefault();
    sendMessage();
  };
  
  // Gestion de la touche Entrée
  const handleKeyDown = (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      sendMessage();
    }
  };
  
  // Exemple de questions suggérées
  const suggestedQuestions = [
    "Comment fonctionne le circuit hydraulique principal ?",
    "Quelle est la procédure de maintenance du filtre ?",
    "Quels sont les symptômes d'une défaillance de la pompe ?",
    "Où se trouve le capteur de pression P3 sur le schéma ?"
  ];
  
  // Fonction pour sélectionner une question suggérée
  const selectSuggestedQuestion = (question) => {
    setInputMessage(question);
  };
  
  return (
    <div className="max-w-4xl mx-auto h-[calc(100vh-12rem)] flex flex-col">
      <div className="mb-4">
        <h1 className="text-2xl font-bold">Assistant technique</h1>
        <p className="text-gray-600">Posez vos questions sur la documentation technique</p>
      </div>
      
      {/* Zone de chat */}
      <div className="flex-grow bg-white rounded-lg shadow-md flex flex-col overflow-hidden">
        {/* Messages */}
        <div className="flex-grow overflow-y-auto p-4">
          {messages.length === 0 ? (
            // État initial - pas de messages
            <div className="h-full flex flex-col items-center justify-center text-center text-gray-500">
              <svg xmlns="http://www.w3.org/2000/svg" className="h-16 w-16 mb-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M8 10h.01M12 10h.01M16 10h.01M9 16H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-5l-5 5v-5z" />
              </svg>
              <h3 className="text-xl font-medium mb-2">Comment puis-je vous aider ?</h3>
              <p className="max-w-md mb-6">
                Posez une question sur votre documentation technique pour obtenir des réponses précises et contextuelles.
              </p>
              
              {/* Questions suggérées */}
              <div className="w-full max-w-lg space-y-2">
                <p className="font-medium text-gray-600 mb-2">Exemples de questions :</p>
                {suggestedQuestions.map((question, index) => (
                  <button
                    key={index}
                    onClick={() => selectSuggestedQuestion(question)}
                    className="w-full text-left p-3 rounded-md bg-gray-50 hover:bg-primary-50 border border-gray-200 hover:border-primary-200 transition-colors text-gray-700"
                  >
                    {question}
                  </button>
                ))}
              </div>
            </div>
          ) : (
            // Affichage des messages
            <div className="space-y-4">
              {messages.map((message) => (
                <div
                  key={message.id}
                  className={`flex ${message.sender === 'user' ? 'justify-end' : 'justify-start'}`}
                >
                  <div
                    className={`max-w-[80%] rounded-lg p-3 ${
                      message.sender === 'user'
                        ? 'bg-primary-100 text-primary-900'
                        : message.isError
                        ? 'bg-red-50 text-red-800'
                        : 'bg-gray-100 text-gray-800'
                    }`}
                  >
                    <div className="prose prose-sm">
                      <ReactMarkdown>
                        {message.content}
                      </ReactMarkdown>
                    </div>
                    
                    {/* Affichage des images s'il y en a */}
                    {message.images && message.images.length > 0 && (
                      <div className="mt-3 space-y-2">
                        <p className="text-sm font-medium">Schémas techniques pertinents :</p>
                        <div className="grid grid-cols-1 gap-2">
                          {message.images.map((image, index) => (
                            <div key={index} className="border border-gray-200 rounded-md overflow-hidden">
                              <img
                                src={image}
                                alt={`Schéma technique ${index + 1}`}
                                className="w-full object-contain"
                              />
                              <div className="p-2 bg-gray-50 text-xs">
                                Schéma {index + 1}
                              </div>
                            </div>
                          ))}
                        </div>
                      </div>
                    )}
                    
                    <div className="text-right mt-1">
                      <span className="text-xs opacity-50">
                        {new Date(message.timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                      </span>
                    </div>
                  </div>
                </div>
              ))}
              
              {/* Indicateur de chargement */}
              {isLoading && (
                <div className="flex justify-start">
                  <div className="bg-gray-100 rounded-lg p-3 flex items-center space-x-2">
                    <div className="flex space-x-1">
                      <div className="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style={{ animationDelay: '0.1s' }}></div>
                      <div className="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style={{ animationDelay: '0.3s' }}></div>
                      <div className="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style={{ animationDelay: '0.5s' }}></div>
                    </div>
                    <span className="text-sm text-gray-500">TechnicIA réfléchit...</span>
                  </div>
                </div>
              )}
              
              {/* Message d'erreur */}
              {error && !isLoading && (
                <div className="flex justify-center">
                  <div className="bg-red-50 text-red-700 px-4 py-2 rounded-lg text-sm">
                    {error}
                  </div>
                </div>
              )}
              
              <div ref={messagesEndRef} />
            </div>
          )}
        </div>
        
        {/* Formulaire de saisie */}
        <div className="border-t border-gray-200 p-4 bg-gray-50">
          <form onSubmit={handleSubmit} className="flex items-end gap-2">
            <div className="flex-grow">
              <textarea
                value={inputMessage}
                onChange={(e) => setInputMessage(e.target.value)}
                onKeyDown={handleKeyDown}
                placeholder="Posez votre question technique..."
                className="w-full rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500 text-sm max-h-32 min-h-[2.5rem]"
                rows={1}
                disabled={isLoading}
              />
              <p className="text-xs text-gray-500 mt-1">
                Appuyez sur Entrée pour envoyer, Maj+Entrée pour un saut de ligne
              </p>
            </div>
            
            <button
              type="submit"
              disabled={isLoading || !inputMessage.trim()}
              className="btn btn-primary h-10 px-4 flex-shrink-0 disabled:opacity-50"
            >
              {isLoading ? (
                <svg className="animate-spin h-5 w-5" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                  <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                  <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                </svg>
              ) : (
                <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                  <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-8.707l-3-3a1 1 0 00-1.414 0l-3 3a1 1 0 001.414 1.414L9 9.414V13a1 1 0 102 0V9.414l1.293 1.293a1 1 0 001.414-1.414z" clipRule="evenodd" />
                </svg>
              )}
            </button>
          </form>
        </div>
      </div>
    </div>
  );
};

export default ChatPage;
