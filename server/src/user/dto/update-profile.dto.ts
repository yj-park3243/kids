import { IsString, IsOptional, MinLength, MaxLength } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class UpdateProfileDto {
  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  @MinLength(2)
  @MaxLength(10)
  nickname?: string;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  regionSido?: string;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  regionSigungu?: string;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  regionDong?: string;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  profileImageUrl?: string;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  @MaxLength(200)
  introduction?: string;
}
