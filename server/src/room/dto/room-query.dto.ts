import { IsString, IsInt, IsOptional, IsNumber, IsIn } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';
import { Transform } from 'class-transformer';

export class RoomQueryDto {
  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  regionDong?: string;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  regionSigungu?: string;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  dateFrom?: string;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  dateTo?: string;

  @ApiProperty({ required: false })
  @IsInt()
  @IsOptional()
  ageMonth?: number;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  placeType?: string;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  joinType?: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @Transform(({ value }) => value === 'true' || value === true)
  costFree?: boolean;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  cursor?: string;

  @ApiProperty({ required: false, default: 20 })
  @IsInt()
  @IsOptional()
  limit?: number = 20;
}

export class MapQueryDto {
  @ApiProperty()
  @IsNumber()
  swLat: number;

  @ApiProperty()
  @IsNumber()
  swLng: number;

  @ApiProperty()
  @IsNumber()
  neLat: number;

  @ApiProperty()
  @IsNumber()
  neLng: number;

  @ApiProperty({ required: false })
  @IsInt()
  @IsOptional()
  ageMonth?: number;

  @ApiProperty({ required: false })
  @IsInt()
  @IsOptional()
  zoomLevel?: number;
}

export class MyRoomQueryDto {
  @ApiProperty({ required: false, enum: ['HOSTING', 'JOINED', 'ALL'] })
  @IsString()
  @IsOptional()
  type?: string = 'ALL';

  @ApiProperty({ required: false, enum: ['UPCOMING', 'PAST'] })
  @IsString()
  @IsOptional()
  status?: string = 'UPCOMING';
}

export class JoinActionDto {
  @ApiProperty({ enum: ['ACCEPT', 'REJECT'] })
  @IsIn(['ACCEPT', 'REJECT'])
  action: string;
}
