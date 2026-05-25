import { IsString, IsInt, IsOptional, Min, Max, MinLength, MaxLength } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class UpdateChildDto {
  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  @MinLength(1)
  @MaxLength(10)
  nickname?: string;

  @ApiProperty({ required: false })
  @IsInt()
  @IsOptional()
  birthYear?: number;

  @ApiProperty({ required: false })
  @IsInt()
  @IsOptional()
  @Min(1)
  @Max(12)
  birthMonth?: number;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  gender?: string;

  @ApiProperty({ required: false, description: '프로필 사진 URL (공개)' })
  @IsString()
  @IsOptional()
  photoUrl?: string;

  @ApiProperty({
    required: false,
    description: '인증 사진 URL — 출생증명서/키즈노트 캡쳐 등 어드민 검수용',
  })
  @IsString()
  @IsOptional()
  verificationPhotoUrl?: string;
}
