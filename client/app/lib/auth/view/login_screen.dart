import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '/auth/bloc/auth_bloc.dart';
import '/auth/bloc/auth_event.dart';
import '/auth/bloc/auth_state.dart';
import '/l10n/app_localizations.dart'; // <-- Dil desteğini import et

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Form alanlarını okumak için controller'lar
  // Hızlı test için dolduralım (prod'da boş olmalı)
  final _emailController = TextEditingController(text: "test@kullanici.com");
  final _passwordController = TextEditingController(text: "sifre123");
  final _formKey = GlobalKey<FormState>(); // Form doğrulama için

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submitLogin() {
    // Önce formun geçerli olup olmadığını kontrol et
    if (_formKey.currentState?.validate() ?? false) {
      // Butona basıldığında BLoC'a event gönder
      context.read<AuthBloc>().add(
            AuthLoginRequested(
              email: _emailController.text,
              password: _passwordController.text,
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Dil dosyasını (l10n) çağır
    final loc = AppLocalizations.of(context)!;
    // Tema renklerini çağır
    final theme = Theme.of(context);

    return Scaffold(
      // Arkaplan rengini Temadan al (Açıkta Kırık Beyaz, Koyuda Siyah)
      backgroundColor: theme.colorScheme.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // TODO: Buraya "Tutkulu" bir logo veya ikon (örn: 'assets/logo.png') ekleyebiliriz
                Icon(
                  Icons.health_and_safety_outlined, // Geçici ikon
                  size: 80,
                  color: theme.colorScheme.primary, // Temanın Ana Rengi (Teal)
                ),
                const SizedBox(height: 16),

                // Başlık (Dil dosyasından ve Temanın yazı tipinden)
                Text(
                  loc.loginScreenTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 40),

                // Email Alanı
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: loc.emailLabel,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: Icon(Icons.email_outlined, color: theme.colorScheme.primary),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Lütfen bir e-posta girin';
                    if (!value.contains('@')) return 'Geçersiz format'; // Basit kontrol
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Şifre Alanı
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: loc.passwordLabel,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: Icon(Icons.lock_outline, color: theme.colorScheme.primary),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Lütfen bir şifre girin';
                    return null;
                  },
                ),
                const SizedBox(height: 40),

                // Yüklenme durumunu dinle
                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    if (state is AuthLoading) {
                      // Yükleniyorsa -> Dönen çark (Temanın "Tutku" renginde)
                      return Center(
                        child: CircularProgressIndicator(
                          color: theme.colorScheme.secondary, // Koral (Accent) rengi
                        ),
                      );
                    }

                    // Yüklenmiyorsa -> Buton
                    // Bu buton, app_theme.dart'ta tanımladığımız
                    // "Tutkulu" (Koral) stili otomatik olarak alacak.
                    return ElevatedButton(
                      onPressed: _submitLogin,
                      child: Text(loc.loginButton),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}