// backend/src/consultation/consultation.service.ts
import { Injectable, Logger, NotFoundException, UnauthorizedException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { S3Service } from '../s3/s3.service';
import { CreateConsultationDto } from './dto/create-consultation.dto';
import { RequestUploadUrlsDto } from './dto/request-upload.dto';
import { v4 as uuidv4 } from 'uuid';
import { ConfirmUploadDto } from './dto/confirm-upload.dto';
import { URL } from 'node:url';

@Injectable()
export class ConsultationService {
  private readonly logger = new Logger(ConsultationService.name);

  constructor(
    private prisma: PrismaService,
    private s3: S3Service,
  ) {}

  // Akış 1: Konsültasyon (Dosya Paketi) oluştur
  async createConsultation(
    dto: CreateConsultationDto,
    patientId: string,
  ) {
    this.logger.log(`Creating consultation for patient ${patientId}`);
    return this.prisma.consultation.create({
      data: {
        patientId: patientId,
        status: 'pending_photos', // Yeni schema'daki enum
        medicalFormData: dto.medicalFormData || {},
      },
    });
  }

  // Akış 2: Pre-signed URL'leri üret
  async generateUploadUrls(dto: RequestUploadUrlsDto, userId: string) {
    this.logger.log(`Generating ${dto.files.length} URLs for consultation ${dto.consultationId}`);
    // Hala sahibini doğruluyoruz (iyi bir şey)
    await this.verifyConsultationOwner(dto.consultationId, userId);

    const uploadTasks: any[] = [];
    for (const file of dto.files) {
      const fileId = uuidv4();
      const fileExtension = file.filename.split('.').pop() || 'jpg';
      const key = `patients/${userId}/${dto.consultationId}/${file.angle_tag}-${fileId}.${fileExtension}`;

      const { preSignedUrl, publicUrl } =
        await this.s3.getPresignedUploadUrl(key, file.contentType);

      uploadTasks.push({
        angle_tag: file.angle_tag,
        preSignedUrl: preSignedUrl,
        finalUrl: publicUrl,
      });
    }
    return { uploadTasks };
  }

  // Akış 3: Yüklemeyi onayla ve DB'ye kaydet
  async confirmUpload(dto: ConfirmUploadDto, userId: string) {
    this.logger.log(`Confirming ${dto.photos.length} photos for consultation ${dto.consultationId}`);
    await this.verifyConsultationOwner(
      dto.consultationId,
      userId,
    );

    // 1. Fotoğraf URL'lerini DB'ye yaz
    await this.prisma.consultationPhoto.createMany({
      data: dto.photos.map((photo) => ({
        consultationId: dto.consultationId,
        fileUrl: photo.file_url,
        angleTag: photo.angle_tag,
      })),
    });

    // 2. Konsültasyon durumunu güncelle (Yeni schema'ya göre)
    const updatedConsultation = await this.prisma.consultation.update({
      where: { id: dto.consultationId },
      data: {
        status: 'pending_review',
      },
    });

    this.logger.log(`Consultation ${dto.consultationId} status updated to 'pending_review'`);
    return updatedConsultation;
  }

  // Hastanın KENDİ dosya paketlerini listele
  async findAllForPatient(patientId: string) {
    this.logger.log(`Fetching all consultations for patient ${patientId}`);

    const consultations = await this.prisma.consultation.findMany({
      where: { patientId: patientId },
      orderBy: { createdAt: 'desc' },
      include: {
        photos: {
          orderBy: { uploadedAt: 'asc' },
          take: 1,
        },
      },
    });

    // ... (Güvenli URL üretme mantığı - bu kalsın, bu iyi)
    const securedConsultations = await Promise.all(
      consultations.map(async (consultation) => {
        if (consultation.photos && consultation.photos.length > 0) {
          const originalUrl = consultation.photos[0].fileUrl;
          const urlParts = new URL(originalUrl);
          const key = urlParts.pathname.substring(1); 
          const temporaryUrl = await this.s3.getPresignedReadUrl(key);
          consultation.photos[0].fileUrl = temporaryUrl;
        }
        return consultation;
      }),
    );
    return securedConsultations;
  }
  
  // Admin için TÜM dosya paketlerini listele (Bu, admin panelinin "Dosyalar" sekmesi için)
  async findAllForAdmin() {
    return this.prisma.consultation.findMany({
      orderBy: { updatedAt: 'desc' },
      include: {
        patient: { 
          include: { profile: true },
        },
      },
    });
  }

  // Hastanın TEK BİR dosya paketini (tüm fotolarla) getir
  async findOneForPatient(consultationId: string, patientId: string) {
    await this.verifyConsultationOwner(consultationId, patientId);
    this.logger.log(`Fetching details for consultation ${consultationId}`);

    const consultation = await this.prisma.consultation.findUnique({
      where: { id: consultationId },
      include: {
        photos: { 
          orderBy: { angleTag: 'asc' },
        },
      },
    });

    if (!consultation) {
      throw new NotFoundException('Konsültasyon detayı bulunamadı.');
    }

    // ... (Tüm fotolar için güvenli URL üretme mantığı - bu da iyi)
    const securedPhotos = await Promise.all(
      consultation.photos.map(async (photo) => {
        const originalUrl = photo.fileUrl;
        const urlParts = new URL(originalUrl);
        const key = urlParts.pathname.substring(1);
        const temporaryUrl = await this.s3.getPresignedReadUrl(key);
        return { ...photo, fileUrl: temporaryUrl };
      }),
    );

    return { ...consultation, photos: securedPhotos };
  }

  // Güvenlik: Kullanıcının kendi konsültasyonuna işlem yaptığını doğrula
  private async verifyConsultationOwner(
    consultationId: string,
    userId: string,
  ) {
    // Admin ise bu kontrolü pas geç (Admin her şeyi yapabilir)
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (user && user.role === 'admin') {
      return; // Admin ise, kontrol etme, devam et
    }

    const consultation = await this.prisma.consultation.findUnique({
      where: { id: consultationId },
    });
    if (!consultation) {
      throw new NotFoundException('Konsültasyon bulunamadı.');
    }
    if (consultation.patientId !== userId) {
      throw new UnauthorizedException('Bu işlem için yetkiniz yok.');
    }
    return consultation;
  }

  // --- O PATLAYAN "ONAYLAMA" FONKSİYONLARI BURADAN SİLİNDİ ---
  // (Çünkü artık 'appointment.service.ts'in işi)
}