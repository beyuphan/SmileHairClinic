import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '/my_consultations/bloc/my_consultations_bloc.dart';
import '/my_consultations/bloc/my_consultations_event.dart';
import '/my_consultations/bloc/my_consultations_state.dart';
import '/services/api_service.dart';
import '/consultation/detail/view/consultation_detail_screen.dart';

class MyConsultationsScreen extends StatelessWidget {
  const MyConsultationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Bu ekrana özel bir BLoC oluştur
    return BlocProvider(
      create: (context) => MyConsultationsBloc(
        apiService: context.read<ApiService>(), // Depoyu al
      )..add(FetchMyConsultations()), // Ekran açılır açılmaz veriyi çek
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Geçmiş Konsültasyonlarım'),
        ),
        body: BlocBuilder<MyConsultationsBloc, MyConsultationsState>(
          builder: (context, state) {
            // DURUM 1: YÜKLENİYOR
            if (state is MyConsultationsLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            // DURUM 2: HATA
            if (state is MyConsultationsFailure) {
              return Center(
                child: Text('Hata: ${state.error}'),
              );
            }

            // DURUM 3: BAŞARILI
            if (state is MyConsultationsLoaded) {
              // Hiç kayıt yoksa
              if (state.consultations.isEmpty) {
                return const Center(
                  child: Text('Henüz bir konsültasyon kaydınız yok.'),
                );
              }

              // Kayıt varsa, ListView ile listele
              return ListView.builder(
                itemCount: state.consultations.length,
                itemBuilder: (context, index) {
                  final consultation = state.consultations[index];

                  // O thumbnail'i al (eğer varsa)
                  String thumbnailUrl = '';
                  if (consultation['photos'] != null && (consultation['photos'] as List).isNotEmpty) {
                    thumbnailUrl = consultation['photos'][0]['fileUrl'];
                  }

                  return Card(
                    margin: const EdgeInsets.all(8.0),
                    child: ListTile(
                      // Thumbnail'i yükle
                      leading: thumbnailUrl.isEmpty
                        ? const Icon(Icons.image_not_supported, size: 50)
                        : Image.network(thumbnailUrl, width: 50, height: 50, fit: BoxFit.cover),

                      // Durum (pending_review, completed vb.)
                      title: Text('Durum: ${consultation['status']}'),

                      // Tarih (şimdilik ham formatta)
                      subtitle: Text('Tarih: ${consultation['createdAt']}'),

                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ConsultationDetailScreen(
                                  consultationId: consultation['id'],
                                ),
                              ),
                            );
                      },
                    ),
                  );
                },
              );
            }

            // DURUM 4: Başlangıç (Initial)
            return const Center(child: Text('Yükleniyor...'));
          },
        ),
      ),
    );
  }
}