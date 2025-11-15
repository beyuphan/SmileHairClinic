// backend/src/chat/chat.gateway.ts
import {
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  OnGatewayConnection,
  OnGatewayDisconnect,
  MessageBody,
  ConnectedSocket,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { PrismaService } from '../prisma/prisma.service';
import { AuthService } from '../auth/auth.service';
import { Logger } from '@nestjs/common';

@WebSocketGateway({
  cors: { origin: '*' }, // CORS'u şimdilik her yere açtık, rahat olsun
})
export class ChatGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer() server: Server;
  private logger = new Logger('ChatGateway');

  constructor(
    private prisma: PrismaService,
    private authService: AuthService,
  ) {}

  async handleConnection(client: Socket) {
    try {
      const user = await this.authService.verifySocketToken(client);
      // Kullanıcıyı socket objesine kaydet, ileride lazım olur
      client.data.user = user;
      this.logger.log(`Kullanıcı bağlandı: ${user.email} (${user.role})`);
      
      // EĞER NORMAL KULLANICIYSA: Otomatik olarak KENDİ odasına girsin
      if (user.role === 'patient') {
        const roomName = `room_${user.id}`;
        await client.join(roomName);
        this.logger.log(`Hasta ${user.email}, ${roomName} odasına katıldı.`);
      }
      // ADMIN ise: Manuel olarak istediği odaya girecek (joinRoom ile)

    } catch (e) {
      this.logger.error('Bağlantı reddedildi: ' + e.message);
      client.disconnect();
    }
  }

  handleDisconnect(client: Socket) {
    this.logger.log(`Bağlantı koptu: ${client.id}`);
  }

  // --- ADMIN İÇİN ODAYA GİRME ---
  @SubscribeMessage('joinRoom')
  async handleJoinRoom(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { targetUserId: string }, // Artık userId ile giriyoruz
  ) {
    // Sadece Admin başkasının odasına girebilir
    if (client.data.user.role !== 'admin') return;

    const roomName = `room_${data.targetUserId}`;
    await client.join(roomName);
    this.logger.log(`Admin, ${roomName} odasına girdi.`);
  }

  // --- MESAJ GÖNDERME (TEK KANAL) ---
  @SubscribeMessage('sendMessage')
  async handleSendMessage(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { content: string; targetUserId?: string },
  ) {
    const sender = client.data.user;
    let channelOwnerId = sender.id; // Varsayılan: Kendi kanalıma yazıyorum

    // Eğer Adminsem ve başkasına yazıyorsam:
    if (sender.role === 'admin' && data.targetUserId) {
      channelOwnerId = data.targetUserId;
    }

    // 1. Mesajı DB'ye kaydet
    const newMessage = await this.prisma.chatMessage.create({
      data: {
        channelOwnerId: channelOwnerId, // Kanal Sahibi
        senderId: sender.id,            // Yazan Kişi
        messageContent: data.content,
      },
    });

    // 2. Odaya yayınla
    const roomName = `room_${channelOwnerId}`;
    this.server.to(roomName).emit('newMessage', newMessage);
  }

  // --- GEÇMİŞİ GETİR (User ID'ye göre) ---
  // Bunu Controller'dan çağırmak daha mantıklı ama şimdilik burada dursun
  // (Controller güncellemesi aşağıda)
}