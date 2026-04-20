import { IsEnum, IsOptional, IsString } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export enum AuthProvider {
  KAKAO = 'KAKAO',
  APPLE = 'APPLE',
  GOOGLE = 'GOOGLE',
}

export class SocialLoginDto {
  @ApiProperty({ enum: AuthProvider })
  @IsEnum(AuthProvider)
  provider: AuthProvider;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  accessToken?: string;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  idToken?: string;
}
