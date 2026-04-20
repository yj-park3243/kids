import { IsOptional, IsString, IsInt, Min, Max, MaxLength } from 'class-validator';
import { Type } from 'class-transformer';
import { ApiProperty } from '@nestjs/swagger';

export class ListMessagesQueryDto {
  @ApiProperty({ required: false, description: 'ISO8601, 이전 페이지의 마지막 createdAt' })
  @IsOptional()
  @IsString()
  cursor?: string;

  @ApiProperty({ required: false, default: 50 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number = 50;
}

export class SendMessageDto {
  @ApiProperty({ example: '안녕하세요' })
  @IsString()
  @MaxLength(1000)
  content: string;
}
