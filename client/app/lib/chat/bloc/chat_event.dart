import 'package:equatable/equatable.dart';

abstract class ChatEvent extends Equatable {
  const ChatEvent();
  @override
  List<Object> get props => [];
}

// Ekran açıldığında hem geçmişi çekecek hem de socket'e bağlanacak
class ChatStarted extends ChatEvent {}

// Kullanıcı "Gönder" butonuna bastığında
class ChatMessageSent extends ChatEvent {
  final String message;
  const ChatMessageSent(this.message);
  @override
  List<Object> get props => [message];
}

// (Dahili Event) Socket'ten yeni mesaj geldiğinde
class ChatMessageReceived extends ChatEvent {
  final Map<String, dynamic> message; // NestJS'ten gelen ham JSON
  const ChatMessageReceived(this.message);
  @override
  List<Object> get props => [message];
}