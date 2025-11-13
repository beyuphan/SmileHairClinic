import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // Dili ekle
import '/l10n/app_localizations.dart'; // Dili ekle
import '/core/theme/app_theme.dart'; // Temayı ekle

// Servisleri/Depoları ekle
import '/services/api_service.dart';
import '/services/storage_service.dart';

// BLoC ve Ekranları ekle
import '/auth/bloc/auth_bloc.dart';
import '/auth/bloc/auth_event.dart';
import '/auth/bloc/auth_state.dart';
import '/auth/view/login_screen.dart';

// TODO: HomeScreen'i silip yerine MainHubScreen'i koyacağız
import '/main_hub/view/main_hub_screen.dart'; 
import '/splash/view/splash_screen.dart';

void main() {


  runApp(
    // Servisleri BLoC'lara tanıt
    MultiRepositoryProvider(
      providers: [
        // 1. StorageService'i yarat
        RepositoryProvider(
          create: (context) => SecureStorageService(),
        ),
        // 2. ApiService'i yarat ve az önce yarattığın storage'ı ona yolla
        RepositoryProvider(
          create: (context) => ApiService(
            storageService: context.read<SecureStorageService>(),
          ),
        ),
      ],
      // AuthBloc'u uygulamanın en üstüne yerleştir
      child: BlocProvider(
        create: (context) => AuthBloc(
          apiService: context.read<ApiService>(),
          storageService: context.read<SecureStorageService>(),
        )..add(AuthCheckStatusRequested()),
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smile Hair Clinic',
      debugShowCheckedModeBanner: false, // O sağ üstteki 'DEBUG' yazısını kaldırır

      // --- YENİ TEMA AYARLARI ---
      theme: AppThemes.lightTheme, // Açık Tema
      darkTheme: AppThemes.darkTheme, // Koyu Tema
      themeMode: ThemeMode.system, // Telefonun ayarına uysun

      // --- YENİ DİL AYARLARI ---
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''), // İngilizce
        Locale('tr', ''), // Türkçe
      ],
      // --- BİTTİ ---

      home: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthFailure) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                // DİL DESTEĞİ: Hata mesajını BLoC'tan değil, dil dosyasından al
                content: Text(_handleAuthError(context, state)),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            if (state is AuthAuthenticated) {
              return const MainHubScreen(); // TODO: Faz 7'de burası MainHubScreen olacak
            }
            if (state is AuthUnauthenticated || state is AuthFailure) {
              return const LoginScreen();
            }
            return const SplashScreen();
          },
        ),
      ),
    );
  }

  // Hata mesajlarını 'dil'e göre "tercüme" eden yardımcı fonksiyon
  String _handleAuthError(BuildContext context, AuthFailure state) {
    // AppLocalizations'ı al
    final loc = AppLocalizations.of(context)!;

    // BLoC'tan gelen "insanlaşmış" mesajı kontrol et
    if (state.message == "Email veya şifre hatalı.") {
      return loc.errorLoginFailed;
    }
    if (state.message == "Geçersiz email formatı girdiniz.") {
      return loc.errorEmailFormat;
    }
    // Diğerlerini de buraya ekleyebiliriz...

    // Eğer tanıyamazsak, BLoC'un mesajını göster
    return state.message;
  }
}