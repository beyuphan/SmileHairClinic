import 'package:flutter/material.dart';
import '/l10n/app_localizations.dart'; // Dil
import '/consultation/view/photo_wizard_screen.dart'; // Sihirbaz

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.homeScreenTitle), // Dil: "Ana Sayfa"
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // TODO: Burası "Dinamik Kartlar" ile dolacak
              // (örn: "Fotoğraflarınız inceleniyor...")
              const Text("Hoşgeldiniz!", style: TextStyle(fontSize: 24)),
              const SizedBox(height: 40),

              // "Yeni Konsültasyon" butonu buraya taşındı
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PhotoWizardScreen(),
                    ),
                  );
                },
                // Bu buton, "Tutkulu" (Koral) temamızı alacak
                child: Text(loc.startConsultationButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}