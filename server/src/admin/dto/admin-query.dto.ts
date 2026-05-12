import { IsString, IsInt, IsOptional, IsBoolean, IsIn, MaxLength } from 'class-validator';
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

export class CorrectIdentityDto {
  @ApiProperty({ enum: ['MOM', 'DAD'], nullable: true, required: false })
  @IsOptional()
  @IsString()
  parentGender?: 'MOM' | 'DAD' | null;

  @ApiProperty({ example: false })
  @IsBoolean()
  isSingleParent: boolean;
}

export class ResolveReportDto {
  @ApiProperty({ enum: ['REVIEWED', 'RESOLVED', 'DISMISSED'] })
  @IsIn(['REVIEWED', 'RESOLVED', 'DISMISSED'])
  status: 'REVIEWED' | 'RESOLVED' | 'DISMISSED';

  @ApiProperty({
    enum: ['NONE', 'WARNING', 'BAN_7D', 'BAN_PERMANENT'],
    required: false,
  })
  @IsOptional()
  @IsIn(['NONE', 'WARNING', 'BAN_7D', 'BAN_PERMANENT'])
  adminAction?: 'NONE' | 'WARNING' | 'BAN_7D' | 'BAN_PERMANENT';

  @ApiProperty({ required: false })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  adminNote?: string;
}

export class AdminInquiryQueryDto {
  @ApiProperty({ required: false, description: 'OPEN | REPLIED | CLOSED' })
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

export class ReplyInquiryDto {
  @ApiProperty()
  @IsString()
  @MaxLength(2000)
  reply: string;

  @ApiProperty({ required: false, enum: ['REPLIED', 'CLOSED'] })
  @IsOptional()
  @IsIn(['REPLIED', 'CLOSED'])
  status?: 'REPLIED' | 'CLOSED';
}
