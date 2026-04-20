import { IsOptional, IsString, Matches } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class PhoneVerifyDto {
  @ApiProperty({ example: '01012345678', description: '휴대폰 번호(하이픈 없이 숫자만)' })
  @IsString()
  @Matches(/^01[016789]\d{7,8}$/, { message: '올바른 휴대폰 번호 형식이 아닙니다.' })
  phoneNumber: string;

  @ApiProperty({
    example: '123456',
    required: false,
    description: '인증번호(없으면 발송 요청, 있으면 검증 요청)',
  })
  @IsOptional()
  @IsString()
  code?: string;
}
