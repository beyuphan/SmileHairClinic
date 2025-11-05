import { Type } from 'class-transformer';
import { IsArray, IsEnum, IsString, ValidateNested } from 'class-validator';
import { AngleTag } from '@prisma/client'; // Prisma şemamızdaki enum'ı kullan

export class FileInfoDto {
  @IsString()
  filename: string;

  @IsString()
  contentType: string;

  @IsEnum(AngleTag)
  angle_tag: AngleTag;
}

export class RequestUploadUrlsDto {
  @IsString()
  consultationId: string;

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => FileInfoDto)
  files: FileInfoDto[];
}