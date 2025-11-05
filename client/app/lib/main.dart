import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'auth/bloc/auth_bloc.dart';
import '/auth/bloc/auth_event.dart';
import '/auth/bloc/auth_state.dart';
import '/services/api_service.dart';
import '/services/storage_service.dart';

// Bu ekranları birazdan oluşturacağız
import '/auth/view/login_screen.dart'; 
import '/home/view/home_screen.dart'; 
import '/splash/view/splash_screen.dart';

void main() {
  // 1. Adım: Servislerimizi (Depoları) oluştur (Bu zaten tamamdı)
  final ApiService apiService = ApiService();
  final SecureStorageService storageService = SecureStorageService();

  runApp(
    // 2. Adım: Servisleri tüm alt widget'lara (ve BLoC'lara) tanıt
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: apiService),
        RepositoryProvider.value(value: storageService),
      ],
      // 3. Adım: AuthBloc'u uygulamanın en üstüne yerleştir
      child: BlocProvider(
        create: (context) => AuthBloc(
          // Servisleri RepositoryProvider'dan alıp BLoC'a pasla
          apiService: context.read<ApiService>(),
          storageService: context.read<SecureStorageService>(),
        )..add(AuthCheckStatusRequested()), // <-- UYGULAMA BAŞLARKEN İLK EVENT'İ GÖNDER
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
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      // home: BlocBuilder<... (ESKİ YER)
      home: BlocListener<AuthBloc, AuthState>(
        // KULAK (LISTENER): Bu, ekran değişse bile hep dinler.
        listener: (context, state) {
          // Eğer "Hata" durumu gelirse, hangi ekranda olursak olalım
          // SnackBar'ı GÖSTER.
          if (state is AuthFailure) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message), // BLoC'tan gelen "insanlaşmış" mesaj
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        // GÖZ (BUILDER): Bu, sadece ekranı değiştirir.
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            // 1. Durum: Giriş başarılıysa
            if (state is AuthAuthenticated) {
              return const HomeScreen();
            }
            // 2. Durum: Giriş yapılmamışsa VEYA Hata alındıysa
            if (state is AuthUnauthenticated || state is AuthFailure) {
              return const LoginScreen();
            }
            // Diğer tüm durumlar (AuthInitial, AuthLoading)
            return const SplashScreen();
          },
        ),
      ),
    );
  }
}