import { IsString, IsOptional, IsEnum, IsUUID, MaxLength } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export enum ReportTargetType {
  USER = 'USER',
  ROOM = 'ROOM',
  CHAT_MESSAGE = 'CHAT_MESSAGE',
}

export enum ReportReason {
  SPAM = 'SPAM',
  INAPPROPRIATE = 'INAPPROPRIATE',
  HARASSMENT = 'HARASSMENT',
  FAKE_PROFILE = 'FAKE_PROFILE',
  NO_SHOW = 'NO_SHOW',
  OTHER = 'OTHER',
}

export class CreateReportDto {
  @ApiProperty({ enum: ReportTargetType })
  @IsEnum(ReportTargetType)
  targetType: ReportTargetType;

  @ApiProperty()
  @IsUUID()
  targetId: string;

  @ApiProperty({ enum: ReportReason })
  @IsEnum(ReportReason)
  reason: ReportReason;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  @MaxLength(500)
  description?: string;
}
