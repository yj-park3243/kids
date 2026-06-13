import {
  IsString,
  IsOptional,
  MinLength,
  MaxLength,
  IsIn,
  IsBoolean,
  IsNumber,
} from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class CreateProfileDto {
  @ApiProperty({ example: '콩이맘', minLength: 2, maxLength: 10 })
  @IsString()
  @MinLength(2, { message: '닉네임은 2자 이상이어야 합니다.' })
  @MaxLength(10, { message: '닉네임은 10자 이하여야 합니다.' })
  nickname: string;

  @ApiProperty({ example: '서울특별시', required: false })
  @IsString()
  @IsOptional()
  regionSido?: string;

  @ApiProperty({ example: '강남구', required: false })
  @IsString()
  @IsOptional()
  regionSigungu?: string;

  @ApiProperty({ example: '역삼동', required: false })
  @IsString()
  @IsOptional()
  regionDong?: string;

  @ApiProperty({ required: false })
  @IsNumber()
  @IsOptional()
  latitude?: number;

  @ApiProperty({ required: false })
  @IsNumber()
  @IsOptional()
  longitude?: number;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  profileImageUrl?: string;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  @MaxLength(200)
  introduction?: string;

  // 부모 성별 / 한부모 여부는 가입 후 수정 불가 (정정은 관리자 경로).
  @ApiProperty({ enum: ['MOM', 'DAD'], example: 'MOM' })
  @IsIn(['MOM', 'DAD'], {
    message: 'PARENT_GENDER_REQUIRED',
    context: { code: 'PARENT_GENDER_REQUIRED' },
  })
  parentGender: 'MOM' | 'DAD';

  @ApiProperty({ example: false })
  @IsBoolean()
  isSingleParent: boolean;
}
