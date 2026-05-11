import {
  IsString,
  IsOptional,
  IsObject,
  MaxLength,
  MinLength,
  IsUUID,
  IsIn,
} from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class CreateErrorLogDto {
  @ApiProperty()
  @IsString()
  @MinLength(1)
  @MaxLength(5000)
  errorMessage: string;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  @MaxLength(20000)
  stackTrace?: string;

  @ApiProperty({ required: false })
  @IsObject()
  @IsOptional()
  deviceInfo?: Record<string, unknown>;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  @MaxLength(100)
  screenName?: string;
}

export class CreateInquiryDto {
  @ApiProperty()
  @IsString()
  @MinLength(1)
  @MaxLength(200)
  subject: string;

  @ApiProperty()
  @IsString()
  @MinLength(1)
  @MaxLength(5000)
  message: string;
}

export class CreateReportDto {
  @ApiProperty({ required: false })
  @IsUUID()
  @IsOptional()
  targetUserId?: string;

  @ApiProperty({ required: false })
  @IsUUID()
  @IsOptional()
  targetRoomId?: string;

  @ApiProperty({ enum: ['SPAM', 'ABUSE', 'INAPPROPRIATE', 'FRAUD', 'OTHER'] })
  @IsString()
  @IsIn(['SPAM', 'ABUSE', 'INAPPROPRIATE', 'FRAUD', 'OTHER'])
  reason: string;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  @MaxLength(2000)
  detail?: string;
}
