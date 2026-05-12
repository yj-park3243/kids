import {
  IsString,
  IsOptional,
  MinLength,
  MaxLength,
  IsIn,
  IsBoolean,
} from 'class-validator';
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

  // ↓ 가입 후 수정 불가 필드. ValidationPipe(forbidNonWhitelisted) 통과를 위해 받기만 하고 서비스에서 무시.
  @ApiProperty({ required: false, deprecated: true })
  @IsOptional()
  @IsIn(['MOM', 'DAD'])
  parentGender?: 'MOM' | 'DAD';

  @ApiProperty({ required: false, deprecated: true })
  @IsOptional()
  @IsBoolean()
  isSingleParent?: boolean;
}
