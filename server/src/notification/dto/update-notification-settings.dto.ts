import { IsBoolean, IsOptional } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';

export class UpdateNotificationSettingsDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  notifyAll?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  notifyRoom?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  notifyChat?: boolean;
}
