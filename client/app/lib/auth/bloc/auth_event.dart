import 'package:equatable/equatable.dart';

// BLoC'a göndereceğimiz tüm olayların temel sınıfı
abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object> get props => [];
}

// Uygulama ilk açıldığında "Token var mı?" diye kontrol et
class AuthCheckStatusRequested extends AuthEvent {}

// "Giriş Yap" butonuna basıldığında
class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;

  const AuthLoginRequested({required this.email, required this.password});

  @override
  List<Object> get props => [email, password];
}

// "Çıkış Yap" butonuna basıldığında
class AuthLogoutRequested extends AuthEvent {}

// TODO: Register event'i de buraya eklenebilir