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

export class BanUserDto {
  @ApiProperty({ example: true })
  @IsBoolean()
  banned: boolean;
}
