import {
  WebSocketGateway,
  SubscribeMessage,
  WebSocketServer,
  OnGatewayConnection,
  OnGatewayDisconnect,
  MessageBody,
  ConnectedSocket,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { JwtService } from '@nestjs/jwt'; // Token'ı doğrulamak için
import { PrismaService } from '../prisma/prisma.service'; // Veritabanına yazmak için
import { Logger } from '@nestjs/common';

// DTO: Flutter'dan 'joinRoom' event'i ile gelecek veri
interface JoinRoomPayload {
  consultationId: string;
}

// DTO: Flutter'dan 'sendMessage' event'i ile gelecek veri
interface ChatMessagePayload {
  consultationId: string;
  messageContent: string;
}

// Gateway'i 80 portunda değil (HTTP ile çakışır), 
// 3001 portunda (veya farklı bir portta) başlatalım
// CORS ayarı: Herhangi bir (örn: Flutter Web) istemcinin bağlanmasına izin ver
@WebSocketGateway({ cors: { origin: '*' } })
export class ChatGateway implements OnGatewayConnection, OnGatewayDisconnect {
  // 'Server', tüm bağlı istemcileri yöneten ana sunucudur
  @WebSocketServer()
  server: Server;

  private readonly logger = new Logger(ChatGateway.name);

  // Gerekli servisleri (Depoları) enjekte et
  constructor(
    private readonly jwtService: JwtService,
    private readonly prisma: PrismaService,
  ) {}

  // --- 1. KRİTİK ADIM: GÜVENLİ BAĞLANTI ---
  // Bir kullanıcı (Flutter) bağlanmaya çalıştığında bu fonksiyon çalışır
  async handleConnection(socket: Socket) {
    try {
      // 1. Kullanıcının token'ını (anahtarını) al
      // Flutter, bağlantı yaparken 'extraHeaders' ile 'Authorization' başlığı göndermeli
      const token = socket.handshake.headers.authorization?.split(' ')[1];
      
      if (!token) {
        throw new Error('Token bulunamadı.');
      }

      // 2. Token'ı doğrula
      const payload = this.jwtService.verify(token);
      const userId = payload.sub;

      // 3. (En Önemlisi) Socket'i (istemciyi) kimliğiyle etiketle
      // Artık bu 'socket'in 'userId'sinin kim olduğunu biliyoruz
      socket.data.userId = userId;
      
      this.logger.log(`İstemci bağlandı: ${socket.id}, Kullanıcı ID: ${userId}`);
      
    } catch (e) {
      // Eğer token geçersizse veya yoksa, bağlantıyı REDDET
      this.logger.error(`Geçersiz token. Bağlantı reddedildi: ${socket.id} - Hata: ${e.message}`);
      socket.disconnect();
    }
  }

  // Kullanıcı bağlantıyı kestiğinde
  handleDisconnect(socket: Socket) {
    this.logger.log(`İstemci ayrıldı: ${socket.id}`);
  }

  // --- 2. KRİTİK ADIM: ODAYA ALMA ---
  // Flutter, bağlandıktan *hemen sonra* bu event'i göndermeli
  @SubscribeMessage('joinRoom')
  async handleJoinRoom(
    @MessageBody() payload: JoinRoomPayload,
    @ConnectedSocket() socket: Socket,
  ) {
    const userId = socket.data.userId;
    const { consultationId } = payload;
    
    // TODO: Bu kullanıcının (userId) bu odaya (consultationId)
    // girme yetkisi var mı diye veritabanından kontrol et (verifyConsultationOwner gibi)

    // Kullanıcıyı odaya al
    socket.join(consultationId);
    this.logger.log(`Kullanıcı ${userId} odaya katıldı: ${consultationId}`);
  }

  // --- 3. KRİTİK ADIM: MESAJLAŞMA ---
  // Flutter'dan "yeni mesaj" geldiğinde bu fonksiyon çalışır
  @SubscribeMessage('sendMessage')
  async handleMessage(
    @MessageBody() payload: ChatMessagePayload, // Gelen mesaj DTO'su
    @ConnectedSocket() socket: Socket, // Gönderen istemci
  ) {
    const userId = socket.data.userId;
    const { consultationId, messageContent } = payload;

    this.logger.log(`Yeni mesaj (Oda: ${consultationId}): ${messageContent}`);

    try {
      // 1. Yeni mesajı veritabanına (chat_messages) kaydet
      const newMessage = await this.prisma.chatMessage.create({
        data: {
          consultationId: consultationId,
          senderId: userId,
          messageContent: messageContent,
        },
        // Gönderen kullanıcının 'email' gibi bilgilerini de al
        include: {
          sender: {
            select: { email: true, role: true },
          },
        },
      });

      // 2. Mesajı, *sadece o odadaki* (hasta ve doktor)
      // *diğer* istemcilere gönder
      // socket.to(consultationId).emit('newMessage', newMessage);
      
      // VEYA (Daha iyisi): Mesajı gönderen dahil HERKESE (o odadaki) gönder
      // Bu, gönderenin de "mesajım ulaştı" teyidini almasını sağlar
      this.server.to(consultationId).emit('newMessage', newMessage);
      
    } catch (e) {
      this.logger.error(`Mesaj kaydedilemedi: ${e.message}`);
      // TODO: Gönderene "Hata" mesajı gönder
      socket.emit('messageError', { error: 'Mesaj gönderilemedi.' });
    }
  }
}