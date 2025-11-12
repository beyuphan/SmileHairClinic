import 'package:flutter/material.dart';
import '/l10n/app_localizations.dart'; // Dil

// O 4 adet sekme ekranını import et
import '/dashboard/view/dashboard_screen.dart';
import '/my_consultations/view/my_consultations_screen.dart';
import '/chat/view/chat_screen.dart';
import '/profile/view/profile_screen.dart';
import '/timeline/view/timeline_screen.dart'; 

class MainHubScreen extends StatefulWidget {
  const MainHubScreen({super.key});

  @override
  State<MainHubScreen> createState() => _MainHubScreenState();
}

class _MainHubScreenState extends State<MainHubScreen> {
  int _selectedIndex = 0; // Hangi sekmenin seçili olduğunu tutar

  // O 4 adet ekranı bir listeye koy
  static const List<Widget> _widgetOptions = <Widget>[
    DashboardScreen(),        // Sekme 0
    TimelineScreen(),  // Sekme 1 ("Yolculuğum")
    ProfileScreen(),          // Sekme 2
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      // Hangi ekran seçiliyse onu göster
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),

      // Alt Navigasyon Çubuğu (Premium & Tutkulu)
      bottomNavigationBar: BottomNavigationBar(
        // Tipi: 'fixed' (sabit) olsun ki 4'ü de görünsün
        type: BottomNavigationBarType.fixed, 

        // Renkler (Temadan)
        backgroundColor: theme.colorScheme.surface, // Açıkta Beyaz, Koyuda Gri
        selectedItemColor: theme.colorScheme.secondary, // Seçili olan: Koral (Tutku)
        unselectedItemColor: Colors.grey, // Seçili olmayan: Gri

        // Sekmeler
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Ana Sayfa', // TODO: Dile ekle
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.timeline_outlined),
            activeIcon: Icon(Icons.timeline),
            label: 'Yolculuğum', // TODO: Dile ekle
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil', // TODO: Dile ekle
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}