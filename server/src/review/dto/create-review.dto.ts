import {
  IsUUID,
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

export class CreateReviewDto {
  @ApiProperty({ example: 'uuid' })
  @IsUUID()
  targetUserId: string;

  @ApiProperty({ example: 5, minimum: 1, maximum: 5 })
  @IsInt()
  @Min(1)
  @Max(5)
  score: number;

  @ApiProperty({ example: ['친절했어요', '약속 잘 지켜요'], type: [String] })
  @IsArray()
  @IsString({ each: true })
  @ArrayMaxSize(10)
  tags: string[];

  @ApiProperty({ required: false, maxLength: 200 })
  @IsString()
  @IsOptional()
  @MaxLength(200)
  comment?: string;
}
