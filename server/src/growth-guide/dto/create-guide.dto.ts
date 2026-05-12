import {
  IsString,
  IsInt,
  IsOptional,
  IsArray,
  Min,
  Max,
  MaxLength,
  ArrayMaxSize,
} from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class CreateGuideDto {
  @ApiProperty({ example: 12 })
  @IsInt()
  @Min(0)
  @Max(72)
  ageMonth: number;

  @ApiProperty({ example: '12개월 발달 가이드' })
  @IsString()
  @MaxLength(100)
  title: string;

  @ApiProperty({ example: '돌 즈음의 아이는...' })
  @IsString()
  @MaxLength(300)
  summary: string;

  @ApiProperty({ example: '## 발달 포인트\n...' })
  @IsString()
  bodyMarkdown: string;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  coverImage?: string;

  @ApiProperty({ required: false, example: ['걸음마', '이유식'] })
  @IsArray()
  @IsOptional()
  @IsString({ each: true })
  @ArrayMaxSize(10)
  tags?: string[];
}
