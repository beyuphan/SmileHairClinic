import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart'; 
import '/services/api_service.dart';
import '/appointment/bloc/appointment_bloc.dart';
import '/appointment/bloc/appointment_event.dart';
import '/appointment/bloc/appointment_state.dart';
// MyConsultationsBloc'a "listeyi yenile" demek için event'i import et
import '/my_consultations/bloc/my_consultations_bloc.dart';
import '/my_consultations/bloc/my_consultations_event.dart';

class AppointmentBookingScreen extends StatelessWidget {
  final String consultationId;
  final String consultationDate; // <-- YENİ: Tarihi de alıyoruz

  const AppointmentBookingScreen({
    super.key, 
    required this.consultationId,
    required this.consultationDate, // <-- Zorunlu yaptık
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AppointmentBloc(
        apiService: context.read<ApiService>(),
      )..add(FetchAvailableSlots()),
      // 'context.read<MyConsultationsBloc>()' ile üstteki BLoC'a erişeceğiz
      child: _AppointmentBookingView(
        consultationId: consultationId,
        consultationDate: consultationDate,
      ),
    );
  }
}

class _AppointmentBookingView extends StatelessWidget {
  final String consultationId;
  final String consultationDate;

  const _AppointmentBookingView({
    required this.consultationId,
    required this.consultationDate,
  });
  
  String _formatDateTime(String isoDate) {
    final date = DateTime.parse(isoDate).toLocal();
    return DateFormat.yMMMMEEEEd('tr_TR').add_Hm().format(date);
  }

  // Başvuru tarihini güzelleştirelim
  String _formatConsultationDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate).toLocal();
      return DateFormat.yMMMMd('tr_TR').format(date); // Örn: 14 Kasım 2025
    } catch (e) {
      return isoDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Randevu Seçimi'),
      ),
      body: Column(
        children: [
          // --- YENİ: BİLGİ KUTUSU (Hangi konsültasyon olduğunu göster) ---
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            child: Column(
              children: [
                Text(
                  "Şu başvurunuz için randevu alıyorsunuz:",
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatConsultationDate(consultationDate), // Tarihi göster
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          
          // Slot Listesi (BlocConsumer)
          Expanded(
            child: BlocConsumer<AppointmentBloc, AppointmentState>(
              listener: (context, state) {
                // --- 409 HATASINI VE BAŞARIYI YAKALA ---
                if (state is AppointmentBookingSuccess) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Randevu talebiniz alındı! Onay bekleniyor.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  // BİR ÖNCEKİ EKRANLARDAKİ LİSTEYİ GÜNCELLE
                  context.read<MyConsultationsBloc>().add(FetchMyConsultations());
                  Navigator.of(context).pop(); // Geri dön
                }
                
                if (state is AppointmentBookingFailure) {
                  // Hata mesajını 409'a [cite: user's request] göre ayarla
                  final bool isConflict409 = state.error.contains("409");
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isConflict409 
                        ? "Bu saat dolu! Lütfen başka bir saat seçin." 
                        : "Hata: ${state.error}"),
                      backgroundColor: Colors.red,
                    ),
                  );
                  // 409 ise liste güncel değil demektir, listeyi yenile
                  if (isConflict409) {
                    context.read<AppointmentBloc>().add(FetchAvailableSlots());
                  }
                }
              },
              builder: (context, state) {
                // ... (Loading, Failure, Empty, vb. aynı) ...
                 if (state is AppointmentSlotsLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is AppointmentSlotsFailure) {
                  return Center(child: Text('Slotlar yüklenemedi.'));
                }

                if (state is AppointmentSlotsLoaded) {
                  if (state.slots.isEmpty) {
                    return const Center(child: Text('Şu an boş randevu yok.'));
                  }
                  
                  return Stack(
                    children: [
                      ListView.builder(
                        itemCount: state.slots.length,
                        itemBuilder: (context, index) {
                          final slot = state.slots[index];
                          final String formattedDate = _formatDateTime(slot['dateTime']);
                          
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: ListTile(
                              leading: Icon(Icons.access_time_filled_outlined, color: Colors.green.shade700),
                              title: Text(formattedDate, style: const TextStyle(fontWeight: FontWeight.w600)),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: () {
                                context.read<AppointmentBloc>().add(
                                  BookSlot(
                                    slotId: slot['id'],
                                    consultationId: consultationId,
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                      
                      // Rezervasyon yaparken yükleniyor ekranı
                      if (state is AppointmentBookingInProgress)
                        Container(
                          color: Colors.black.withOpacity(0.5),
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(color: Colors.white),
                                SizedBox(height: 16),
                                Text('Randevu alınıyor...', style: TextStyle(color: Colors.white, fontSize: 16)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                }

                return const SizedBox.shrink(); // Initial state
              },
            ),
          ),
        ],
      ),
    );
  }
}