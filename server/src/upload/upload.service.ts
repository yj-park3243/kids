import { Injectable, BadRequestException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  S3Client,
  PutObjectCommand,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { v4 as uuidv4 } from 'uuid';

@Injectable()
export class UploadService {
  private s3Client: S3Client;
  private bucket: string;

  constructor(private configService: ConfigService) {
    this.s3Client = new S3Client({
      region: this.configService.get('AWS_REGION', 'ap-northeast-2'),
      credentials: {
        accessKeyId: this.configService.get('AWS_ACCESS_KEY_ID', ''),
        secretAccessKey: this.configService.get('AWS_SECRET_ACCESS_KEY', ''),
      },
    });
    this.bucket = this.configService.get('AWS_S3_BUCKET', 'kids-uploads-518');
  }

  async uploadImage(file: Express.Multer.File) {
    if (!file) {
      throw new BadRequestException('이미지 파일이 필요합니다.');
    }

    // Validate file type
    const allowedMimes = ['image/jpeg', 'image/png', 'image/webp'];
    if (!allowedMimes.includes(file.mimetype)) {
      throw new BadRequestException('jpg, png, webp 형식의 이미지만 업로드 가능합니다.');
    }

    // Validate file size (5MB)
    if (file.size > 5 * 1024 * 1024) {
      throw new BadRequestException('이미지 크기는 5MB 이하여야 합니다.');
    }

    const ext = file.originalname.split('.').pop();
    const key = `images/${uuidv4()}.${ext}`;

    const command = new PutObjectCommand({
      Bucket: this.bucket,
      Key: key,
      Body: file.buffer,
      ContentType: file.mimetype,
    });

    await this.s3Client.send(command);

    const url = `https://${this.bucket}.s3.${this.configService.get('AWS_REGION')}.amazonaws.com/${key}`;

    return { url };
  }

  async getPresignedUrl(filename: string, contentType: string) {
    const ext = filename.split('.').pop();
    const key = `images/${uuidv4()}.${ext}`;

    const command = new PutObjectCommand({
      Bucket: this.bucket,
      Key: key,
      ContentType: contentType,
    });

    const presignedUrl = await getSignedUrl(this.s3Client, command, {
      expiresIn: 3600,
    });

    const fileUrl = `https://${this.bucket}.s3.${this.configService.get('AWS_REGION')}.amazonaws.com/${key}`;

    return {
      presignedUrl,
      fileUrl,
      key,
    };
  }
}
