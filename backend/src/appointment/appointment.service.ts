// backend/src/appointment/appointment.service.ts
import { Injectable, UnauthorizedException, NotFoundException, ConflictException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateSlotDto } from './dto/create-slot.dto';
import { BookSlotDto } from './dto/book-slot.dto';
import { User } from '@prisma/client'; // schema.prisma'dan

@Injectable()
export class AppointmentService {
  constructor(private prisma: PrismaService) {}

  // --- Admin ---
  async createSlot(dto: CreateSlotDto) {
    return this.prisma.appointmentSlot.create({
      data: {
        dateTime: dto.dateTime,
      },
    });
  }

  // --- Kullanıcı ---
  async getAvailableSlots() {
    // Sadece 'rezerve edilmemiş' VE 'tarihi geçmemiş' slotları getir
    return this.prisma.appointmentSlot.findMany({
      where: {
        isBooked: false,
        dateTime: {
          gte: new Date(), // 'greater than or equal' - bugünden büyük/eşit
        },
      },
      orderBy: {
        dateTime: 'asc', // Yakın tarihten uzağa sırala
      },
    });
  }

  // --- Kullanıcı ---
  async bookSlot(user: User, dto: BookSlotDto) {
    // 1. Bu danışmanlık bu kullanıcıya mı ait? Güvenlik kontrolü
    const consultation = await this.prisma.consultation.findUnique({
      where: { id: dto.consultationId },
    });

    if (!consultation) {
      throw new NotFoundException('Danışmanlık bulunamadı');
    }
    if (consultation.patientId !== user.id) {
      throw new UnauthorizedException('Bu danışmanlık size ait değil');
    }

    // 2. İşlemi 'Transaction' içinde yap
    // (Biri slotu kaparsa, diğeri hata alsın)
    try {
      return await this.prisma.$transaction(async (tx) => {
        // A. Slotu bul ve 'isBooked: false' olduğundan emin ol
        const slot = await tx.appointmentSlot.findFirst({
          where: {
            id: dto.slotId,
            isBooked: false,
          },
        });

        if (!slot) {
          throw new ConflictException('Bu slot dolu veya mevcut değil');
        }

        // B. Slotu 'dolu' olarak güncelle ve danışmanlığa bağla
        const updatedSlot = await tx.appointmentSlot.update({
          where: { id: dto.slotId },
          data: {
            isBooked: true,
            consultationId: dto.consultationId,
          },
        });

        // C. Danışmanlığın (Consultation) durumunu 'ONAY BEKLİYOR' yap
        await tx.consultation.update({
          where: { id: dto.consultationId },
          data: {
            // Not: schema.prisma'daki enum adın PENDING_APPROVAL olmalı
            status: 'PENDING_APPROVAL', 
          },
        });

        return updatedSlot;
      });
    } catch (e) {
      if (e instanceof ConflictException) {
        throw e;
      }
      throw new ConflictException('Randevu alınırken bir hata oluştu. Slot kapılmış olabilir.');
    }
  }

  async deleteSlot(user: User, slotId: string) {
    // Admin değilse veya rolü yoksa engelle
    if (user.role !== 'admin') {
      throw new UnauthorizedException('Bu işlemi yapmaya yetkiniz yok');
    }

    const slot = await this.prisma.appointmentSlot.findUnique({
      where: { id: slotId },
    });

    if (!slot) {
      throw new NotFoundException('Slot bulunamadı');
    }

    // ÖNEMLİ KONTROL: Eğer slot bir hasta tarafından 'rezerve edilmişse'
    // (yani 'isBooked' true ise) silinmemeli.
    if (slot.isBooked) {
      throw new ConflictException('Bu slot bir hastaya rezerve edilmiş, silinemez.');
    }

    // Slot boşsa, sil
    await this.prisma.appointmentSlot.delete({
      where: { id: slotId },
    });

    return { message: 'Slot başarıyla silindi' };
  }

}