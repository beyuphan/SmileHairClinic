import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '/services/api_service.dart';
import '/services/storage_service.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '/l10n/app_localizations.dart';

import '/chat/bloc/chat_bloc.dart';
import '/chat/bloc/chat_event.dart';
import '/chat/bloc/chat_state.dart';

// 'MyConsultationsScreen'den bu ekrana ID ile geliyoruz
class ChatScreen extends StatelessWidget {
  final String consultationId;

  const ChatScreen({super.key, required this.consultationId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ChatBloc(
        apiService: context.read<ApiService>(),
        storageService: context.read<SecureStorageService>(),
        consultationId: consultationId,
      )..add(ChatStarted()), // BLoC'u başlat
      child: const _ChatView(),
    );
  }
}

class _ChatView extends StatefulWidget {
  const _ChatView();

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController(); // Listenin en altına kaymak için

  void _sendMessage() {
    if (_textController.text.isEmpty) return;
    
    // BLoC'a "Mesaj Gönder" event'i yolla
    context.read<ChatBloc>().add(ChatMessageSent(_textController.text));
    _textController.clear(); // Metin kutusunu temizle
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    // BLoC, 'dispose' olduğunda WebSocket bağlantısını otomatik kapatmalı
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("Doktor Görüşmesi"), // TODO: Dile ekle
      ),
      body: Column(
        children: [
          // 1. Sohbet Balonları
          Expanded(
            child: BlocConsumer<ChatBloc, ChatState>(
              listener: (context, state) {
                // Yeni mesaj geldiğinde veya yüklendiğinde en alta kaydır
                if (state is ChatLoaded) {
                  // Kısa bir gecikme (render bitince)
                  Future.delayed(const Duration(milliseconds: 100), () {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  });
                }
              },
              builder: (context, state) {
                if (state is ChatHistoryLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is ChatFailure) {
                  return Center(child: Text("Hata: ${state.error}"));
                }
                if (state is ChatLoaded) {
                  // TODO: 'userId'yi BLoC'tan alıp 'isMe' kontrolü yap
                  final String currentUserId = state.currentUserId;
                  
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8.0),
                    itemCount: state.messages.length,
                    itemBuilder: (context, index) {
                      final message = state.messages[index];
                      // TODO: 'sender' objesini kontrol et

                      final dynamic senderId = message['senderId'];
                      final dynamic messageContent = message['messageContent'];

                      final bool isMe = (senderId != null && senderId == currentUserId);                     
                      return _buildMessageBubble(
                        message: messageContent?.toString() ?? "[İçerik yok]", // null ise fallback                        isMe: isMe,
                        isMe: isMe,
                        theme: theme,
                      );
                    },
                  );
                }
                return const Center(child: Text("Sohbet yükleniyor..."));
              },
            ),
          ),
          
          // 2. Metin Yazma Alanı
          _buildTextInput(theme),
        ],
      ),
    );
  }

  // Sohbet balonu çizen yardımcı Widget
  Widget _buildMessageBubble({required String message, required bool isMe, required ThemeData theme}) {
    return Row(
      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
          decoration: BoxDecoration(
            color: isMe ? theme.colorScheme.secondary : theme.colorScheme.surface, // Ben: Koral, Diğeri: Yüzey
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            message,
            style: TextStyle(
              color: isMe ? Colors.white : theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  // Metin yazma çubuğunu çizen yardımcı Widget
  Widget _buildTextInput(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 5,
          )
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: const InputDecoration(
                hintText: "Mesajınızı yazın...",
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          IconButton(
            icon: Icon(Icons.send, color: theme.colorScheme.secondary), // Koral (Tutku) rengi
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}