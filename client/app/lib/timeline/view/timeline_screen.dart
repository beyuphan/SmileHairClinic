import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '/l10n/app_localizations.dart'; // Dil
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

// Az önce oluşturduğumuz BLoC dosyaları
import '/timeline/bloc/timeline_bloc.dart';
import '/timeline/bloc/timeline_event.dart';
import '/timeline/bloc/timeline_state.dart';
import '/consultation/view/photo_wizard_screen.dart';

import '/services/api_service.dart'; // ApiService (Depo)

class TimelineScreen extends StatelessWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    // Bu ekrana özel bir BLoC oluştur
    return BlocProvider(
      create: (context) => TimelineBloc(
        apiService: context.read<ApiService>(), // Depoyu al
      )..add(FetchTimeline()), // <-- Ekran açılır açılmaz veriyi çek

      child: Scaffold(
        appBar: AppBar(
          title: const Text("Yolculuğum"), // TODO: Bunu dile (l10n) ekle
        ),
        body: BlocBuilder<TimelineBloc, TimelineState>(
          builder: (context, state) {

            // DURUM 1: YÜKLENİYOR
            if (state is TimelineLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            // DURUM 2: HATA
            if (state is TimelineFailure) {
              return Center(
                child: Text('Hata: ${state.error}'),
              );
            }

            // DURUM 3: BAŞARILI
            if (state is TimelineLoaded) {
              // Hiç görev yoksa
              if (state.events.isEmpty) {
                return const Center(
                  child: Text('Henüz bir yolculuk planınız yok.'),
                );
              }

              // Görevler varsa, ListView ile listele
              return ListView.builder(
                    padding: const EdgeInsets.all(8.0),
                    itemCount: state.events.length,
                    itemBuilder: (context, index) {
                      final event = state.events[index];
                      
                      // O "Zenginleştirme" (Video/Yükleme) kısmını buraya ekliyoruz
                      final String eventType = event['type'] ?? 'INFO';
                      final String? videoUrl = event['videoUrl'];

                      return Card(
                        elevation: 4.0,
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. Görev Başlığı (İkonlu)
                              Row(
                                children: [
                                  Icon(
                                    event['isCompleted'] 
                                      ? Icons.check_circle 
                                      : Icons.radio_button_unchecked,
                                    color: event['isCompleted'] 
                                      ? Colors.green 
                                      : Colors.grey,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      event['title'],
                                      style: Theme.of(context).textTheme.titleLarge,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              
                              // 2. Görev Tarihi
                              Text(
                                'Tarih: ${event['eventDate']}', // TODO: Tarihi formatla
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 16),
                              
                              // 3. Görev Açıklaması
                              Text(
                                event['description'] ?? '',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              
                              // 4. ZENGİNLEŞTİRME (VİDEO)
                              if (eventType == 'VIDEO' && videoUrl != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 16.0),
                                  child: YoutubePlayer( // <-- VİDEO OYNATICI
                                    controller: YoutubePlayerController(
                                      initialVideoId: YoutubePlayer.convertUrlToId(videoUrl) ?? '',
                                      flags: const YoutubePlayerFlags(
                                        autoPlay: false,
                                      ),
                                    ),
                                    showVideoProgressIndicator: true,
                                  ),
                                ),
                                
                              // 5. ZENGİNLEŞTİRME (FOTO YÜKLEME)
                              if (eventType == 'UPLOAD')
                                Padding(
                                  padding: const EdgeInsets.only(top: 16.0),
                                  child: ElevatedButton.icon( // <-- "TUTKULU" BUTON
                                    onPressed: () {
                                      // O "Akıllı Sihirbazı" tekrar çağır
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => const PhotoWizardScreen(),
                                          // TODO: Sihirbaza 'post_op_1_month' gibi bir 'tag' yolla
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.camera_alt_outlined),
                                    label: const Text('İlerleme Fotoğrafı Yükle'),
                                  ),
                                ),
                                
                            ],
                          ),
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