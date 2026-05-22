import { Controller, Get, Query, Req } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiQuery } from '@nestjs/swagger';
import { JwtService } from '@nestjs/jwt';
import { Public } from '../common/decorators/public.decorator';
import { VersionService } from './version.service';

@ApiTags('version')
@Controller('app-version')
export class VersionController {
  constructor(
    private readonly versionService: VersionService,
    private readonly jwtService: JwtService,
  ) {}

  // 앱 시작 시 부트스트랩 — 버전 정보/핸드폰 인증 우회 여부를 반환하고,
  // 요청에 실린 플랫폼/앱 버전/위치를 호출 로그로 남긴다. 인증은 선택.
  @Public()
  @Get()
  @ApiOperation({ summary: '앱 버전/강제 업데이트 정보 조회 (부트스트랩)' })
  @ApiQuery({ name: 'platform', enum: ['IOS', 'ANDROID'], required: true })
  @ApiQuery({ name: 'appVersion', required: false })
  @ApiQuery({ name: 'lat', required: false })
  @ApiQuery({ name: 'lng', required: false })
  async getAppVersion(
    @Query('platform') platform: string,
    @Req() req: any,
    @Query('appVersion') appVersion?: string,
    @Query('lat') lat?: string,
    @Query('lng') lng?: string,
  ) {
    const info = await this.versionService.getVersionInfo(platform);

    // ─── 부트스트랩 호출 로그 (위치 포함) — 실패해도 응답엔 영향 없음 ──
    const latNum = lat != null ? Number(lat) : NaN;
    const lngNum = lng != null ? Number(lng) : NaN;
    void this.versionService.logVersionCheck({
      userId: this.extractUserId(req),
      platform: (platform || '').toUpperCase(),
      appVersion: appVersion ?? null,
      latitude: Number.isFinite(latNum) ? latNum : null,
      longitude: Number.isFinite(lngNum) ? lngNum : null,
      ipAddress: req.ip ?? null,
    });

    return info;
  }

  // Authorization 헤더가 있으면 userId 추출, 없거나 무효하면 null.
  private extractUserId(req: any): string | null {
    const auth: string | undefined = req.headers?.authorization;
    if (!auth?.startsWith('Bearer ')) return null;
    try {
      const payload = this.jwtService.verify<{ sub: string; type?: string }>(
        auth.slice(7),
        { issuer: 'kids-app' },
      );
      if (!payload.type || payload.type === 'access') {
        return payload.sub;
      }
    } catch {
      // 토큰 무효 — 익명 처리
    }
    return null;
  }
}
