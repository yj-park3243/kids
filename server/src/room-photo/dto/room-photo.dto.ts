import { ApiProperty } from '@nestjs/swagger';
import {
  IsArray,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

export class UpdatePhotoTagsDto {
  @ApiProperty({ example: ['uuid1', 'uuid2'] })
  @IsArray()
  @IsUUID('all', { each: true })
  childIds: string[];
}

export class CreatePhotoCommentDto {
  @ApiProperty()
  @IsString()
  @MinLength(1)
  @MaxLength(500)
  content: string;
}

export class PhotoQueryDto {
  @ApiProperty({ required: false })
  @IsUUID()
  @IsOptional()
  childId?: string;

  @ApiProperty({ required: false, default: 1 })
  @IsInt()
  @IsOptional()
  @Min(1)
  page?: number = 1;

  @ApiProperty({ required: false, default: 30 })
  @IsInt()
  @IsOptional()
  @Min(1)
  limit?: number = 30;
}
