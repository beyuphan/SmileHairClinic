import { IsNotEmpty, IsUUID } from 'class-validator';

export class BookSlotDto {
  @IsNotEmpty()
  @IsUUID()
  slotId: string;

  // consultationId ARTIK YOK!
}