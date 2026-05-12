import {
  IsString,
  IsInt,
  IsOptional,
  IsEnum,
  IsArray,
  IsBoolean,
  IsNumber,
  Min,
  Max,
  MinLength,
  MaxLength,
  ArrayMaxSize,
} from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export enum PlaceType {
  PLAYGROUND = 'PLAYGROUND',
  KIDS_CAFE = 'KIDS_CAFE',
  PARTY_ROOM = 'PARTY_ROOM',
  PARK = 'PARK',
  OTHER = 'OTHER',
}

export enum JoinType {
  FREE = 'FREE',
  APPROVAL = 'APPROVAL',
}

export enum GenderFilter {
  ALL = 'ALL',
  MOM_ONLY = 'MOM_ONLY',
  DAD_ONLY = 'DAD_ONLY',
}

export class CreateRoomDto {
  @ApiProperty({ example: '역삼동 산책 모임' })
  @IsString()
  @MinLength(2)
  @MaxLength(30)
  title: string;

  @ApiProperty({ example: '역삼동 근처에서 산책하며 아이들 놀릴 분 찾습니다!', required: false })
  @IsString()
  @IsOptional()
  @MaxLength(500)
  description?: string;

  @ApiProperty({ example: '서울특별시' })
  @IsString()
  regionSido: string;

  @ApiProperty({ example: '강남구' })
  @IsString()
  regionSigungu: string;

  @ApiProperty({ example: '역삼동' })
  @IsString()
  regionDong: string;

  @ApiProperty({ example: '2026-04-15' })
  @IsString()
  date: string;

  @ApiProperty({ example: '14:00' })
  @IsString()
  startTime: string;

  @ApiProperty({ required: false, example: '16:00' })
  @IsString()
  @IsOptional()
  endTime?: string;

  @ApiProperty({ example: 6 })
  @IsInt()
  @Min(0)
  @Max(84)
  ageMonthMin: number;

  @ApiProperty({ example: 12 })
  @IsInt()
  @Min(0)
  @Max(84)
  ageMonthMax: number;

  @ApiProperty({ enum: PlaceType })
  @IsEnum(PlaceType)
  placeType: PlaceType;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  placeName?: string;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  placeAddress?: string;

  @ApiProperty({ required: false })
  @IsNumber()
  @IsOptional()
  latitude?: number;

  @ApiProperty({ required: false })
  @IsNumber()
  @IsOptional()
  longitude?: number;

  @ApiProperty({ example: 5 })
  @IsInt()
  @Min(2)
  @Max(10)
  maxMembers: number;

  @ApiProperty({ enum: JoinType })
  @IsEnum(JoinType)
  joinType: JoinType;

  @ApiProperty({ required: false, example: 0 })
  @IsInt()
  @IsOptional()
  @Min(0)
  cost?: number;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  costDescription?: string;

  @ApiProperty({ required: false, example: ['산책', '이유식'] })
  @IsArray()
  @IsOptional()
  @IsString({ each: true })
  @ArrayMaxSize(5)
  tags?: string[];

  @ApiProperty({ enum: GenderFilter, required: false, default: 'ALL' })
  @IsEnum(GenderFilter)
  @IsOptional()
  genderFilter?: GenderFilter;

  @ApiProperty({ required: false, default: false })
  @IsBoolean()
  @IsOptional()
  singleParentOnly?: boolean;

  @ApiProperty({ required: false, default: false })
  @IsBoolean()
  @IsOptional()
  isFlashMeeting?: boolean;

  @ApiProperty({ required: false, example: ['기저귀', '물티슈'] })
  @IsArray()
  @IsOptional()
  @IsString({ each: true })
  @ArrayMaxSize(10)
  @MaxLength(20, { each: true })
  requiredItems?: string[];
}
