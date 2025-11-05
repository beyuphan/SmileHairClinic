import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '/auth/bloc/auth_event.dart';
import '/auth/bloc/auth_state.dart';
import '/services/api_service.dart';
import '/services/storage_service.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  // Depolarımızı (servislerimizi) istiyoruz
  final ApiService _apiService;
  final SecureStorageService _storageService;

  AuthBloc({
    required ApiService apiService,
    required SecureStorageService storageService,
  })  : _apiService = apiService,
        _storageService = storageService,
        super(AuthInitial()) { // Başlangıç durumu

    // Hangi event gelince hangi fonksiyon çalışsın?
    on<AuthCheckStatusRequested>(_onCheckStatus);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
  }

  // Uygulama açıldığında çalışacak fonksiyon
  Future<void> _onCheckStatus(
    AuthCheckStatusRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    final token = await _storageService.getToken();

    if (token != null) {
      // TODO: Token'ı API'de doğrulayabiliriz (şimdilik var sayalım)
      emit(AuthAuthenticated());
    } else {
      emit(AuthUnauthenticated());
    }
  }

  // Login butonuna basıldığında çalışacak fonksiyon
  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      // 1. API'ye git, token'ı iste (Hamle 1)
      final token = await _apiService.login(event.email, event.password);

      // 2. Token'ı kasaya kaydet
      await _storageService.saveToken(token);

      // 3. UI'a "başarılı" de
      emit(AuthAuthenticated());
    } catch (e) {
        // Hatanın tipini kontrol et
        if (e is DioException) {
          // Eğer hata Dio'dan geldiyse ve kodu 401 (Yetki Yok) ise:
          if (e.response?.statusCode == 401) {
            emit(const AuthFailure("Email veya şifre hatalı."));
          }
          else if (e.response?.statusCode == 400) {
            emit(const AuthFailure("Geçersiz email formatı girdiniz."));
          }
          else {
            // Diğer API hataları için (örn: 500 - Sunucu Çöktü)
            emit(AuthFailure("Sunucuya bağlanılamadı: ${e.message}"));
          }
        } else {
          // Diğer bilinmeyen hatalar için
          emit(AuthFailure("Bilinmeyen bir hata oluştu: ${e.toString()}"));
        }
      }
  }

  // Çıkış yap butonuna basıldığında
  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    await _storageService.deleteToken();
    emit(AuthUnauthenticated());
  }
}