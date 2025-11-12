import { Controller, Get, Param, UseGuards, Request as NestRequest } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { PrismaService } from '../prisma/prisma.service';
// TODO: verifyConsultationOwner'ı ConsultationService'ten almamız lazım
// Şimdilik Prisma'yı direkt kullanıyoruz.

@UseGuards(JwtAuthGuard)
@Controller('chat')
export class ChatController {
  constructor(private readonly prisma: PrismaService) {}

  // YENİ ENDPOINT: Sohbet Geçmişini Getir
  // 'GET /chat/history/abc-123-xyz' (consultationId)
  @Get('history/:consultationId')
  async getChatHistory(
    @Param('consultationId') consultationId: string,
    @NestRequest() req,
  ) {
    const userId = req.user.userId;

    // TODO: Güvenlik - Bu kullanıcının bu sohbete erişimi var mı?
    // (verifyConsultationOwner... gibi)

    // O konsültasyona ait tüm mesajları, en yeniden eskiye doğru çek
    return this.prisma.chatMessage.findMany({
      where: {
        consultationId: consultationId,
      },
      orderBy: {
        timestamp: 'desc', // En yeni mesaj en üstte
      },
      include: {
        sender: { // Gönderen bilgisini de al
          select: { id: true, email: true, role: true },
        },
      },
    });
  }
}