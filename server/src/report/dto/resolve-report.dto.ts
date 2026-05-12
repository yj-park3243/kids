import { IsString, IsOptional, IsEnum, MaxLength } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export enum ResolveStatus {
  RESOLVED = 'RESOLVED',
  DISMISSED = 'DISMISSED',
}

export enum AdminAction {
  NONE = 'NONE',
  WARNING = 'WARNING',
  BAN_7D = 'BAN_7D',
  BAN_PERMANENT = 'BAN_PERMANENT',
}

export class ResolveReportDto {
  @ApiProperty({ enum: ResolveStatus })
  @IsEnum(ResolveStatus)
  status: ResolveStatus;

  @ApiProperty({ enum: AdminAction })
  @IsEnum(AdminAction)
  adminAction: AdminAction;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  @MaxLength(500)
  adminNote?: string;
}

export class AdminReportListQueryDto {
  @ApiProperty({ required: false, description: 'PENDING | RESOLVED | DISMISSED' })
  @IsString()
  @IsOptional()
  status?: string;

  @ApiProperty({ required: false, default: 1 })
  @IsOptional()
  page?: number;

  @ApiProperty({ required: false, default: 20 })
  @IsOptional()
  limit?: number;
}
