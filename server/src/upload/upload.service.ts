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

  // 확장자·ContentType 을 클라이언트 입력이 아닌 검증된 타입에서만 파생시킨다.
  private static readonly IMAGE_TYPES: Record<
    'jpg' | 'png' | 'webp',
    string
  > = {
    jpg: 'image/jpeg',
    png: 'image/png',
    webp: 'image/webp',
  };

  // 파일 내용(매직바이트)으로 실제 이미지 형식을 판별. 클라이언트가 보낸
  // mimetype/파일명은 위조 가능하므로 신뢰하지 않는다.
  private detectImageType(buffer: Buffer): 'jpg' | 'png' | 'webp' | null {
    if (!buffer || buffer.length < 12) return null;
    // JPEG: FF D8 FF
    if (buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff) {
      return 'jpg';
    }
    // PNG: 89 50 4E 47 0D 0A 1A 0A
    if (
      buffer[0] === 0x89 &&
      buffer[1] === 0x50 &&
      buffer[2] === 0x4e &&
      buffer[3] === 0x47 &&
      buffer[4] === 0x0d &&
      buffer[5] === 0x0a &&
      buffer[6] === 0x1a &&
      buffer[7] === 0x0a
    ) {
      return 'png';
    }
    // WebP: "RIFF" ....  "WEBP"
    if (
      buffer.toString('ascii', 0, 4) === 'RIFF' &&
      buffer.toString('ascii', 8, 12) === 'WEBP'
    ) {
      return 'webp';
    }
    return null;
  }

  async uploadImage(file: Express.Multer.File) {
    if (!file) {
      throw new BadRequestException('이미지 파일이 필요합니다.');
    }

    // Validate file size (5MB)
    if (file.size > 5 * 1024 * 1024) {
      throw new BadRequestException('이미지 크기는 5MB 이하여야 합니다.');
    }

    // 매직바이트로 실제 형식 확인 — 위조된 mimetype/확장자는 여기서 걸린다.
    const type = this.detectImageType(file.buffer);
    if (!type) {
      throw new BadRequestException(
        'jpg, png, webp 형식의 이미지만 업로드 가능합니다.',
      );
    }

    const contentType = UploadService.IMAGE_TYPES[type];
    const key = `images/${uuidv4()}.${type}`;

    const command = new PutObjectCommand({
      Bucket: this.bucket,
      Key: key,
      Body: file.buffer,
      ContentType: contentType,
    });

    await this.s3Client.send(command);

    const url = `https://${this.bucket}.s3.${this.configService.get('AWS_REGION')}.amazonaws.com/${key}`;

    return { url };
  }

  async getPresignedUrl(filename: string, contentType: string) {
    // 확장자는 파일명이 아니라 검증된 contentType 에서만 파생 — 임의 확장자
    // (.php/.svg 등) 객체가 만들어지지 않게 한다.
    const ext = (
      Object.keys(UploadService.IMAGE_TYPES) as Array<
        keyof typeof UploadService.IMAGE_TYPES
      >
    ).find((k) => UploadService.IMAGE_TYPES[k] === contentType);
    if (!ext) {
      throw new BadRequestException(
        'jpg, png, webp 형식만 업로드 가능합니다.',
      );
    }
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
