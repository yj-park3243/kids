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
}
