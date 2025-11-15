// src/Messages.js
import React, { useState, useEffect, useRef, useCallback } from 'react';
import apiService, { setAuthToken } from './apiService'; // setAuthToken'a ihtiyacımız var
import { io } from 'socket.io-client';


const getAdminUserId = () => {
  const token = localStorage.getItem('adminToken');
  if (!token) return null;
  try {
    const payload = JSON.parse(atob(token.split('.')[1]));
    return payload.sub; // 'sub' (subject) genelde 'id'dir
  } catch (e) {
    console.error("Token decode edilemedi:", e);
    return null;
  }
};

// ------------------------------------------------------------------
// BİLEŞEN 1: Gerçek Zamanlı Sohbet Ekranı
// ------------------------------------------------------------------
function ChatView({ patient, adminUserId }) {
  const [messages, setMessages] = useState([]);
  const [newMessage, setNewMessage] = useState('');
  const [socket, setSocket] = useState(null);
  const messagesEndRef = useRef(null); // Sohbetin en altına kaymak için

  console.log("ChatView YÜKLENDİ. Gelen 'consultation' prop'u:", patient);  
  // En alta kaydırma fonksiyonu
  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  };

  // 1. ADIM: Danışmanlık değiştiğinde, eski mesajları çek ve socket'e bağlan
  useEffect(() => {
    if (!patient) {
      setMessages([]); // Hasta seçilmediyse mesajları temizle
      return;
    }
    
    let newSocket; // Socket'i dışarıda tanımla ki cleanup erişebilsin
    
    const setupChat = async () => {
      try {
        // --- a) ÖNCE eski mesajları çek (ve BEKLE) ---
        console.log(`API isteği atılıyor: /chat/history/${patient.id}`);

        // (URL'i '/chat/history/' olarak düzelttiğini varsayıyorum)
        const response = await apiService.get(`/chat/history/${patient.id}`);

        console.log("API'dan dönen HAM VERİ:", response.data);

        setMessages(response.data);

        // --- b) Eski mesajlar bittikten SONRA socket'i bağla ---
        const token = localStorage.getItem('adminToken');
        
        newSocket = io('http://localhost:3000', {
          extraHeaders: {
            'Authorization': `Bearer ${token}` // Flutter gibi
          }
        });

        newSocket.on('connect', () => {
          console.log('Socket.IO bağlandı. Odaya giriliyor:', patient.id);
          newSocket.emit('joinRoom', { targetUserId: patient.id });
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
    
  }, [patient]);

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
      targetUserId: patient.id,
      content: newMessage,
    });
    
    setNewMessage('');
  };

  if (!patient) {
    return <div className="chat-view-placeholder">Hasta seçilmedi.</div>;
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
  // --- Değişiklik 1: State isimlerini güncelleyelim ---
  const [patientList, setPatientList] = useState([]); // consultations -> patientList
  const [selectedPatient, setSelectedPatient] = useState(null); // selectedConsultation -> selectedPatient
  const [loading, setLoading] = useState(true);
  
  // ... (getAdminUserId fonksiyonu aynı kalabilir) ...
  const adminUserId = getAdminUserId();

  // --- Değişiklik 2: Yeni endpoint'i çağıralım ---
  useEffect(() => {
    const fetchPatientList = async () => {
      try {
        setLoading(true);
        console.log("API isteği atılıyor: /chat/patient-list");

        // /consultations/admin/all YERİNE yeni endpoint'i çağır
        const response = await apiService.get('/chat/patient-list'); 

        console.log("API'DAN HASTA LİSTESİ GELDİ (HAM VERİ):", response.data);
        setPatientList(response.data);
      } catch (error) {
        
        console.error("Hasta listesi çekilemedi:", error);
      } finally {
        setLoading(false);
      }
    };
    
    fetchPatientList();
  }, []);

  return (
    <div className="content-card messages-layout">
      {/* Sol Taraf: Hasta Listesi (DÜZELTİLMİŞ) */}
      <div className="consultation-list"> {/* CSS class'ı aynı kalabilir */}
        <h3>Tüm Hastalar</h3>
        {loading ? (
          <p>Yükleniyor...</p>
        ) : (
          <ul>
            {/* --- Değişiklik 3: patientList üzerinden map yap --- */}
            {patientList.map(patient => {
              // Backend'den çektiğimiz son başvuruyu al
              const latestConsultation = patient.consultations?.[0];

              return (
                <li 
                  key={patient.id} // Artık patient.id
                  // Durumu son başvurudan al VEYA 'Yeni Hasta' de
                  data-status={latestConsultation?.status.toLowerCase() || 'new'}
                  className={selectedPatient?.id === patient.id ? 'active' : ''}
                  onClick={() => setSelectedPatient(patient)} // Tıklayınca patient'ı set et
                >
                  {/* --- Değişiklik 4: Veriyi direkt patient'tan al --- */}
                  <span className="patient-name">
                    {patient.profile ? 
                      `${patient.profile.firstName} ${patient.profile.lastName}` : 
                      patient.email}
                  </span>

                  <div className="consultation-details">
                    <span className="consultation-date">
                      {/* Varsa başvuru tarihi, yoksa kayıt tarihi */}
                      {new Date(latestConsultation?.createdAt || patient.createdAt).toLocaleDateString('tr-TR')}
                    </span>
                    <span className="consultation-status">
                      {/* Varsa durum, yoksa 'Yeni Hasta' vb. */}
                      {latestConsultation ? latestConsultation.status.replace('_', ' ') : 'Yeni Hasta'}
                    </span>
                  </div>
                </li>
              );
            })}
          </ul>
        )}
      </div>
      
      {/* --- Değişiklik 5: ChatView'e 'patient' prop'u gönder --- */}
      <ChatView 
        patient={selectedPatient} // consultation -> patient
        adminUserId={adminUserId}
      />
    </div>
  );
}
export default Messages;