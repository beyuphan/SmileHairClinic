import 'package:flutter/material.dart';
import '/l10n/app_localizations.dart';
import '/appointment/view/appointment_booking_screen.dart'; // Randevu ekranı
import '/consultation/view/photo_wizard_screen.dart'; // Foto yükleme ekranı

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dashboardTitle),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            
            // --- 1. KART: RANDEVU AL (ARTIK ÖZGÜR) ---
            // "Önce Kap, Sonra Konuş" mantığı.
            // Buton artık hep burada. BlocBuilder'a gerek yok.
            Card(
              color: theme.colorScheme.primary, // Vurgulu renk
              elevation: 4.0,
              child: InkWell(
                onTap: () {
                  // Tıklayınca Randevu Ekranına git (Parametresiz)
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AppointmentBookingScreen(),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.event_available_outlined,
                        size: 48.0,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 16.0),
                      Text(
                        "Randevu Alın",
                        style: const TextStyle(
                          fontSize: 22, 
                          fontWeight: FontWeight.bold,
                          color: Colors.white
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      Text(
                        "Boş tarihleri görmek için tıklayın...",
                        style: const TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 20),

            // --- 2. KART: YENİ KONSÜLTASYON ---
            Card(
              elevation: 4.0,
              child: InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const PhotoWizardScreen(),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.camera_alt_outlined,
                        size: 48.0,
                        color: theme.colorScheme.secondary, // Rengi değiştirebilirsin
                      ),
                      const SizedBox(height: 16.0),
                      Text(
                        l10n.dashboardNewConsultationTitle,
                        style: theme.textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8.0),
                      Text(
                        l10n.dashboardNewConsultationSubtitle,
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
          ],
        ),
      ),
    );
  }
}