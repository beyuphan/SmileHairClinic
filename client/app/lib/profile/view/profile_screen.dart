import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '/l10n/app_localizations.dart'; // Dil
import '/auth/bloc/auth_bloc.dart';
import '/auth/bloc/auth_event.dart';
import '/my_consultations/view/my_consultations_screen.dart'; 

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'), // TODO: Bunu da dile ekle
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_pin, size: 80),
              const SizedBox(height: 20),
              // TODO: Buraya 'authBloc.state.user.email' gibi bir şey gelecek
              const Text("test@kullanici.com"), 
              const SizedBox(height: 40),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary, // Ana Renk (Teal)
                ),
                onPressed: () {
                   Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MyConsultationsScreen(),
                    ),
                  );
                },
                child: Text(loc.myConsultationsButton),
              ),
              const SizedBox(height: 10),

              // Çıkış Yap butonu buraya taşındı
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[700], // Temadan farklı
                ),
                onPressed: () {
                  context.read<AuthBloc>().add(AuthLogoutRequested());
                },
                child: Text(loc.logoutButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}