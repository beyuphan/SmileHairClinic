// backend/src/chat/chat.controller.ts
import { Controller, Get, Param, UseGuards, Req } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../auth/roles.decorator'; // Roles (varsa)
import { Role } from '@prisma/client'; // Prisma'dan Role enum'unu al

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

  @Get('patient-list') // /chat/patient-list
  @UseGuards(JwtAuthGuard)
  // @Roles(Role.admin) // Sadece adminlerin erişmesi için (RolesGuard'ın varsa)
  async getPatientList(@Req() req) {
    // Admin değilse hata fırlat (veya guard ile yap)
    if (req.user.role !== 'admin') {
      throw new Error('Yetkisiz erişim');
    }

    // Bize tüm hastalar lazım
    const patients = await this.prisma.user.findMany({
      where: {
        role: 'patient', // Sadece 'patient' rolündekiler
      },
      include: {
        profile: true, // Ad/Soyad için
        consultations: {
          // Son durumunu görebilmek için SADECE EN YENİ başvuruyu çek
          orderBy: { createdAt: 'desc' },
          take: 1,
        },
      },
      orderBy: {
        createdAt: 'desc', // En yeni kayıt olan hasta en üstte
      },
    });

    return patients;
  }
}