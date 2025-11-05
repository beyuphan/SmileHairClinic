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

  // Akış 1: Konsültasyon kaydını oluştur
  async createConsultation(
    dto: CreateConsultationDto,
    patientId: string,
  ) {
    this.logger.log(`Creating consultation for patient ${patientId}`);
    return this.prisma.consultation.create({
      data: {
        patientId: patientId,
        status: 'pending_photos',
        medicalFormData: dto.medicalFormData || {},
      },
    });
  }

  // Akış 2: Pre-signed URL'leri üret
  async generateUploadUrls(dto: RequestUploadUrlsDto, userId: string) {
    this.logger.log(`Generating ${dto.files.length} URLs for consultation ${dto.consultationId}`);
    await this.verifyConsultationOwner(dto.consultationId, userId);

    const uploadTasks: any[] = []; // Düzeltme burada

    for (const file of dto.files) {
      const fileId = uuidv4();
      const fileExtension = file.filename.split('.').pop() || 'jpg';
      const key = `patients/${userId}/${dto.consultationId}/${file.angle_tag}-${fileId}.${fileExtension}`;

      const { preSignedUrl, publicUrl } =
        await this.s3.getPresignedUploadUrl(key, file.contentType); // Bu satır 's3.service.ts' düzeldikten sonra çalışacak

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

    // 2. Konsültasyon durumunu güncelle
    const updatedConsultation = await this.prisma.consultation.update({
      where: { id: dto.consultationId },
      data: {
        status: 'pending_review',
      },
    });

    this.logger.log(`Consultation ${dto.consultationId} status updated to 'pending_review'`);
    return updatedConsultation;
  }

  async findAllForPatient(patientId: string) {
  this.logger.log(`Fetching all consultations for patient ${patientId}`);

  // 1. Önce veritabanından ham veriyi çek (thumbnail dahil)
  const consultations = await this.prisma.consultation.findMany({
    where: {
      patientId: patientId,
    },
    orderBy: {
      createdAt: 'desc',
    },
    include: {
      photos: {
        orderBy: { uploadedAt: 'asc' },
        take: 1,
      },
    },
  });

  // 2. Şimdi, her bir fotoğraf için GEÇİCİ URL üret (En önemli kısım)
  const securedConsultations = await Promise.all(
    consultations.map(async (consultation) => {

      if (consultation.photos && consultation.photos.length > 0) {
        
        const originalUrl = consultation.photos[0].fileUrl;
        
        // KRİTİK KOD: URL sınıfını kullanarak parçala
        const urlParts = new URL(originalUrl);
        const key = urlParts.pathname.substring(1); 

        // O 'key' için S3'ten geçici okuma URL'si iste
        const temporaryUrl = await this.s3.getPresignedReadUrl(key);

        // Orijinal URL yerine bu geçici URL'yi koy
        consultation.photos[0].fileUrl = temporaryUrl;
      }

      return consultation;
    }),
  );

  // 3. Flutter'a bu GÜVENLİ listeyi döndür
  return securedConsultations;

  }
  // YENİ FONKSİYON: Tek bir kaydın tüm detaylarını getir
async findOneForPatient(consultationId: string, patientId: string) {
  // 1. Önce bu kullanıcının bu kayda erişim hakkı var mı kontrol et
  // (Bu fonksiyon bizde zaten var)
  await this.verifyConsultationOwner(consultationId, patientId);

  this.logger.log(`Fetching details for consultation ${consultationId}`);

  // 2. Kaydın tüm detaylarını, TÜM fotoğraflarla birlikte çek
  const consultation = await this.prisma.consultation.findUnique({
    where: { id: consultationId },
    include: {
      photos: { // Thumbnail değil, HEPSİNİ al
        orderBy: {
          angleTag: 'asc', // Fotoğrafları 'front', 'top' sırasına göre al
        },
      },
    },
  });

  if (!consultation) {
    throw new NotFoundException('Konsültasyon detayı bulunamadı.');
  }

  // 3. Güvenlik: TÜM Fotoğrafları imzalı URL'lerle değiştir
  // (Bu 'map' mantığı 'findAllForPatient' ile aynı)
  const securedPhotos = await Promise.all(
    consultation.photos.map(async (photo) => {
      const originalUrl = photo.fileUrl;
      const urlParts = new URL(originalUrl); // URL importu en üstte olmalı
      const key = urlParts.pathname.substring(1);

      const temporaryUrl = await this.s3.getPresignedReadUrl(key);

      // Orijinal objeyi değiştirmeden yenisini yarat
      return {
        ...photo,
        fileUrl: temporaryUrl,
      };
    }),
  );

  // 4. Flutter'a güvenli ve tam detayı döndür
  return {
    ...consultation,
    photos: securedPhotos,
  };
}
  // Güvenlik: Kullanıcının kendi konsültasyonuna işlem yaptığını doğrula
  private async verifyConsultationOwner(
    consultationId: string,
    userId: string,
  ) {
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



}