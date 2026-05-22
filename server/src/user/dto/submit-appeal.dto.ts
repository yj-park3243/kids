import { IsString } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class SubmitAppealDto {
  @ApiProperty({ description: '정지 해제 요청용 증거 사진 URL' })
  @IsString()
  photoUrl: string;
}
