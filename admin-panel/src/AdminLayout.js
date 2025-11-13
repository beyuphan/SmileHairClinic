// src/AdminLayout.js
import React from 'react';

function AdminLayout({ children, onLogout, onNavigate, activePage }) {
  return (
    <div className="admin-layout">
      {/* Sol Menü */}
      <nav className="admin-sidebar">
        <h1>Admin Paneli</h1>
        <ul>
          <li 
            className={activePage === 'approvals' ? 'active' : ''}
            onClick={() => onNavigate('approvals')}
          >
            Randevu Onay
          </li>
          
          <li 
            className={activePage === 'slots' ? 'active' : ''}
            onClick={() => onNavigate('slots')}
          >
            Randevu Slotları
          </li>
          <li 
            className={activePage === 'messages' ? 'active' : ''}
            onClick={() => onNavigate('messages')}
          >
            Mesajlar
          </li>
        </ul>
        <button onClick={onLogout} className="logout-button">
          Çıkış Yap
        </button>
      </nav>
      
      {/* Sağ İçerik Alanı */}
      <main className="admin-content">
        {children}
      </main>
    </div>
  );
}
export default AdminLayout;