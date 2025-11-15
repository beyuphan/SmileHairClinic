import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '/services/api_service.dart';
import '/services/storage_service.dart';
import '/chat/bloc/chat_bloc.dart';
import '/chat/bloc/chat_event.dart';
import '/chat/bloc/chat_state.dart';

// ARTIK PARAMETRE ALMIYOR
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ChatBloc(
        apiService: context.read<ApiService>(),
        storageService: context.read<SecureStorageService>(),
        // consultationId ARTIK YOK
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
  final _scrollController = ScrollController(); 

  void _sendMessage() {
    if (_textController.text.trim().isEmpty) return;
    context.read<ChatBloc>().add(ChatMessageSent(_textController.text));
    _textController.clear();
    // Socket'ten cevap gelince listener kaydıracak
  }

  // Yeni mesaj gelince en alta kaydır
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("Destek Hattı"), // Artık genel bir başlık
      ),
      body: Column(
        children: [
          // 1. Sohbet Balonları
          Expanded(
            child: BlocConsumer<ChatBloc, ChatState>(
              listener: (context, state) {
                // Her 'ChatLoaded' durumunda (hem geçmiş hem yeni mesaj)
                if (state is ChatLoaded) {
                  _scrollToBottom();
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
                  final String currentUserId = state.currentUserId; 
                  
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8.0),
                    itemCount: state.messages.length,
                    itemBuilder: (context, index) {
                      final message = state.messages[index];
                      // Backend'den 'senderId' geliyor
                      final bool isMe = message['senderId'] == currentUserId; 
                      
                      return _buildMessageBubble(
                        message: message['messageContent'],
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