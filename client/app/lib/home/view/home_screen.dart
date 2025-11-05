import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '/auth/bloc/auth_bloc.dart';
import '/auth/bloc/auth_event.dart';
import '/consultation/view/photo_wizard_screen.dart';
import '/my_consultations/view/my_consultations_screen.dart'; 
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ana Sayfa'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // Çıkış yap event'ini BLoC'a gönder
              context.read<AuthBloc>().add(AuthLogoutRequested());
            },
          )
        ],
      ),
     body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Giriş Başarılı!'),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const MyConsultationsScreen(),
                  ),
                );
              },
              child: const Text('Geçmiş Konsültasyonlarım'),
            ),
            // --- YENİ BUTON BİTTİ ---

            const SizedBox(height: 20),
            // YENİ BUTON
            ElevatedButton(
              onPressed: () {
                // Sihirbaz ekranına yönlendir
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PhotoWizardScreen(),
                  ),
                );
              },
              child: const Text('Yeni Konsültasyon Başlat'),
            ),
          ],
        ),
      ),
    );
  }
}