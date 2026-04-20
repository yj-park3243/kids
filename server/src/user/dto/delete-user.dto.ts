import { IsString, IsOptional } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class DeleteUserDto {
  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  reason?: string;
}
