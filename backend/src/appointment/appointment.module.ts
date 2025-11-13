// backend/src/appointment/appointment.module.ts
import { Module } from '@nestjs/common';
import { AppointmentService } from './appointment.service';
import { AppointmentController } from './appointment.controller';
import { PrismaModule } from '../prisma/prisma.module';
import { AuthModule } from '../auth/auth.module';

@Module({
  imports: [PrismaModule, AuthModule], // Prisma ve Auth'u import et
  controllers: [AppointmentController],
  providers: [AppointmentService],
})
export class AppointmentModule {}