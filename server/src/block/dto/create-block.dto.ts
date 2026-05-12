import { IsUUID } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class CreateBlockDto {
  @ApiProperty({ example: 'uuid' })
  @IsUUID()
  targetUserId: string;
}
