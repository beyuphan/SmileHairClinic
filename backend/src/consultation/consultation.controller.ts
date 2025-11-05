// backend/src/consultation/consultation.controller.ts
import { Controller, Post, Body, UseGuards, Get, Param ,Request as NestRequest } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard'; // Korumamızı import et
import { ConsultationService } from './consultation.service';
import { CreateConsultationDto } from './dto/create-consultation.dto';
import { RequestUploadUrlsDto } from './dto/request-upload.dto';
import { ConfirmUploadDto } from './dto/confirm-upload.dto';

@UseGuards(JwtAuthGuard) // BU MODÜLDEKİ TÜM ENDPOINT'LERİ KORU
@Controller('consultations')
export class ConsultationController {
  constructor(private readonly consultationService: ConsultationService) {}

  @Get()
  findAllForPatient(@NestRequest() req) {
    const userId = req.user.userId; // Token'dan gelen kullanıcı kimliği
    return this.consultationService.findAllForPatient(userId);
  }
  @Get(':id')
  findOneForPatient(@Param('id') id: string, @NestRequest() req) {
    const userId = req.user.userId;
    return this.consultationService.findOneForPatient(id, userId);
  }
  // Akış 1: Yeni konsültasyon kaydı oluştur
  @Post()
  create(@Body() createDto: CreateConsultationDto, @NestRequest() req) {
    const userId = req.user.userId; // Token'dan gelen kullanıcı kimliği
    return this.consultationService.createConsultation(createDto, userId);
  }

  // Akış 2: URL'leri talep et
  @Post('request-upload-urls')
  requestUploadUrls(
    @Body() requestDto: RequestUploadUrlsDto,
    @NestRequest() req,
  ) {
    const userId = req.user.userId; // Token'dan gelen kullanıcı kimliği
    return this.consultationService.generateUploadUrls(requestDto, userId);
  }

  // Akış 3: Yüklemeyi onayla
  @Post('confirm-upload')
  confirmUpload(@Body() confirmDto: ConfirmUploadDto, @NestRequest() req) {
    const userId = req.user.userId; // Token'dan gelen kullanıcı kimliği
    return this.consultationService.confirmUpload(confirmDto, userId);
  }
}