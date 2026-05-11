import { IsString, IsInt, IsOptional, IsBoolean } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class AdminUserQueryDto {
  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  search?: string;

  @ApiProperty({ required: false, default: 1 })
  @IsInt()
  @IsOptional()
  page?: number = 1;

  @ApiProperty({ required: false, default: 20 })
  @IsInt()
  @IsOptional()
  limit?: number = 20;
}

export class AdminRoomQueryDto {
  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  search?: string;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  status?: string;

  @ApiProperty({ required: false, default: 1 })
  @IsInt()
  @IsOptional()
  page?: number = 1;

  @ApiProperty({ required: false, default: 20 })
  @IsInt()
  @IsOptional()
  limit?: number = 20;
}

export class AdminReportQueryDto {
  @ApiProperty({ required: false, description: 'OPEN | REVIEWED | RESOLVED | DISMISSED' })
  @IsString()
  @IsOptional()
  status?: string;

  @ApiProperty({ required: false, description: 'SPAM | ABUSE | INAPPROPRIATE | FRAUD | OTHER' })
  @IsString()
  @IsOptional()
  reason?: string;

  @ApiProperty({ required: false, default: 1 })
  @IsInt()
  @IsOptional()
  page?: number = 1;

  @ApiProperty({ required: false, default: 20 })
  @IsInt()
  @IsOptional()
  limit?: number = 20;
}

export class BanUserDto {
  @ApiProperty({ example: true })
  @IsBoolean()
  banned: boolean;
}

export class VerifyUserDto {
  @ApiProperty({ example: true })
  @IsBoolean()
  isPhoneVerified: boolean;
}
