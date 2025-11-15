import React, { useState, useEffect, useCallback } from 'react';
import apiService from './apiService';

function ApprovalScreen() {
  const [pending, setPending] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  // Veriyi çeken fonksiyon (useCallback ile)
  const fetchPending = useCallback(async () => {
    try {
      setLoading(true);
      setError('');
      // HATA 1 ÇÖZÜMÜ: 'consultations' DEĞİL 'appointments'
      const response = await apiService.get('/appointments/admin/pending-approvals');
      setPending(response.data);
    } catch (err) {
      console.error("Onay bekleyenler çekilemedi:", err);
      setError(err.response?.data?.message || "Veri çekilemedi.");
    } finally {
      setLoading(false);
    }
  }, []); // Bu fonksiyon değişmez

  // Sayfa açılınca veriyi çek
  useEffect(() => {
    fetchPending();
  }, [fetchPending]);

  // Onaylama butonu
  const handleApprove = async (slotId) => { // <-- ARTIK 'slotId' ALIYOR
    try {
      // HATA 2 ÇÖZÜMÜ: 'consultations' DEĞİL 'appointments' ve 'slotId'
      await apiService.post(`/appointments/admin/approve/${slotId}`);
      
      // Başarılı olursa, listeyi yeniden çek (F5 atmadan)
      fetchPending(); 
      // setPending(pending.filter(c => c.id !== consultationId)); // <-- ESKİ YANLIŞ KOD
    } catch (err) {
      console.error("Onaylama hatası:", err);
      alert(err.response?.data?.message || "Onaylama başarısız.");
    }
  };

  return (
    <div className="content-card">
      <h2>Onay Bekleyen Randevular</h2>
      {loading && <p>Yükleniyor...</p>}
      {error && <p style={{ color: 'red' }}>{error}</p>}
      {!loading && pending.length === 0 && (
        <p>Onay bekleyen randevu bulunamadı.</p>
      )}
      
      <div className="approval-list">
        {/* 'con' (consultation) [cite: user's request] değil, 'slot' (AppointmentSlot) [cite: beyuphan/smilehairclinic/SmileHairClinic-22b33-4ffb13040d99316dd3963051f2cb/backend/prisma/schema.prisma] olarak map'liyoruz */}
        {pending.map(slot => (
          <div key={slot.id} className="approval-item">
            <div>
              <span className="patient-name">
                {/* Hasta bilgisi artık 'slot.patient' [cite: beyuphan/smilehairclinic/SmileHairClinic-22b33-4ffb13040d99316dd3963051f2cb/backend/prisma/schema.prisma] içinde */}
                {slot.patient.profile ? 
                  `${slot.patient.profile.firstName} ${slot.patient.profile.lastName}` : 
                  slot.patient.email}
              </span>
              <span className="requested-date">
                Talep Edilen Tarih: {new Date(slot.dateTime).toLocaleString('tr-TR')}
              </span>
            </div>
            <button 
              className="approve-button"
              // 'con.id' [cite: user's request] DEĞİL, 'slot.id' [cite: beyuphan/smilehairclinic/SmileHairClinic-22b33-4ffb13040d99316dd3963051f2cb/backend/prisma/schema.prisma] yolluyoruz
              onClick={() => handleApprove(slot.id)}
            >
              Onayla
            </button>
          </div>
        ))}
      </div>
    </div>
  );
}

export default ApprovalScreen;