import { IsOptional, IsString, IsInt, Min, Max, MaxLength, IsIn } from 'class-validator';
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

  /// LOCATION 일 때 content 는 JSON 문자열 `{"lat":..,"lng":..,"label":"..."}`.
  @ApiProperty({
    required: false,
    enum: ['TEXT', 'LOCATION'],
    description: '메시지 타입. 기본 TEXT.',
  })
  @IsOptional()
  @IsIn(['TEXT', 'LOCATION'])
  type?: 'TEXT' | 'LOCATION';
}

export class MarkReadDto {
  @ApiProperty({
    required: false,
    description: '이 시점까지 읽음 처리 (ISO8601). 생략 시 서버 now()',
  })
  @IsOptional()
  @IsString()
  asOf?: string;
}
