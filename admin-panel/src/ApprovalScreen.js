// admin-panel/src/ApprovalScreen.js
import React, { useState, useEffect } from 'react';
import apiService from './apiService';

function ApprovalScreen() {
  const [pending, setPending] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  // Veriyi çeken fonksiyon
  const fetchPending = async () => {
    try {
      setLoading(true);
      setError('');
      const response = await apiService.get('/consultations/admin/pending-approval');
      setPending(response.data);
    } catch (err) {
      console.error("Onay bekleyenler çekilemedi:", err);
      setError(err.response?.data?.message || "Veri çekilemedi.");
    } finally {
      setLoading(false);
    }
  };

  // Sayfa açılınca veriyi çek
  useEffect(() => {
    fetchPending();
  }, []);

  // Onaylama butonu
  const handleApprove = async (consultationId) => {
    try {
      await apiService.post(`/consultations/admin/approve/${consultationId}`);
      // Başarılı olursa, listeden (UI'dan) kaldır
      setPending(pending.filter(c => c.id !== consultationId));
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
        {pending.map(con => (
          <div key={con.id} className="approval-item">
            <div>
              <span className="patient-name">
                {con.patient.profile ? 
                  `${con.patient.profile.firstName} ${con.patient.profile.lastName}` : 
                  con.patient.email}
              </span>
              <span className="requested-date">
                Talep Edilen Tarih: {new Date(con.selectedSlot.dateTime).toLocaleString('tr-TR')}
              </span>
            </div>
            <button 
              className="approve-button"
              onClick={() => handleApprove(con.id)}
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