import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { S3Client, PutObjectCommand, GetObjectCommand} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';

@Injectable()
export class S3Service {
  private readonly s3Client: S3Client;
  public readonly bucketName: string;
  private readonly region: string;
  public readonly s3Endpoint: string;

  // CONSTRUCTOR BURADA BAŞLIYOR
  constructor(private configService: ConfigService) {
    this.bucketName = this.configService.getOrThrow<string>('DO_SPACES_BUCKET');
    this.region = this.configService.getOrThrow<string>('DO_SPACES_REGION');
    this.s3Endpoint = this.configService.getOrThrow<string>('DO_SPACES_ENDPOINT');
    const accessKeyId = this.configService.getOrThrow<string>('DO_SPACES_KEY');
    const secretAccessKey = this.configService.getOrThrow<string>('DO_SPACES_SECRET');

    this.s3Client = new S3Client({
      endpoint: `https://${this.s3Endpoint}`,
      region: this.region,
      credentials: {
        accessKeyId: accessKeyId,
        secretAccessKey: secretAccessKey,
      },
    });
  } // <-- EKSİK OLAN PARANTEZ BURADAYDI.

  // ASIL FONKSİYON BURADA BAŞLIYOR
  async getPresignedUploadUrl(key: string, contentType: string) {
    const command = new PutObjectCommand({
      Bucket: this.bucketName,
      Key: key,
      ContentType: contentType,
      ACL: 'private',
    });

    const preSignedUrl = await getSignedUrl(this.s3Client, command, {
      expiresIn: 300,
    });

    const publicUrl = `https://${this.bucketName}.${this.s3Endpoint}/${key}`;

    return { preSignedUrl, publicUrl };
  }
async getPresignedReadUrl(key: string) {
  const command = new GetObjectCommand({ // PUT değil, GET
    Bucket: this.bucketName,
    Key: key,
  });

  // URL 10 dakika (600 saniye) geçerli olsun
  const preSignedUrl = await getSignedUrl(this.s3Client, command, {
    expiresIn: 600,
  });

  return preSignedUrl;
}
} 