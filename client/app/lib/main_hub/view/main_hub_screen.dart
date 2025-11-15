// client/app/lib/main_hub/view/main_hub_screen.dart
import 'package:app/chat/view/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '/dashboard/view/dashboard_screen.dart';
import '/my_consultations/view/my_consultations_screen.dart';
import '/profile/view/profile_screen.dart';
import '/l10n/app_localizations.dart';


// --- YENİ İMPORTLAR ---
import '/my_consultations/bloc/my_consultations_bloc.dart';
import '/my_consultations/bloc/my_consultations_event.dart';
import '/services/api_service.dart';

class MainHubScreen extends StatefulWidget {
  const MainHubScreen({super.key});

  @override
  State<MainHubScreen> createState() => _MainHubScreenState();
}

class _MainHubScreenState extends State<MainHubScreen> {
  int _selectedIndex = 0;

  // Ana Sayfa, Geçmiş, Takvim, Profil
  static const List<Widget> _widgetOptions = <Widget>[
    DashboardScreen(),
    MyConsultationsScreen(),
    ChatScreen(),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // --- YENİ MANTIK BURADA ---
    // BLoC'u 'MyConsultationsScreen'den alıp buraya,
    // yani tüm sekmelerin üstüne 'BlocProvider' olarak koyuyoruz.
    // Böylece hem Dashboard hem de MyConsultations aynı BLoC'u dinleyebilir.
    return BlocProvider(
      create: (context) => MyConsultationsBloc(
        apiService: context.read<ApiService>(),
      )..add(FetchMyConsultations()), // Hub açılır açılmaz konsültasyonları çek
      child: Scaffold(
        body: Center(
          child: _widgetOptions.elementAt(_selectedIndex),
        ),
        bottomNavigationBar: BottomNavigationBar(
          items: <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: const Icon(Icons.home_outlined),
              activeIcon: const Icon(Icons.home),
              label: l10n.navbarHome,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.folder_copy_outlined),
              activeIcon: const Icon(Icons.folder_copy),
              label: l10n.navbarConsultations,

            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.chat_bubble_outline),
              activeIcon: const Icon(Icons.chat_bubble),
              label: "Chat",
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.person_outline),
              activeIcon: const Icon(Icons.person),
              label: l10n.navbarProfile,
            ),
          ],
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          // Tema'dan (app_theme.dart) renkleri al
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Theme.of(context).colorScheme.primary,
          unselectedItemColor: Colors.grey,
        ),
      ),
    );
  }
}