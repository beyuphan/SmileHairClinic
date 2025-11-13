// backend/src/appointment/dto/book-slot.dto.ts
import { IsNotEmpty, IsUUID } from 'class-validator';

export class BookSlotDto {
  @IsNotEmpty()
  @IsUUID()
  slotId: string;

  @IsNotEmpty()
  @IsUUID()
  consultationId: string;
}