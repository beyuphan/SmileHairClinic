import { IsObject, IsOptional } from 'class-validator';

export class CreateConsultationDto {
  @IsObject()
  @IsOptional()
  medicalFormData?: any; // Şimdilik esnek tutalım
}