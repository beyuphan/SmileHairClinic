import 'package:equatable/equatable.dart';

// BLoC'tan UI'a gidecek tüm durumların temel sınıfı
abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object> get props => [];
}

// Başlangıç durumu, "ne olduğunu henüz bilmiyorum"
class AuthInitial extends AuthState {}

// API ile konuşuyoruz, "bekle" (Loading indicator göster)
class AuthLoading extends AuthState {}

// Başarıyla giriş yapıldı (HomeScreen'e yönlendir)
class AuthAuthenticated extends AuthState {}

// Giriş yapılmamış (LoginScreen'i göster)
class AuthUnauthenticated extends AuthState {}

// Bir hata oluştu (Hata mesajı göster)
class AuthFailure extends AuthState {
  final String message;

  const AuthFailure(this.message);

  @override
  List<Object> get props => [message];
}