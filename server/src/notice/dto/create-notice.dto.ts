import { IsString, IsOptional, IsBoolean, MaxLength } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class CreateNoticeDto {
  @ApiProperty({ example: '같이크자 정식 오픈 안내' })
  @IsString()
  @MaxLength(200)
  title: string;

  @ApiProperty({ example: '안녕하세요, 같이크자입니다...' })
  @IsString()
  content: string;

  @ApiProperty({ required: false, default: false })
  @IsBoolean()
  @IsOptional()
  isPinned?: boolean;

  @ApiProperty({ required: false, default: true })
  @IsBoolean()
  @IsOptional()
  isPublished?: boolean;
}
