import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '/auth/bloc/auth_bloc.dart';
import '/auth/bloc/auth_event.dart';
import '/auth/bloc/auth_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Form alanlarını okumak için controller'lar
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submitLogin() {
    // Butona basıldığında BLoC'a event gönder
    context.read<AuthBloc>().add(
          AuthLoginRequested(
            email: _emailController.text,
            password: _passwordController.text,
          ),
        );
  }
@override
  Widget build(BuildContext context) {
    // Scaffold'ı en dışarı alıyoruz.
    return Scaffold(
      // ESKİ BlocListener BURADAYDI -> SİLDİK.
      // Artık 'main.dart' dinliyor.
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ... (TextFields ve diğer her şey AYNI KALIYOR) ...
              const Text('Giriş Yap', style: TextStyle(fontSize: 24)),
              const SizedBox(height: 20),
              TextField(
                controller: _emailController,
                // ...
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _passwordController,
                // ...
              ),
              const SizedBox(height: 30),

              // Yüklenme durumunu dinle (Bu BlocBuilder DOĞRU, kalıyor)
              BlocBuilder<AuthBloc, AuthState>(
                builder: (context, state) {
                  if (state is AuthLoading) {
                    return const CircularProgressIndicator();
                  }
                  return ElevatedButton(
                    onPressed: _submitLogin,
                    child: const Text('Giriş Yap'),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}