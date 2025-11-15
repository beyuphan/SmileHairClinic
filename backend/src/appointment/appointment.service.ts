// backend/src/appointment/appointment.service.ts
import { Injectable, NotFoundException, ConflictException, UnauthorizedException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateSlotDto } from './dto/create-slot.dto';
import { BookSlotDto } from './dto/book-slot.dto';
import { User } from '@prisma/client'; 

@Injectable()
export class AppointmentService {
  constructor(private prisma: PrismaService) {}

  // --- Admin: Slot Ekle ---
  async createSlot(dto: CreateSlotDto) {
    return this.prisma.appointmentSlot.create({
      data: { dateTime: dto.dateTime },
    });
  }

  // --- Admin: Slot Sil ---
  async deleteSlot(user: User, slotId: string) {
    if (user.role !== 'admin') {
      throw new UnauthorizedException('Yetkiniz yok');
    }
    const slot = await this.prisma.appointmentSlot.findUnique({ where: { id: slotId } });
    if (!slot) throw new NotFoundException('Slot bulunamadı');
    if (slot.isBooked) throw new ConflictException('Dolu slot silinemez.');
    
    await this.prisma.appointmentSlot.delete({ where: { id: slotId } });
    return { message: 'Slot silindi' };
  }

  // --- Herkes: Boş Slotları Gör ---
  async getAvailableSlots() {
    return this.prisma.appointmentSlot.findMany({
      where: { 
        isBooked: false, 
        dateTime: { gte: new Date() }
      },
      orderBy: { dateTime: 'asc' },
    });
  }

  // --- Kullanıcı: Randevu Al ---
  async bookSlot(user: User, dto: BookSlotDto) {
    const existingBooking = await this.prisma.appointmentSlot.findFirst({
        where: { patientId: user.id }
    });
    if (existingBooking) {
        throw new ConflictException('Zaten mevcut bir randevu rezervasyonunuz var.');
    }

    return await this.prisma.$transaction(async (tx) => {
      const slot = await tx.appointmentSlot.findFirst({
        where: { 
          id: dto.slotId, 
          isBooked: false 
        },
      });
      if (!slot) {
        throw new ConflictException('Bu slot dolu veya mevcut değil.');
      }

      const updatedSlot = await tx.appointmentSlot.update({
        where: { id: dto.slotId },
        data: {
          isBooked: true,
          patientId: user.id, // schema.prisma 'patientId' bekliyor
          isConfirmed: false, 
        },
      });
      return updatedSlot;
    });
  }

  // --- YENİ ADMİN FONKSİYONLARI (DOĞRU YERDE) ---

  // Admin: Onay bekleyen randevuları getir
  async findPendingApprovals() {
    return this.prisma.appointmentSlot.findMany({
      where: {
        isBooked: true,       // Dolu
        isConfirmed: false,   // Onaylanmamış
      },
      include: {
        patient: { include: { profile: true } }, // Hastanın kim olduğunu görmek için
      },
      orderBy: {
        dateTime: 'asc',
      },
    });
  }

  // Admin: Randevuyu onayla
  async approveAppointment(slotId: string) {
    const slot = await this.prisma.appointmentSlot.findUnique({
      where: { id: slotId },
    });

    if (!slot) {
      throw new NotFoundException('Randevu slotu bulunamadı');
    }
    if (!slot.isBooked || slot.isConfirmed) {
      throw new ConflictException('Bu slot zaten onaylanmış veya boş.');
    }

    // 2. Slotu 'Onaylandı' olarak işaretle
    return this.prisma.appointmentSlot.update({
      where: { id: slotId },
      data: {
        isConfirmed: true,
      },
    });
  }
}