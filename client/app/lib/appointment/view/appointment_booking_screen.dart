import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '/services/api_service.dart';
import '/appointment/bloc/appointment_bloc.dart';
import '/appointment/bloc/appointment_event.dart';
import '/appointment/bloc/appointment_state.dart';
// MyConsultationsBloc'a artık sinyal vermiyoruz, o kaldırıldı.

class AppointmentBookingScreen extends StatelessWidget {
  // --- ARTIK PARAMETRE ALMIYOR ---
  const AppointmentBookingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AppointmentBloc(
        apiService: context.read<ApiService>(),
      )..add(FetchAvailableSlots()), // BLoC'u yaratır yaratmaz slotları çek
      child: const _AppointmentBookingView(),
    );
  }
}

class _AppointmentBookingView extends StatelessWidget {
  const _AppointmentBookingView();
  
  String _formatDateTime(String isoDate) {
    final date = DateTime.parse(isoDate).toLocal();
    return DateFormat.yMMMMEEEEd('tr_TR').add_Hm().format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Randevu Tarihi Seçin'),
      ),
      body: Column(
        children: [
          // --- O "Hangi başvuru..." [user's previous turn] BİLGİ KUTUSU KALDIRILDI ---
          
          // Slot Listesi (BlocConsumer)
          Expanded(
            child: BlocConsumer<AppointmentBloc, AppointmentState>(
              listener: (context, state) {
                if (state is AppointmentBookingSuccess) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Randevunuz rezerve edildi! Admin onayı bekleniyor.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  // Artık MyConsultationsBloc'u güncellemeye gerek yok
                  Navigator.of(context).pop(); // Geri dön
                }
                
                if (state is AppointmentBookingFailure) {
                  final bool isConflict409 = state.error.contains("409");
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isConflict409 
                        ? "Bu saat dolu! Lütfen başka bir saat seçin." 
                        : "Hata: ${state.error}"),
                      backgroundColor: Colors.red,
                    ),
                  );
                  if (isConflict409) {
                    context.read<AppointmentBloc>().add(FetchAvailableSlots());
                  }
                }
              },
              builder: (context, state) {
                // ... (Loading, Failure, Empty aynı) ...
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
                                // --- ARTIK 'consultationId' YOK ---
                                context.read<AppointmentBloc>().add(
                                  BookSlot(slotId: slot['id']),
                                );
                              },
                            ),
                          );
                        },
                      ),
                      
                      if (state is AppointmentBookingInProgress)
                        Container(
                          // ... (Yükleniyor ekranı aynı) ...
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