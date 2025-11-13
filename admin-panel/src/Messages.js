// src/Messages.js
import React, { useState, useEffect, useRef, useCallback } from 'react';
import apiService, { setAuthToken } from './apiService'; // setAuthToken'a ihtiyacımız var
import { io } from 'socket.io-client';

// ------------------------------------------------------------------
// BİLEŞEN 1: Gerçek Zamanlı Sohbet Ekranı
// ------------------------------------------------------------------
function ChatView({ consultation, adminUserId }) {
  const [messages, setMessages] = useState([]);
  const [newMessage, setNewMessage] = useState('');
  const [socket, setSocket] = useState(null);
  const messagesEndRef = useRef(null); // Sohbetin en altına kaymak için

  // En alta kaydırma fonksiyonu
  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  };

  // 1. ADIM: Danışmanlık değiştiğinde, eski mesajları çek ve socket'e bağlan
  useEffect(() => {
    if (!consultation) return;
    
    let newSocket; // Socket'i dışarıda tanımla ki cleanup erişebilsin
    
    const setupChat = async () => {
      try {
        // --- a) ÖNCE eski mesajları çek (ve BEKLE) ---
        // (URL'i '/chat/history/' olarak düzelttiğini varsayıyorum)
        const response = await apiService.get(`/chat/history/${consultation.id}`);
        setMessages(response.data);

        // --- b) Eski mesajlar bittikten SONRA socket'i bağla ---
        const token = localStorage.getItem('adminToken');
        
        newSocket = io('http://localhost:3000', {
          extraHeaders: {
            'Authorization': `Bearer ${token}` // Flutter gibi
          }
        });

        newSocket.on('connect', () => {
          console.log('Socket.IO bağlandı. Odaya giriliyor:', consultation.id);
          newSocket.emit('joinRoom', { consultationId: consultation.id });
        });

        // 'newMessage' event'ini dinle
        // Bu artık 'fetchHistory'den sonra çalıştığı için GÜVENLİ
        newSocket.on('newMessage', (messageData) => {
          setMessages((prevMessages) => [...prevMessages, messageData]);
        });

        newSocket.on('connect_error', (err) => {
          console.error("Socket bağlantı hatası:", err.message);
        });

        setSocket(newSocket);

      } catch (error) {
        console.error("Sohbet kurulum hatası:", error);
      }
    };
    
    setupChat(); // Async fonksiyonu çalıştır

    // --- c) Bileşen kapandığında (veya değiştiğinde) socket'i kapat ---
    return () => {
      console.log("Socket kapatılıyor.");
      if (newSocket) {
        newSocket.off('newMessage');
        newSocket.disconnect();
      }
    };
    
  }, [consultation]);

  // 2. ADIM: Mesajlar yüklendiğinde en alta kaydır
  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  // 3. ADIM: Mesaj gönderme
  const handleSendMessage = (e) => {
    e.preventDefault();
    if (!newMessage.trim() || !socket) return;

    // ChatGateway'deki 'sendMessage' event'ini tetikle
    socket.emit('sendMessage', {
      consultationId: consultation.id,
      messageContent: newMessage,
    });
    
    setNewMessage('');
  };

  if (!consultation) {
    return <div className="chat-view-placeholder">Konuşma seçilmedi.</div>;
  }

  return (
    <div className="chat-view">
      {/* Mesaj Baloncukları */}
      <div className="messages-list">
        {messages.map((msg, index) => {
          // 'adminUserId' (giriş yapan admin) ile mesajın 'senderId'sini karşılaştır
          const isMe = msg.senderId === adminUserId;
          return (
            <div key={index} className={`message-bubble ${isMe ? 'me' : 'them'}`}>
              <p>{msg.messageContent}</p>
              <span>{new Date(msg.timestamp).toLocaleTimeString('tr-TR', { hour: '2-digit', minute: '2-digit' })}</span>
            </div>
          );
        })}
        <div ref={messagesEndRef} />
      </div>
      
      {/* Mesaj Yazma Alanı */}
      <form className="message-input-form" onSubmit={handleSendMessage}>
        <input
          type="text"
          value={newMessage}
          onChange={(e) => setNewMessage(e.target.value)}
          placeholder="Mesajınızı yazın..."
        />
        <button type="submit">Gönder</button>
      </form>
    </div>
  );
}

// ------------------------------------------------------------------
// BİLEŞEN 2: Ana Mesajlar Sayfası (Listeyi Çeken)
// ------------------------------------------------------------------
function Messages() {
  const [consultations, setConsultations] = useState([]);
  const [selectedConsultation, setSelectedConsultation] = useState(null);
  const [loading, setLoading] = useState(true);
  
  // Admin'in kendi ID'sini al (ChatView'de 'isMe' kontrolü için)
  const getAdminUserId = () => {
    const token = localStorage.getItem('adminToken');
    if (!token) return null;
    try {
      // Token'ı (JWT) decode et (basit JS yolu)
      const payload = JSON.parse(atob(token.split('.')[1]));
      return payload.sub; // 'sub' (subject) genelde 'id'dir
    } catch (e) {
      console.error("Token decode edilemedi:", e);
      return null;
    }
  };
  const adminUserId = getAdminUserId();

  // Sayfa ilk yüklendiğinde, admin için tüm odaları çek
  useEffect(() => {
    const fetchConsultations = async () => {
      try {
        setLoading(true);
        // 1. Adım'da yaptığımız YENİ ENDPOINT'i çağır
        const response = await apiService.get('/consultations/admin/all');
        setConsultations(response.data);
      } catch (error) {
        console.error("Danışmanlıklar çekilemedi:", error);
      } finally {
        setLoading(false);
      }
    };
    
    fetchConsultations();
  }, []);

  return (
    <div className="content-card messages-layout">
      {/* Sol Taraf: Hasta Listesi */}
      <div className="consultation-list">
        <h3>Tüm Görüşmeler</h3>
        {loading ? (
          <p>Yükleniyor...</p>
        ) : (
          <ul>
            {consultations.map(con => (
              <li 
                key={con.id}
                data-status={con.status.toLowerCase()}
                className={selectedConsultation?.id === con.id ? 'active' : ''}
                onClick={() => setSelectedConsultation(con)}
              >
                {/* Hastanın adını veya email'ini yaz */}
                <span className="patient-name">
                  {con.patient.profile ? 
                    `${con.patient.profile.firstName} ${con.patient.profile.lastName}` : 
                    con.patient.email}
                </span>

                {/* YENİ: Başvuru tarihi ve durumu */}
                <div className="consultation-details">
                  <span className="consultation-date">
                    {new Date(con.createdAt).toLocaleDateString('tr-TR')}
                  </span>
                  <span className="consultation-status">
                    {con.status.replace('_', ' ')} {/* Alttan tireyi boşluğa çevir */}
                  </span>
                </div>

                <span className="consultation-status">
                  {con.status}
                </span>
              </li>
            ))}
          </ul>
        )}
      </div>
      
      {/* Sağ Taraf: Sohbet Ekranı */}
      <ChatView 
        consultation={selectedConsultation} 
        adminUserId={adminUserId}
      />
    </div>
  );
}

export default Messages;