import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class TimelineService {
  private readonly logger = new Logger(TimelineService.name);

  constructor(private prisma: PrismaService) {}

  // Hastanın tüm "Yolculuk" görevlerini bul
  async findAllForPatient(patientId: string) {
    this.logger.log(`Fetching timeline events for patient ${patientId}`);

    return this.prisma.timelineEvent.findMany({
      where: {
        patientId: patientId,
      },
      orderBy: {
        eventDate: 'asc', // Görevleri tarihe göre (eskiden yeniye) sırala
      },
    });
  }

  async createEvent(patientId: string, dto: { title: string; description: string; eventDate: Date; type?: string; videoUrl?: string }) {
  this.logger.log(`Creating timeline event for patient ${patientId}`);

  return this.prisma.timelineEvent.create({
    data: {
      patientId: patientId,
      title: dto.title,
      description: dto.description,
      eventDate: dto.eventDate,
      type: (dto.type as any) ?? 'INFO',
      videoUrl: dto.videoUrl ?? null, 
    },
  });
}
}