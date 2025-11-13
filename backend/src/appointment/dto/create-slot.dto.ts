// backend/src/appointment/dto/create-slot.dto.ts
import { IsDate, IsNotEmpty } from 'class-validator';
import { Type } from 'class-transformer';

export class CreateSlotDto {
  @IsNotEmpty()
  @IsDate()
  @Type(() => Date) // Gelen JSON string'i Date objesine çevir
  dateTime: Date;
}