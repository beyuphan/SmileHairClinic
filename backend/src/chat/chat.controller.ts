// backend/src/chat/chat.controller.ts
import { Controller, Get, Param, UseGuards, Req } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

@Controller('chat')
export class ChatController {
  constructor(private prisma: PrismaService) {}

  @Get('history/:userId') // URL değişti: consultationId -> userId
  @UseGuards(JwtAuthGuard)
  async getChatHistory(@Param('userId') targetUserId: string, @Req() req) {
    // Eğer hastaysam sadece kendi mesajlarımı çekebilirim
    // Eğer adminsem herkesinkini çekebilirim
    const requestingUser = req.user;
    const channelId = requestingUser.role === 'admin' ? targetUserId : requestingUser.id;

    return this.prisma.chatMessage.findMany({
      where: { channelOwnerId: channelId }, // Yeni şema
      orderBy: { timestamp: 'asc' }, // Sıralı
    });
  }
}