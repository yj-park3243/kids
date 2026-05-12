import {
  IsInt,
  Min,
  Max,
  IsArray,
  IsString,
  IsOptional,
  MaxLength,
  ArrayMaxSize,
} from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class UpdateReviewDto {
  @ApiProperty({ example: 4, minimum: 1, maximum: 5, required: false })
  @IsInt()
  @Min(1)
  @Max(5)
  @IsOptional()
  score?: number;

  @ApiProperty({ example: ['친절했어요'], type: [String], required: false })
  @IsArray()
  @IsString({ each: true })
  @ArrayMaxSize(10)
  @IsOptional()
  tags?: string[];

  @ApiProperty({ required: false, maxLength: 200 })
  @IsString()
  @IsOptional()
  @MaxLength(200)
  comment?: string;
}
