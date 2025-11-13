// src/SlotManager.js
import React, { useState, useEffect, useCallback } from 'react';
import Calendar from 'react-calendar';
import 'react-calendar/dist/Calendar.css';
import apiService from './apiService';

// ------------------------------------------------------------------
// BİLEŞEN 1: SlotList (Sağ Taraf - Artık "Dumb" bir bileşen)
// ------------------------------------------------------------------
// Bu bileşen artık veri çekmiyor. Sadece 'slots'u ve 'onDelete' fonksiyonunu alıyor.
function SlotList({ slots, loading, onDelete }) {
  
  const handleDeleteClick = async (slotId) => {
    // Emin misin diye sor
    if (!window.confirm("Bu slotu silmek istediğinize emin misiniz?")) {
      return;
    }
    
    try {
      // Backend'e silme isteği at
      await apiService.delete(`/appointments/admin/delete-slot/${slotId}`);
      // Başarılıysa, ana bileşene "listeyi yenile" sinyali yolla
      onDelete(); 
    } catch (error) {
      console.error("Slot silinemedi:", error);
      alert(error.response?.data?.message || "Bir hata oluştu.");
    }
  };

  if (loading) return <p>Boş slotlar yükleniyor...</p>;

  return (
    <div className="slot-list">
      <h3>Gelecek Randevu Slotları</h3>
      {slots.length === 0 ? (
        <p>Gelecek için boş slot bulunamadı.</p>
      ) : (
        <ul>
          {slots.map(slot => (
            <li key={slot.id}>
              <span>
                {slot.dateTime.toLocaleString('tr-TR', {
                  year: 'numeric',
                  month: 'long',
                  day: 'numeric',
                  hour: '2-digit',
                  minute: '2-digit',
                })}
              </span>
              {/* YENİ SİL BUTONU */}
              <button 
                onClick={() => handleDeleteClick(slot.id)} 
                className="delete-slot-button"
              >
                Sil
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

// ------------------------------------------------------------------
// BİLEŞEN 2: SlotCreator (Sol Taraf)
// ------------------------------------------------------------------
// Bu bileşen de 'onSlotAdded' fonksiyonunu alıyor
function SlotCreator({ onSlotAdded }) {
  const [date, setDate] = useState(new Date());
  const [time, setTime] = useState('09:00');
  const [message, setMessage] = useState('');
  const [isError, setIsError] = useState(false);

  // --- YENİ DROPDOWN MANTIĞI ---
  // Yarım saatlik aralıklarla (00:00 - 23:30) bir array oluştur
  const generateTimeOptions = () => {
    const options = [];
    for (let h = 0; h < 24; h++) {
      const hour = h.toString().padStart(2, '0');
      options.push(`${hour}:00`);
      options.push(`${hour}:30`);
    }
    return options;
  };
  const timeOptions = generateTimeOptions();

  const handleSubmitSlot = async () => {
    setMessage('');
    setIsError(false);
    
    try {
      const selectedDate = new Date(date);
      const [hours, minutes] = time.split(':');
      selectedDate.setHours(parseInt(hours, 10));
      selectedDate.setMinutes(parseInt(minutes, 10));
      selectedDate.setSeconds(0);
      
      // Düzeltilmiş URL (benim 404 hatam)
      await apiService.post('/appointments/admin/create-slot', {
        dateTime: selectedDate,
      });

      setMessage(`Slot başarıyla eklendi: ${selectedDate.toLocaleString('tr-TR')}`);
      // BAŞARILI OLUNCA, ANA BİLEŞENE SİNYAL YOLLA:
      onSlotAdded();
      
    } catch (err) {
      setMessage(err.response?.data?.message || 'Hata: Slot eklenemedi.');
      setIsError(true);
      console.error(err);
    }
  };

  return (
    <div className="slot-creator">
      <h4>Yeni Slot Ekle</h4>
      <p>1. Takvimden bir GÜN seçin:</p>
      <Calendar onChange={setDate} value={date} />
      
      <p>2. Bir SAAT seçin:</p>
      <div className="time-picker">
        <select 
          className="time-dropdown" 
          value={time}
          onChange={(e) => setTime(e.target.value)}
        >
          {timeOptions.map(option => (
            <option key={option} value={option}>
              {option}
            </option>
          ))}
        </select>
      </div>
      
      <button onClick={handleSubmitSlot}>
        Slot Oluştur
      </button>
      
      {message && (
        <p className={`message ${isError ? 'error' : 'success'}`}>
          {message}
        </p>
      )}
    </div>
  );
}

// ------------------------------------------------------------------
// BİLEŞEN 3: SlotManager (Ana Konteyner)
// ------------------------------------------------------------------
// Artık tüm state ve veri çekme mantığı burada.
function SlotManager() {
  const [slots, setSlots] = useState([]);
  const [loading, setLoading] = useState(true);

  // VERİ ÇEKME FONKSİYONU
  // 'useCallback' React'ın gereksiz yere fonksiyonu yeniden yaratmasını engeller
  const fetchSlots = useCallback(async () => {
    try {
      setLoading(true);
      const response = await apiService.get('/appointments/available-slots');
      const sortedSlots = response.data
        .map(slot => ({ ...slot, dateTime: new Date(slot.dateTime) }))
        .sort((a, b) => a.dateTime - b.dateTime);
      setSlots(sortedSlots);
    } catch (error) {
      console.error("Slotlar çekilemedi:", error);
    } finally {
      setLoading(false);
    }
  }, []); // Boş array, bu fonksiyonun kendisi değişmez

  // İLK YÜKLEME: Sayfa ilk açıldığında slotları çek
  useEffect(() => {
    fetchSlots();
  }, [fetchSlots]); // 'fetchSlots'a bağımlı

  return (
    <div className="content-card">
      <h2>Randevu Slot Yöneticisi</h2>
      <div className="slot-manager">
        
        {/* Sol Taraf: Yaratma */}
        <SlotCreator 
          onSlotAdded={fetchSlots} // Ekleme başarılı olursa 'fetchSlots'u tetikle
        />
        
        {/* Sağ Taraf: Liste */}
        <SlotList 
          slots={slots} 
          loading={loading} 
          onDelete={fetchSlots} // Silme başarılı olursa 'fetchSlots'u tetikle
        />
        
      </div>
    </div>
  );
}

export default SlotManager;