import {
  Controller,
  Get,
  Patch,
  Param,
  Body,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation } from '@nestjs/swagger';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { AdminGuard } from '../common/guards/admin.guard';
import { VersionService } from './version.service';
import { UpdateVersionDto } from './dto/update-version.dto';

@ApiTags('Admin')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, AdminGuard)
@Controller('admin')
export class VersionAdminController {
  constructor(private readonly versionService: VersionService) {}

  @Get('app-versions')
  @ApiOperation({ summary: '앱 버전 목록 조회 (ADMIN)' })
  async listVersions() {
    return this.versionService.listVersions();
  }

  @Patch('app-versions/:id')
  @ApiOperation({ summary: '앱 버전 정보 수정 (ADMIN)' })
  async updateVersion(
    @Param('id') id: string,
    @Body() dto: UpdateVersionDto,
  ) {
    return this.versionService.updateVersion(id, dto);
  }

  @Get('version-check-logs')
  @ApiOperation({ summary: '앱 버전 체크(접속) 로그 조회 (ADMIN)' })
  async getCheckLogs(
    @Query('page') page?: string,
    @Query('pageSize') pageSize?: string,
    @Query('platform') platform?: string,
    @Query('userId') userId?: string,
    @Query('hasLocation') hasLocation?: string,
  ) {
    return this.versionService.getCheckLogs({
      page: page ? Number(page) : 1,
      pageSize: pageSize ? Number(pageSize) : 50,
      platform: platform || undefined,
      userId: userId || undefined,
      hasLocation:
        hasLocation === 'true'
          ? true
          : hasLocation === 'false'
            ? false
            : undefined,
    });
  }
}
