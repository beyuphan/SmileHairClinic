// backend/src/consultation/consultation.controller.ts
import {
  Controller,
  Post,
  Body,
  UseGuards,
  Req,
  Get,
  Param,
} from '@nestjs/common';
import { ConsultationService } from './consultation.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CreateConsultationDto } from './dto/create-consultation.dto';
import { RequestUploadUrlsDto } from './dto/request-upload.dto';
import { ConfirmUploadDto } from './dto/confirm-upload.dto';
import { Roles } from '../auth/roles.decorator'; // Admin için
import { RolesGuard } from '../auth/roles.guard';   // Admin için
import { Role } from '@prisma/client';       // Admin için

@Controller('consultations')
export class ConsultationController {
  constructor(
    private readonly consultationService: ConsultationService,
  ) {}

  @Post()
  @UseGuards(JwtAuthGuard)
  create(@Body() dto: CreateConsultationDto, @Req() req) {
    return this.consultationService.createConsultation(dto, req.user.id);
  }

  @Post('request-upload-urls')
  @UseGuards(JwtAuthGuard)
  requestUploadUrls(@Body() dto: RequestUploadUrlsDto, @Req() req) {
    return this.consultationService.generateUploadUrls(dto, req.user.id);
  }

  @Post('confirm-upload')
  @UseGuards(JwtAuthGuard)
  confirmUpload(@Body() dto: ConfirmUploadDto, @Req() req) {
    return this.consultationService.confirmUpload(dto, req.user.id);
  }

  @Get()
  @UseGuards(JwtAuthGuard)
  findAllForPatient(@Req() req) {
    return this.consultationService.findAllForPatient(req.user.id);
  }

  @Get('admin/all')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.admin)
  findAllForAdmin() {
    return this.consultationService.findAllForAdmin();
  }

  @Get(':id')
  @UseGuards(JwtAuthGuard)
  findOne(@Param('id') id: string, @Req() req) {
    return this.consultationService.findOneForPatient(id, req.user.id);
  }

  // --- HATA VEREN O İKİ BLOK BURADAN SİLİNDİ ---
  // @Get('admin/pending-approval') ... SİLİNDİ
  // @Post('admin/approve/:consultationId') ... SİLİNDİ
}