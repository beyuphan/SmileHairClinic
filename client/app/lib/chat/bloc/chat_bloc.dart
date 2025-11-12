import 'dart:async'; // StreamSubscription için
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO; // Socket.IO paketi
import '/services/api_service.dart';
import '/services/storage_service.dart';
import '/chat/bloc/chat_event.dart';
import '/chat/bloc/chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ApiService _apiService;
  final SecureStorageService _storageService;
  final String consultationId;
  
  IO.Socket? _socket; // Socket.IO bağlantımız
  StreamSubscription? _socketSubscription; // Socket'i dinleyen abonelik

  ChatBloc({
    required ApiService apiService,
    required SecureStorageService storageService,
    required this.consultationId,
  }) : _apiService = apiService, // Gelen 'apiService'i '_apiService'e ata
       _storageService = storageService, 
       super(ChatInitial()) {
    
    // Hangi event gelince hangi fonksiyon çalışsın?
    on<ChatStarted>(_onChatStarted);
    on<ChatMessageSent>(_onMessageSent);
    on<ChatMessageReceived>(_onMessageReceived);
  }

  Future<void> _onChatStarted(
    ChatStarted event,
    Emitter<ChatState> emit,
  ) async {
    print("--- BLoC: CHAT BAŞLATILDI ---"); // BLoC başladı logu
    emit(ChatHistoryLoading()); // "Eski mesajlar yükleniyor..."
    
    try {
      // 1. ADIM: Eski mesajları REST API'den çek
      final history = await _apiService.getChatHistory(consultationId);
      
      // 2. ADIM: WebSocket'e (Socket.IO) Bağlan
      
      // Önce token'ı al (Güvenlik için)
      final token = await _storageService.getToken();
      if (token == null) {
        throw Exception('Giriş yapılmamış, token bulunamadı.');
      }

      // Backend'deki Gateway portu (3001)
      const socketUrl = 'http://192.168.1.25:3000';// <-- IP ADRESİNİ KONTROL ET!

// YENİ AYAR LOGLARI
    print("--- SOCKET AYARLARI ---");
    print("URL: $socketUrl");
    print("TOKEN ALINDI MI?: ${token.isNotEmpty}");
    print("CONSULTATION ID: $consultationId");
    print("------------------------");
      // Socket.IO'yu kur ve token'ı 'extraHeaders' ile gönder
      _socket = IO.io(socketUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': true,
        'extraHeaders': {
          'Authorization': 'Bearer $token', // <-- GÜVENLİK BURADA
        }
      });
      
      // Socket'e bağlanmayı dene
      _socket!.connect();

      // Socket'ten gelen 'newMessage' olayını dinle
      _socket!.on('newMessage', (data) {
        // Socket'ten yeni mesaj gelince, BLoC'a DAHİLİ event yolla
        add(ChatMessageReceived(data as Map<String, dynamic>));
      });
      
      _socket!.onConnect((_) {
        print('Socket.IO: Bağlantı kuruldu.');
        // Bağlantı kurulur kurulmaz, "Odaya Katıl" emrini gönder
        _socket!.emit('joinRoom', {'consultationId': consultationId});
      });
      
      _socket!.onConnectError((data) {
        print('Socket.IO Bağlantı Hatası: $data');
        if (!emit.isDone) { // <-- KONTROLÜ EKLE
          emit(const ChatFailure('Sohbete bağlanılamadı.'));
        }
        });

      // 3. ADIM: Başarılı
      // UI'a "Eski mesajlar bunlar, socket de bağlandı" de
      emit(ChatLoaded(history.reversed.toList())); // Mesajları eskiden yeniye sırala

    } catch (e) {
      emit(ChatFailure(e.toString()));
    }
  }

  // Kullanıcı "Gönder"e bastığında
  void _onMessageSent(
    ChatMessageSent event,
    Emitter<ChatState> emit,
  ) {
    if (_socket == null || !_socket!.connected) return; // Bağlı değilsek gönderme

    // Socket'e 'sendMessage' event'i ile yeni mesajı gönder
    _socket!.emit('sendMessage', {
      'consultationId': consultationId,
      'messageContent': event.message,
    });
    // Not: Sunucu bu mesajı alıp, veritabanına kaydedip,
    // 'newMessage' olarak *geri yollayacak*. Biz mesajı DAHİLİ olarak eklemiyoruz.
  }

  // Socket'ten 'newMessage' geldiğinde
  void _onMessageReceived(
    ChatMessageReceived event,
    Emitter<ChatState> emit,
  ) {
    final currentState = state;
    if (currentState is ChatLoaded) {
      // Mevcut mesaj listesini al
      final updatedMessages = List<dynamic>.from(currentState.messages);
      // Yeni gelen mesajı (NestJS'ten dönen) listenin sonuna ekle
      updatedMessages.add(event.message);
      
      // UI'ı yeni listeyle güncelle
      emit(ChatLoaded(updatedMessages));
    }
  }

  // BLoC kapandığında (ekran kapandığında) socket'i de kapat
 @override
Future<void> close() {
  print("Socket.IO: Bağlantı kapatılıyor ve tüm listener'lar temizleniyor.");
  
  // Önce TÜM listener'ları kaldır
  _socket?.off('newMessage');
  _socket?.off('connect');
  _socket?.off('connect_error');
  _socket?.off('disconnect');
  
  // Socket bağlantısını kes
  _socket?.disconnect();
  
  _socketSubscription?.cancel(); // Bu satır durabilir
  
  return super.close();
}
}