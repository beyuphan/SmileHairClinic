import { Controller, Get, Post, Body, Param, UseGuards, Request as NestRequest } from '@nestjs/common';
import { TimelineService } from './timeline.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard'; // Güvenlik Kalkanı

@UseGuards(JwtAuthGuard) // Bu endpoint'ler korumalı
@Controller('timeline')
export class TimelineController {
  constructor(private readonly timelineService: TimelineService) {}

  @Get()
  findAllForPatient(@NestRequest() req) {
    const userId = req.user.userId; // Token'dan gelen kullanıcı kimliği
    return this.timelineService.findAllForPatient(userId);
  }

  @Post(':patientId')
  // TODO: Burayı @Roles('doctor') ile korumalıyız
  createEvent(
    @Param('patientId') patientId: string,
    @Body() dto: { title: string; description: string; eventDate: Date; type: string },
  ) {
    return this.timelineService.createEvent(patientId, dto);
  }
}