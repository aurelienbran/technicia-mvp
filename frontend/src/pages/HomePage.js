import React from 'react';
import { Link } from 'react-router-dom';

const HomePage = () => {
  return (
    <div className="max-w-5xl mx-auto">
      {/* Hero Section */}
      <section className="text-center py-8 md:py-16">
        <h1 className="text-3xl md:text-4xl font-bold mb-4">TechnicIA</h1>
        <p className="text-xl md:text-2xl text-gray-600 mb-8">Assistant intelligent de maintenance technique</p>
        <div className="flex flex-col md:flex-row justify-center gap-4">
          <Link to="/upload" className="btn btn-primary px-6 py-3">
            Téléverser de la documentation
          </Link>
          <Link to="/chat" className="btn btn-outline px-6 py-3">
            Poser une question
          </Link>
        </div>
      </section>

      {/* Features */}
      <section className="py-12">
        <h2 className="text-2xl font-bold text-center mb-8">Fonctionnalités principales</h2>
        <div className="grid md:grid-cols-3 gap-8">
          {/* Feature 1 */}
          <div className="card flex flex-col items-center text-center">
            <div className="rounded-full bg-primary-100 p-4 mb-4">
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-8 h-8 text-primary-600">
                <path strokeLinecap="round" strokeLinejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z" />
              </svg>
            </div>
            <h3 className="text-lg font-semibold mb-2">Documentation intelligente</h3>
            <p className="text-gray-600">Indexation avancée de vos manuels techniques pour un accès rapide à l'information pertinente.</p>
          </div>

          {/* Feature 2 */}
          <div className="card flex flex-col items-center text-center">
            <div className="rounded-full bg-primary-100 p-4 mb-4">
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-8 h-8 text-primary-600">
                <path strokeLinecap="round" strokeLinejoin="round" d="M7.5 8.25h9m-9 3H12m-9.75 1.51c0 1.6 1.123 2.994 2.707 3.227 1.129.166 2.27.293 3.423.379.35.026.67.21.865.501L12 21l2.755-4.133a1.14 1.14 0 01.865-.501 48.172 48.172 0 003.423-.379c1.584-.233 2.707-1.626 2.707-3.228V6.741c0-1.602-1.123-2.995-2.707-3.228A48.394 48.394 0 0012 3c-2.392 0-4.744.175-7.043.513C3.373 3.746 2.25 5.14 2.25 6.741v6.018z" />
              </svg>
            </div>
            <h3 className="text-lg font-semibold mb-2">Assistant par chat</h3>
            <p className="text-gray-600">Posez vos questions en langage naturel et obtenez des réponses précises basées sur votre documentation technique.</p>
          </div>

          {/* Feature 3 */}
          <div className="card flex flex-col items-center text-center">
            <div className="rounded-full bg-primary-100 p-4 mb-4">
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-8 h-8 text-primary-600">
                <path strokeLinecap="round" strokeLinejoin="round" d="M11.42 15.17L17.25 21A2.652 2.652 0 0021 17.25l-5.877-5.877M11.42 15.17l2.496-3.03c.317-.384.74-.626 1.208-.766M11.42 15.17l-4.655 5.653a2.548 2.548 0 11-3.586-3.586l6.837-5.63m5.108-.233c.55-.164 1.163-.188 1.743-.14a4.5 4.5 0 004.486-6.336l-3.276 3.277a3.004 3.004 0 01-2.25-2.25l3.276-3.276a4.5 4.5 0 00-6.336 4.486c.091 1.076-.071 2.264-.904 2.95l-.102.085m-1.745 1.437L5.909 7.5H4.5L2.25 3.75l1.5-1.5L7.5 4.5v1.409l4.26 4.26m-1.745 1.437l1.745-1.437m6.615 8.206L15.75 15.75M4.867 19.125h.008v.008h-.008v-.008z" />
              </svg>
            </div>
            <h3 className="text-lg font-semibold mb-2">Diagnostic guidé</h3>
            <p className="text-gray-600">Diagnostic pas à pas pour vous aider à résoudre méthodiquement les problèmes techniques rencontrés.</p>
          </div>
        </div>
      </section>

      {/* How it works */}
      <section className="py-12 bg-gray-50 rounded-lg my-8">
        <h2 className="text-2xl font-bold text-center mb-8">Comment ça fonctionne</h2>
        <div className="flex flex-col gap-6 max-w-3xl mx-auto">
          <div className="flex items-start gap-4">
            <div className="bg-primary-600 text-white rounded-full w-8 h-8 flex items-center justify-center flex-shrink-0 mt-1">1</div>
            <div>
              <h3 className="font-semibold text-lg">Téléversez votre documentation technique</h3>
              <p className="text-gray-600">Importez vos manuels, schémas et guides au format PDF pour les rendre accessibles à TechnicIA.</p>
            </div>
          </div>
          <div className="flex items-start gap-4">
            <div className="bg-primary-600 text-white rounded-full w-8 h-8 flex items-center justify-center flex-shrink-0 mt-1">2</div>
            <div>
              <h3 className="font-semibold text-lg">Posez vos questions</h3>
              <p className="text-gray-600">Utilisez l'interface de chat pour poser des questions techniques en langage naturel.</p>
            </div>
          </div>
          <div className="flex items-start gap-4">
            <div className="bg-primary-600 text-white rounded-full w-8 h-8 flex items-center justify-center flex-shrink-0 mt-1">3</div>
            <div>
              <h3 className="font-semibold text-lg">Obtenez des réponses précises</h3>
              <p className="text-gray-600">TechnicIA vous fournit des réponses contextuelles avec références aux sources et schémas pertinents.</p>
            </div>
          </div>
          <div className="flex items-start gap-4">
            <div className="bg-primary-600 text-white rounded-full w-8 h-8 flex items-center justify-center flex-shrink-0 mt-1">4</div>
            <div>
              <h3 className="font-semibold text-lg">Démarrez un diagnostic guidé</h3>
              <p className="text-gray-600">Pour les problèmes complexes, utilisez le module de diagnostic pas à pas pour une résolution méthodique.</p>
            </div>
          </div>
        </div>
      </section>

      {/* Call to action */}
      <section className="py-12 text-center">
        <h2 className="text-2xl font-bold mb-4">Prêt à optimiser votre maintenance ?</h2>
        <p className="text-gray-600 mb-6 max-w-2xl mx-auto">TechnicIA vous aide à améliorer l'efficacité de vos techniciens en leur donnant accès rapidement à l'information dont ils ont besoin.</p>
        <Link to="/upload" className="btn btn-primary px-6 py-3">Commencer maintenant</Link>
      </section>
    </div>
  );
};

export default HomePage;
