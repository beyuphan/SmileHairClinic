// src/App.js
import React, { useState, useEffect } from 'react';
import './App.css';
import Login from './Login';
import SlotManager from './SlotManager'; // Düzeltilmiş v3'ü import edecek
import AdminLayout from './AdminLayout';
import Messages from './Messages';
import { setAuthToken } from './apiService';

function App() {
  const [token, setToken] = useState(null);
  const [isLoading, setIsLoading] = useState(true);
  const [page, setPage] = useState('slots'); // Hangi sayfadayız?

  // Token'ı kontrol et
  useEffect(() => {
    const storedToken = localStorage.getItem('adminToken');
    if (storedToken) {
      setToken(storedToken);
      setAuthToken(storedToken);
    }
    setIsLoading(false);
  }, []);

  // Login olunca
  const handleLoginSuccess = (newToken) => {
    setToken(newToken);
    localStorage.setItem('adminToken', newToken);
    setAuthToken(newToken);
  };

  // Çıkış yapınca (Artık çalışacak)
  const handleLogout = () => {
    setToken(null);
    localStorage.removeItem('adminToken');
    setAuthToken(null);
    setPage('slots'); // Sayfayı sıfırla
  };

  // Menüden sayfa değiştirince
  const handleNavigate = (newPage) => {
    setPage(newPage);
  };

  // Hangi sayfayı göstereceğimizi seç
  const renderPage = () => {
    switch(page) {
      case 'slots':
        return <SlotManager />; // Düzeltilmiş (v3) SlotManager'ı göster
      case 'messages':
        return <Messages />;
      default:
        return <SlotManager />;
    }
  };

  if (isLoading) {
    return <div>Yükleniyor...</div>;
  }

  return (
    <div className="App">
      {token ? (
        // Giriş yaptıysak: Paneli göster
        <AdminLayout 
          onLogout={handleLogout}
          onNavigate={handleNavigate}
          activePage={page}
        >
          {renderPage()}
        </AdminLayout>
      ) : (
        // Giriş yapmadıysak: Login'i göster
        <div className="login-view">
          <Login onLoginSuccess={handleLoginSuccess} />
        </div>
      )}
    </div>
  );
}
export default App;