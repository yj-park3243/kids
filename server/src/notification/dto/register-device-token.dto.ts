import { IsString, IsEnum } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export enum Platform {
  IOS = 'IOS',
  ANDROID = 'ANDROID',
}

export class RegisterDeviceTokenDto {
  @ApiProperty()
  @IsString()
  token: string;

  @ApiProperty({ enum: Platform })
  @IsEnum(Platform)
  platform: Platform;
}
