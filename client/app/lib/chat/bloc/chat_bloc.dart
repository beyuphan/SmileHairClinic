import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '/services/api_service.dart';
import '/services/storage_service.dart';
import '/chat/bloc/chat_event.dart';
import '/chat/bloc/chat_state.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ApiService _apiService;
  final SecureStorageService _storageService;
  final String consultationId;
  
  IO.Socket? _socket;
  StreamSubscription? _socketSubscription;

  ChatBloc({
    required ApiService apiService,
    required SecureStorageService storageService,
    required this.consultationId,
  }) : _apiService = apiService,
       _storageService = storageService, 
       super(ChatInitial()) {
    
    on<ChatStarted>(_onChatStarted);
    on<ChatMessageSent>(_onMessageSent);
    on<ChatMessageReceived>(_onMessageReceived);
  }

  Future<void> _onChatStarted(
    ChatStarted event,
    Emitter<ChatState> emit,
  ) async {
    print("--- BLoC: CHAT BAŞLATILDI ---");
    emit(ChatHistoryLoading());
    
    try {
      // 1. ADIM: Token işlemleri (Temizlendi)
      final token = await _storageService.getToken();
      if (token == null) {
        throw Exception('Giriş yapılmamış, token bulunamadı.');
      }

      // Token'dan ID'yi güvenli bir şekilde al
      Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
      // Backend 'sub' veya 'id' olarak yolluyor olabilir, garantiye alalım:
      final String currentUserId = decodedToken['sub'] ?? decodedToken['id'];
      
      print("Token'dan çözülen Kullanıcı ID: $currentUserId");

      // 2. ADIM: Eski mesajları çek
      // Backend artık 'orderBy: asc' ile gönderiyor (Eskiden -> Yeniye)
      final history = await _apiService.getChatHistory(consultationId);

      // 3. ADIM: WebSocket'e Bağlan
      
      // DİKKAT: Buradaki IP adresinin 'ApiService'teki ile AYNI olduğundan emin ol!
      // Eğer emülatörse 10.0.2.2, gerçek cihazsa 192.168.1.XX
      const socketUrl = 'http://192.168.1.25:3000'; // <-- GÜNCEL IP'Nİ YAZ

      print("--- SOCKET BAĞLANIYOR ---");
      print("URL: $socketUrl");

      _socket = IO.io(socketUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': true,
        'extraHeaders': {
          'Authorization': 'Bearer $token', // Token'ı header'da yolla
        }
      });
      
      _socket!.connect();

      _socket!.on('newMessage', (data) {
        add(ChatMessageReceived(data as Map<String, dynamic>));
      });
      
      _socket!.onConnect((_) {
        print('Socket.IO: Bağlantı kuruldu.');
        _socket!.emit('joinRoom', {'consultationId': consultationId});
      });
      
      _socket!.onConnectError((data) {
        print('Socket.IO Bağlantı Hatası: $data');
        // Bağlantı hatası olsa bile geçmiş mesajları gösterelim, hata fırlatmayalım
      });

      // 4. ADIM: Başarılı
      // DÜZELTME: .reversed kaldırıldı! Liste zaten kronolojik geliyor.
      emit(ChatLoaded(history, currentUserId)); 

    } catch (e) {
      print("ChatBloc Hatası: $e");
      emit(ChatFailure(e.toString()));
    }
  }

  void _onMessageSent(
    ChatMessageSent event,
    Emitter<ChatState> emit,
  ) {
    if (_socket == null || !_socket!.connected) {
      print("Socket bağlı değil, mesaj gönderilemedi.");
      return; 
    }

    _socket!.emit('sendMessage', {
      'consultationId': consultationId,
      'messageContent': event.message,
    });
  }

  void _onMessageReceived(
    ChatMessageReceived event,
    Emitter<ChatState> emit,
  ) {
    final currentState = state;
    if (currentState is ChatLoaded) {
      // Mevcut listeyi kopyala
      final updatedMessages = List<dynamic>.from(currentState.messages);
      // Yeni mesajı SONA ekle (Kronolojik sıra bozulmaz)
      updatedMessages.add(event.message);
      
      emit(ChatLoaded(updatedMessages, currentState.currentUserId));
    }
  }

  @override
  Future<void> close() {
    print("Socket.IO: Kapatılıyor.");
    _socket?.off('newMessage');
    _socket?.disconnect();
    _socketSubscription?.cancel();
    return super.close();
  }
}