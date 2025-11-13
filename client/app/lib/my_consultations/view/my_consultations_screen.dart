import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '/my_consultations/bloc/my_consultations_bloc.dart';
import '/my_consultations/bloc/my_consultations_event.dart';
import '/my_consultations/bloc/my_consultations_state.dart';
// import '/services/api_service.dart'; // Artık BlocProvider burada değil, gerek yok
import '/consultation/detail/view/consultation_detail_screen.dart';
import '/chat/view/chat_screen.dart'; 
import 'package:intl/intl.dart'; // Tarih formatlama için

class MyConsultationsScreen extends StatelessWidget {
  const MyConsultationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Geçmiş Konsültasyonlarım'),
      ),
      // --- YENİ: AŞAĞI ÇEKİNCE YENİLE ---
      body: RefreshIndicator(
        onRefresh: () async {
          // BLoC'a "Yeniden Çek" emri ver
          context.read<MyConsultationsBloc>().add(FetchMyConsultations());
          // BLoC'un 'MyConsultationsLoaded' state'ini yaymasını bekle
          await context.read<MyConsultationsBloc>().stream.firstWhere(
                (state) => state is MyConsultationsLoaded || state is MyConsultationsFailure
              );
        },
        child: BlocBuilder<MyConsultationsBloc, MyConsultationsState>(
          builder: (context, state) {
            // ... (Loading, Failure aynı) ...

            if (state is MyConsultationsLoaded) {
              if (state.consultations.isEmpty) {
                // ... (Empty kontrolü aynı) ...
              }

              return ListView.builder(
                // ListView'ın her zaman kaydırılabilir olması lazım ki Refresh çalışsın
                physics: const AlwaysScrollableScrollPhysics(), 
                itemCount: state.consultations.length,
                itemBuilder: (context, index) {
                  final consultation = state.consultations[index];
                  final String status = consultation['status'];
                  final String consultationId = consultation['id'];
                  
                  // Tarihi formatla
                  String formattedDate = '';
                  try {
                     formattedDate = DateFormat.yMMMMd('tr_TR')
                        .format(DateTime.parse(consultation['createdAt']).toLocal());
                  } catch(e) { /* ignore */ }
                  
                  String thumbnailUrl = '';
                  if (consultation['photos'] != null && (consultation['photos'] as List).isNotEmpty) {
                    thumbnailUrl = consultation['photos'][0]['fileUrl'];
                  }

                  return Card(
                    margin: const EdgeInsets.all(8.0),
                    child: ListTile(
                      leading: thumbnailUrl.isEmpty
                        ? const Icon(Icons.image_not_supported, size: 50)
                        : Image.network(thumbnailUrl, width: 50, height: 50, fit: BoxFit.cover),
                      
                      title: Text('Durum: $status'),
                      subtitle: Text('Başvuru: $formattedDate'), // 'createdAt' yerine
                      
                      trailing: IconButton(
                            icon: const Icon(Icons.chat_bubble_outline),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    consultationId: consultationId,
                                  ),
                                ),
                              );
                            },
                          ),
                      onTap: () {
                        Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ConsultationDetailScreen(
                                  consultationId: consultationId,
                                ),
                              ),
                            );
                      },
                    ),
                  );
                },
              );
            }
            return const Center(child: Text('Yükleniyor...'));
          },
        ),
      ),
    );
  }
}