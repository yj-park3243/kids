import { Controller, Get, Query } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiQuery } from '@nestjs/swagger';
import { Public } from '../common/decorators/public.decorator';
import { VersionService } from './version.service';

@ApiTags('version')
@Controller('app-version')
export class VersionController {
  constructor(private readonly versionService: VersionService) {}

  @Public()
  @Get()
  @ApiOperation({ summary: '앱 버전/강제 업데이트 정보 조회' })
  @ApiQuery({ name: 'platform', enum: ['IOS', 'ANDROID'], required: true })
  @ApiQuery({ name: 'appVersion', required: false })
  async getAppVersion(
    @Query('platform') platform: string,
    @Query('appVersion') _appVersion?: string,
  ) {
    return this.versionService.getVersionInfo(platform);
  }
}
