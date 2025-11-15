// client/app/lib/chat/bloc/chat_bloc.dart
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
  
  IO.Socket? _socket;
  String? _currentUserId; // "Benim" ID'm

  ChatBloc({
    required ApiService apiService,
    required SecureStorageService storageService,
    // 'consultationId' ARTIK YOK!
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
    print("--- BLoC: TEK KANAL CHAT BAŞLATILDI ---");
    emit(ChatHistoryLoading());
    
    try {
      // 1. ADIM: Token'dan "BENİM ID'Mİ" al
      final token = await _storageService.getToken();
      if (token == null) {
        throw Exception('Giriş yapılmamış, token bulunamadı.');
      }
      Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
      _currentUserId = decodedToken['sub'] ?? decodedToken['id']; // 'sub' veya 'id'
      
      if (_currentUserId == null) {
        throw Exception('Token\'dan User ID alınamadı.');
      }
      print("Token'dan çözülen Kullanıcı ID: $_currentUserId");

      // 2. ADIM: Eski mesajları çek (Artık parametresiz)
      final history = await _apiService.getChatHistory();

      // 3. ADIM: WebSocket'e Bağlan
      // DİKKAT: IP ADRESİNİ KONTROL ET
      const socketUrl = 'http://192.168.1.21:3000'; // <-- KENDİ IP'N

      _socket = IO.io(socketUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': true,
        'extraHeaders': {
          'Authorization': 'Bearer $token', // Flutter gibi
        }
      });
      
      _socket!.connect();

      // Backend (ChatGateway) 'patient' rolünü görünce
      // otomatik olarak 'room_{userId}' odasına sokacak.
      // 'joinRoom' emit etmemize gerek yok.
      
      _socket!.on('connect', (_) => print('Socket.IO: Bağlantı kuruldu.'));

      _socket!.on('newMessage', (data) {
        add(ChatMessageReceived(data as Map<String, dynamic>));
      });
      
      _socket!.onConnectError((data) {
        print('Socket.IO Bağlantı Hatası: $data');
      });

      // 4. ADIM: Başarılı
      // (Backend zaten 'asc' [user's previous turn] sıralı yolluyor, '.reversed' yok)
      emit(ChatLoaded(history, _currentUserId!)); 

    } catch (e) {
      print("ChatBloc Hatası: $e");
      emit(ChatFailure(e.toString()));
    }
  }

  void _onMessageSent(
    ChatMessageSent event,
    Emitter<ChatState> emit,
  ) {
    if (_socket == null || !_socket!.connected) return;

    // Backend 'sendMessage' artık 'content' bekliyor.
    // 'targetUserId' yollamıyoruz, çünkü biz hastayız.
    _socket!.emit('sendMessage', {
      'content': event.message,
    });
  }

  void _onMessageReceived(
    ChatMessageReceived event,
    Emitter<ChatState> emit,
  ) {
    final currentState = state;
    if (currentState is ChatLoaded) {
      final updatedMessages = List<dynamic>.from(currentState.messages);
      updatedMessages.add(event.message);
      emit(ChatLoaded(updatedMessages, currentState.currentUserId));
    }
  }

  @override
  Future<void> close() {
    print("Socket.IO: Kapatılıyor.");
    _socket?.off('newMessage');
    _socket?.disconnect();
    return super.close();
  }
}