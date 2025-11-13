// client/app/lib/dashboard/view/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '/l10n/app_localizations.dart';

// --- YENİ İMPORTLAR ---
import '/my_consultations/bloc/my_consultations_bloc.dart';
import '/my_consultations/bloc/my_consultations_state.dart';
import '/consultation/view/photo_wizard_screen.dart'; 
import '/appointment/view/appointment_booking_screen.dart'; // Randevu ekranı

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
            // --- YENİ KART: RANDEVU AL BUTONU ---
            // 'MainHubScreen'den gelen 'MyConsultationsBloc'u dinle
            _buildAppointmentCard(context),

            const SizedBox(height: 20),

            // --- MEVCUT KART: YENİ KONSÜLTASYON ---
            Card(
              elevation: 4.0,
              child: InkWell(
                onTap: () {
                  // TODO: 'PhotoWizardScreen'e git
                    Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const PhotoWizardScreen(),
                    ),
                  );                },
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.camera_alt_outlined,
                        size: 48.0,
                        color: theme.colorScheme.primary,
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
            
            // Diğer dashboard widget'ları buraya eklenebilir
          ],
        ),
      ),
    );
  }
  
Widget _buildAppointmentCard(BuildContext context) {
    return BlocBuilder<MyConsultationsBloc, MyConsultationsState>(
      builder: (context, state) {
        if (state is MyConsultationsLoaded) {
          
          final consultationToBook = state.consultations.firstWhere(
            (c) => c['status'] == 'review_completed',
            orElse: () => null,
          );

          if (consultationToBook != null) {
            final String consultationId = consultationToBook['id'];
            // --- YENİ: Tarihi al ---
            final String dateStr = consultationToBook['createdAt']; 
            
            // Tarihi formatla (basitçe)
            final dateDisplay = DateTime.parse(dateStr).toLocal().toString().split(' ')[0]; 

            return Card(
              color: Theme.of(context).colorScheme.primary,
              elevation: 4.0,
              child: InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AppointmentBookingScreen(
                        consultationId: consultationId,
                        consultationDate: dateStr, // <-- YENİ: Tarihi yolla
                      ),
                    ),
                  );
                },
                child: Padding( // const'u kaldırdık çünkü değişken var
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.event_available_outlined,
                        size: 48.0,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 16.0),
                      const Text(
                        'Randevu Alın', 
                        style: TextStyle(
                          fontSize: 22, 
                          fontWeight: FontWeight.bold,
                          color: Colors.white
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      // --- YENİ: Hangi başvuru olduğunu yaz ---
                      Text(
                        '$dateDisplay tarihli başvurunuz onaylandı.\nHemen randevu seçebilirsiniz.',
                        style: const TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        }
        return const SizedBox.shrink(); 
      },
    );
  }
}