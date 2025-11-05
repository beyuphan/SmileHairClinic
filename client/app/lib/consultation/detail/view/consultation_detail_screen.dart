import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '/consultation/detail/bloc/consultation_detail_bloc.dart';
import '/consultation/detail/bloc/consultation_detail_event.dart';
import '/consultation/detail/bloc/consultation_detail_state.dart';
import '/services/api_service.dart';

class ConsultationDetailScreen extends StatelessWidget {
  // Önceki ekrandan (listeden) tıklanan kaydın ID'sini al
  final String consultationId;

  const ConsultationDetailScreen({
    super.key,
    required this.consultationId,
  });

  @override
  Widget build(BuildContext context) {
    // Bu ekrana özel bir BLoC oluştur
    return BlocProvider(
      create: (context) => ConsultationDetailBloc(
        apiService: context.read<ApiService>(), // Depoyu al
      )..add(FetchConsultationDetail(consultationId)), // Ekran açılır açılmaz veriyi çek
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Konsültasyon Detayı'),
        ),
        body: BlocBuilder<ConsultationDetailBloc, ConsultationDetailState>(
          builder: (context, state) {
            // DURUM 1: YÜKLENİYOR
            if (state is ConsultationDetailLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            // DURUM 2: HATA
            if (state is ConsultationDetailFailure) {
              return Center(
                child: Text('Detaylar yüklenemedi: ${state.error}'),
              );
            }

            // DURUM 3: BAŞARILI
            if (state is ConsultationDetailLoaded) {
              final consultation = state.consultation;
              final List photos = consultation['photos'] ?? [];

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Durum ve Tarih Bilgisi
                    Text(
                      'Mevcut Durum: ${consultation['status']}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text('Oluşturulma Tarihi: ${consultation['createdAt']}'),
                    const Divider(height: 30),

                    // Fotoğraf Galerisi
                    Text(
                      'Yüklenen Fotoğraflar (${photos.length} adet)',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),

                    // 6 fotoğrafı Grid'de göster
                    GridView.builder(
                      shrinkWrap: true, // ScrollView içinde olduğu için
                      physics: const NeverScrollableScrollPhysics(), // ScrollView'a devret
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, // Yan yana 2 adet
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.75, // En/Boy oranı
                      ),
                      itemCount: photos.length,
                      itemBuilder: (context, index) {
                        final photo = photos[index];
                        final secureUrl = photo['fileUrl']; // Güvenli, geçici URL

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Fotoğraf
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  secureUrl,
                                  fit: BoxFit.cover,
                                  // Yüklenirken dönen çark
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return const Center(child: CircularProgressIndicator());
                                  },
                                  // Hata olursa (ki olmamalı)
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(Icons.broken_image, size: 50, color: Colors.red);
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            // Açı Etiketi (front, top, vb.)
                            Text(
                              photo['angleTag'],
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        );
                      },
                    ),

                    // TODO: Doktor Notları ve Tıbbi Form Verileri de buraya eklenebilir
                  ],
                ),
              );
            }

            // DURUM 4: Başlangıç (Initial)
            return const Center(child: Text('Detaylar getiriliyor...'));
          },
        ),
      ),
    );
  }
}