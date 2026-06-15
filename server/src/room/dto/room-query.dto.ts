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

  @ApiProperty({ required: false, enum: ['ALL', 'MOM_ONLY', 'DAD_ONLY'] })
  @IsString()
  @IsOptional()
  genderFilter?: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @Transform(({ value }) => value === 'true' || value === true)
  singleParentOnly?: boolean;

  @ApiProperty({ required: false })
  @IsOptional()
  @Transform(({ value }) => value === 'true' || value === true)
  parentAgeMatch?: boolean;

  @ApiProperty({ required: false })
  @IsOptional()
  @Transform(({ value }) => value === 'true' || value === true)
  isFlashMeeting?: boolean;

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
  // 뷰포트 제한은 선택. 빠지면 "전국 모든 활성 방"을 반환한다 — 클라이언트가
  // 지도 화면에서 줌/팬 해도 별도 재조회 없이 전체 핀을 한 번에 다룰 수 있게.
  @ApiProperty({ required: false })
  @IsNumber()
  @IsOptional()
  swLat?: number;

  @ApiProperty({ required: false })
  @IsNumber()
  @IsOptional()
  swLng?: number;

  @ApiProperty({ required: false })
  @IsNumber()
  @IsOptional()
  neLat?: number;

  @ApiProperty({ required: false })
  @IsNumber()
  @IsOptional()
  neLng?: number;

  @ApiProperty({ required: false })
  @IsInt()
  @IsOptional()
  ageMonth?: number;

  @ApiProperty({ required: false })
  @IsInt()
  @IsOptional()
  zoomLevel?: number;

  // ─── 필터 (방 목록 RoomQueryDto 와 동일 체계) ───────────────────
  @ApiProperty({ required: false, description: '모임 날짜 하한 YYYY-MM-DD' })
  @IsString()
  @IsOptional()
  dateFrom?: string;

  @ApiProperty({ required: false, description: '모임 날짜 상한 YYYY-MM-DD' })
  @IsString()
  @IsOptional()
  dateTo?: string;

  @ApiProperty({ required: false, description: '시작 시간 하한 HH:mm' })
  @IsString()
  @IsOptional()
  startTimeFrom?: string;

  @ApiProperty({ required: false, description: '시작 시간 상한 HH:mm' })
  @IsString()
  @IsOptional()
  startTimeTo?: string;

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

  @ApiProperty({ required: false, enum: ['ALL', 'MOM_ONLY', 'DAD_ONLY'] })
  @IsString()
  @IsOptional()
  genderFilter?: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @Transform(({ value }) => value === 'true' || value === true)
  singleParentOnly?: boolean;

  @ApiProperty({ required: false })
  @IsOptional()
  @Transform(({ value }) => value === 'true' || value === true)
  parentAgeMatch?: boolean;

  @ApiProperty({ required: false })
  @IsOptional()
  @Transform(({ value }) => value === 'true' || value === true)
  isFlashMeeting?: boolean;
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
