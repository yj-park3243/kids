import {
  IsOptional,
  IsBoolean,
  IsInt,
  Min,
  Matches,
  IsString,
} from 'class-validator';

export class UpdateVersionDto {
  @IsOptional()
  @Matches(/^\d+\.\d+\.\d+$/, { message: 'minVersion은 x.y.z 형식이어야 합니다.' })
  minVersion?: string;

  @IsOptional()
  @Matches(/^\d+\.\d+\.\d+$/, { message: 'latestVersion은 x.y.z 형식이어야 합니다.' })
  latestVersion?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  latestBuild?: number;

  @IsOptional()
  @IsBoolean()
  forceUpdate?: boolean;

  @IsOptional()
  @IsString()
  updateMessage?: string | null;

  @IsOptional()
  @IsString()
  storeUrl?: string | null;

  @IsOptional()
  @IsBoolean()
  showAd?: boolean;

  @IsOptional()
  @IsBoolean()
  bypassPhoneVerification?: boolean;
}
