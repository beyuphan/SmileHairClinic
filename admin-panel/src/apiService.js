// src/apiService.js
import axios from 'axios';

// Backend'imizin ana adresi (docker-compose'dan)
const API_URL = 'http://localhost:3000';

// Axios'un temel ayarlarını yapıyoruz
const apiService = axios.create({
  baseURL: API_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Bu çok önemli: Login olduktan sonra alacağımız JWT token'ı
// her API isteğinin kafasına (Header) otomatik eklemesini sağlayacağız.
export const setAuthToken = (token) => {
  if (token) {
    // Token varsa, her isteğe 'Authorization' başlığını ekle
    apiService.defaults.headers.common['Authorization'] = `Bearer ${token}`;
  } else {
    // Token yoksa (logout), bu başlığı sil
    delete apiService.defaults.headers.common['Authorization'];
  }
};

export default apiService;