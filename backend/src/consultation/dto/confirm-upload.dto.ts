import { Type } from 'class-transformer';
import { IsArray, IsEnum, IsString, IsUrl, ValidateNested } from 'class-validator';
import { AngleTag } from '@prisma/client';

export class PhotoUploadDto {
  @IsUrl()
  file_url: string;

  @IsEnum(AngleTag)
  angle_tag: AngleTag;
}

export class ConfirmUploadDto {
  @IsString()
  consultationId: string;

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => PhotoUploadDto)
  photos: PhotoUploadDto[];
}