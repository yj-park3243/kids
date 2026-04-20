import { IsString, IsOptional, MinLength, MaxLength } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class CreateProfileDto {
  @ApiProperty({ example: '콩이맘', minLength: 2, maxLength: 10 })
  @IsString()
  @MinLength(2, { message: '닉네임은 2자 이상이어야 합니다.' })
  @MaxLength(10, { message: '닉네임은 10자 이하여야 합니다.' })
  nickname: string;

  @ApiProperty({ example: '서울특별시' })
  @IsString()
  regionSido: string;

  @ApiProperty({ example: '강남구' })
  @IsString()
  regionSigungu: string;

  @ApiProperty({ example: '역삼동' })
  @IsString()
  regionDong: string;

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
