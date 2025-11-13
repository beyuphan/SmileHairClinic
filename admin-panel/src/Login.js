// src/Login.js
import React, { useState } from 'react';
import apiService from './apiService'; // Az önce yarattığımız servis

// 'onLoginSuccess' prop'u, App.js'e "Giriş başarılı, token bu" demek için
function Login({ onLoginSuccess }) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError(''); // Eski hatayı temizle

    try {
      // Backend'e yolladığımız veriyi de loglayalım
      const loginData = {
        email: email,
        password: password, // Senin backend'in (DTO) 'pass' bekliyordu
      };
      
      console.log("Backend'e yollanan veri:", loginData);

      // Backend'in /auth/login endpoint'ine (auth.controller.ts) istek at
      const response = await apiService.post('/auth/login', loginData);

      console.log("Backend'den gelen cevap:", response.data);

      const token = response.data.accessToken;
      if (token) {
        onLoginSuccess(token); // Ana bileşene token'ı yolla
      } else {
        setError('Token alınamadı.');
      }

    } catch (err) {
      // --- İŞTE AMINA KODUMUN HATASINI BURADA YAKALAYACAĞIZ ---

      console.error("--- HATA OBJEKTİSİNİN TAMAMI ---", err); // 1. Tüm objeyi logla

      if (err.response) {
        // Backend'den 401, 403, 404, 500 gibi bir hata cevabı geldiyse
        console.error("--- BACKEND'DEN GELEN HATA ---", err.response.data);
        console.error("--- HTTP STATUS KODU ---", err.response.status);
        
        // Ekrana da yazdıralım
        // err.response.data genelde { "message": "...", "statusCode": 401 } gibi bir JSON'dur
        const backendMesaji = err.response.data.message || JSON.stringify(err.response.data);
        setError(`Backend Hatası: ${backendMesaji} (Kod: ${err.response.status})`);

      } else if (err.request) {
        // İstek yapıldı ama backend'den cevap gelmedi (CORS veya backend kapalı)
        console.error("--- CEVAP ALINAMADI ---", err.request);
        setError("Backend'e Ulaşılamadı. Docker (api) ayakta mı? CORS hatası olabilir.");

      } else {
        // React'ta, isteği kurarken bir hata oldu
        console.error("--- İSTEK KURULURKEN HATA ---", err.message);
        setError(`React Hatası: ${err.message}`);
      }
    }
  };

  return (
    <div className="login-container">
      <form onSubmit={handleSubmit}>
        <h2>Admin Girişi</h2>
        <div>
          <label>Email:</label>
          <input
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
          />
        </div>
        <div>
          <label>Şifre:</label>
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
          />
        </div>
        <button type="submit">Giriş Yap</button>
        {error && <p className="error">{error}</p>}
      </form>
    </div>
  );
}

export default Login;