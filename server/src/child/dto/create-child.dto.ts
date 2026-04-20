import { IsString, IsInt, IsOptional, IsEnum, Min, Max, MinLength, MaxLength } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

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
}
