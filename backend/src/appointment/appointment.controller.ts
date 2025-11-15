// backend/src/appointment/appointment.controller.ts
import { Controller, Post, Body, UseGuards, Get, Req, Delete, Param } from '@nestjs/common';
import { AppointmentService } from './appointment.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { Role } from '@prisma/client';
import { CreateSlotDto } from './dto/create-slot.dto';
import { BookSlotDto } from './dto/book-slot.dto';

@Controller('appointments')
export class AppointmentController {
  constructor(private readonly appointmentService: AppointmentService) {}

  // --- EKSİK ENDPOINT (404 VERİYORDU) ---
  @Get('available-slots')
  @UseGuards(JwtAuthGuard) // Sadece giriş yapanlar (Flutter) görebilir
  getAvailableSlots() {
    return this.appointmentService.getAvailableSlots();
  }
  
  // --- EKSİK ENDPOINT (404 VERİYORDU) ---
  @Post('book-slot')
  @UseGuards(JwtAuthGuard) // Sadece giriş yapanlar (Flutter)
  bookSlot(@Req() req, @Body() dto: BookSlotDto) {
    return this.appointmentService.bookSlot(req.user, dto);
  }

  // --- Admin: Slot Yarat (Bu zaten vardı) ---
  @Post('admin/create-slot')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.admin)
  createSlot(@Body() dto: CreateSlotDto) {
    return this.appointmentService.createSlot(dto);
  }

  // --- Admin: Slot Sil (Bu zaten vardı) ---
  @Delete('admin/delete-slot/:slotId')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.admin)
  deleteSlot(
    @Req() req,
    @Param('slotId') slotId: string,
  ) {
    return this.appointmentService.deleteSlot(req.user, slotId);
  }

  // --- Admin: Onay Bekleyenler (Bu zaten vardı) ---
  @Get('admin/pending-approvals')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.admin)
  findPendingApprovals() {
    return this.appointmentService.findPendingApprovals();
  }

  // --- Admin: Onayla (Bu zaten vardı) ---
  @Post('admin/approve/:slotId') 
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.admin)
  approveAppointment(@Param('slotId') slotId: string) {
    return this.appointmentService.approveAppointment(slotId);
  }
}