import 'package:equatable/equatable.dart';

abstract class ChatState extends Equatable {
  const ChatState();
  @override
  List<Object> get props => [];
}

// Ekran ilk açıldığında
class ChatInitial extends ChatState {}

// Eski mesajlar yükleniyor
class ChatHistoryLoading extends ChatState {}

// Hata oluştu (geçmiş yüklenemedi VEYA socket bağlanamadı)
class ChatFailure extends ChatState {
  final String error;
  const ChatFailure(this.error);
  @override
  List<Object> get props => [error];
}

// Başarılı: Eski mesajlar yüklendi VE socket bağlantısı kuruldu
class ChatLoaded extends ChatState {
  // Veritabanından gelen eski mesajlar + Socket'ten gelen yeni mesajlar
  final List<dynamic> messages; 
  const ChatLoaded(this.messages);
  @override
  List<Object> get props => [messages];
}