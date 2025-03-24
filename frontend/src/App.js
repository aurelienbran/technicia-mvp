import React from 'react';
import { Routes, Route } from 'react-router-dom';
import Layout from './components/Layout';
import HomePage from './pages/HomePage';
import DocumentUploadPage from './pages/DocumentUploadPage';
import ChatPage from './pages/ChatPage';
import DiagnosticPage from './pages/DiagnosticPage';

function App() {
  return (
    <Routes>
      <Route path="/" element={<Layout />}>
        <Route index element={<HomePage />} />
        <Route path="upload" element={<DocumentUploadPage />} />
        <Route path="chat" element={<ChatPage />} />
        <Route path="diagnostic" element={<DiagnosticPage />} />
      </Route>
    </Routes>
  );
}

export default App;
