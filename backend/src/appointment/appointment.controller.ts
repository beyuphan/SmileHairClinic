// backend/src/appointment/appointment.controller.ts
import { Controller, Post, Body, UseGuards, Get, Req, Delete, Param } from '@nestjs/common';
import { AppointmentService } from './appointment.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { Role } from '@prisma/client';
import { CreateSlotDto } from './dto/create-slot.dto';
import { BookSlotDto } from './dto/book-slot.dto';

@Controller('appointments') // Bütün endpoint'ler '/appointments' ile başlayacak
export class AppointmentController {
  constructor(private readonly appointmentService: AppointmentService) {}

  // --- Admin ---
  @Post('admin/create-slot')
  @UseGuards(JwtAuthGuard, RolesGuard) // Önce JWT kontrolü, sonra Rol kontrolü
  @Roles(Role.admin) // Sadece 'admin' rolü girebilir
  createSlot(@Body() dto: CreateSlotDto) {
    return this.appointmentService.createSlot(dto);
  }

  // --- Kullanıcı ---
  @Get('available-slots')
  @UseGuards(JwtAuthGuard) // Sadece giriş yapmış kullanıcılar görebilir
  getAvailableSlots() {
    return this.appointmentService.getAvailableSlots();
  }

  // --- Kullanıcı ---
  @Post('book-slot')
  @UseGuards(JwtAuthGuard) // Sadece giriş yapmış kullanıcılar
  bookSlot(@Req() req, @Body() dto: BookSlotDto) {
    // req.user -> JWT'den gelen (token'ı çözülmüş) kullanıcı bilgisi
    return this.appointmentService.bookSlot(req.user, dto);
  }

  // --- Silme ---
  @Delete('admin/delete-slot/:slotId')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.admin) // Sadece 'admin'
  deleteSlot(
    @Req() req,
    @Param('slotId') slotId: string,
  ) {
    return this.appointmentService.deleteSlot(req.user, slotId);
  }
}