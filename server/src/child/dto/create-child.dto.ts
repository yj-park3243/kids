import {
  IsString,
  IsInt,
  IsOptional,
  IsEnum,
  IsArray,
  ArrayMaxSize,
  Min,
  Max,
  MinLength,
  MaxLength,
} from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

const NAP_TIME_VALUES = ['MORNING', 'AFTERNOON', 'LATE_AFTERNOON', 'EVENING', 'NONE'] as const;

export class CreateChildDto {
  @ApiProperty({ example: '콩이' })
  @IsString()
  @MinLength(1, { message: '아이 별명은 1자 이상이어야 합니다.' })
  @MaxLength(10, { message: '아이 별명은 10자 이하여야 합니다.' })
  nickname: string;

  @ApiProperty({ example: 2024 })
  @IsInt()
  birthYear: number;

  @ApiProperty({ example: 6 })
  @IsInt()
  @Min(1)
  @Max(12)
  birthMonth: number;

  @ApiProperty({ required: false, enum: ['MALE', 'FEMALE'] })
  @IsString()
  @IsOptional()
  gender?: string;

  @ApiProperty({ required: false, description: '프로필 사진 URL (공개)' })
  @IsString()
  @IsOptional()
  photoUrl?: string;

  @ApiProperty({
    required: false,
    description: '인증 사진 URL — 출생증명서/키즈노트 캡쳐 등 어드민 검수용 (비공개)',
  })
  @IsString()
  @IsOptional()
  verificationPhotoUrl?: string;

  @ApiProperty({ required: false, enum: NAP_TIME_VALUES })
  @IsOptional()
  @IsEnum(NAP_TIME_VALUES)
  napTime?: string;

  @ApiProperty({ required: false, type: [String], description: '기질 태그 (최대 5개)' })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(5)
  @IsString({ each: true })
  temperamentTags?: string[];
}
