import {
  IsString,
  IsInt,
  IsOptional,
  IsArray,
  Min,
  Max,
  MinLength,
  MaxLength,
  ArrayMaxSize,
} from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class UpdateRoomDto {
  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  @MinLength(2)
  @MaxLength(30)
  title?: string;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  @MinLength(10)
  @MaxLength(500)
  description?: string;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  startTime?: string;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  endTime?: string;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  placeName?: string;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  placeAddress?: string;

  @ApiProperty({ required: false })
  @IsInt()
  @IsOptional()
  @Min(2)
  @Max(10)
  maxMembers?: number;

  @ApiProperty({ required: false })
  @IsInt()
  @IsOptional()
  @Min(0)
  cost?: number;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  costDescription?: string;

  @ApiProperty({ required: false })
  @IsArray()
  @IsOptional()
  @IsString({ each: true })
  @ArrayMaxSize(5)
  tags?: string[];
}
