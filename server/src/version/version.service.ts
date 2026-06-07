import {
  Injectable,
  Logger,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as http from 'node:http';
import { AppVersion } from './entities/app-version.entity';
import { AppVersionCheckLog } from './entities/app-version-check-log.entity';
import { User } from '../user/entities/user.entity';
import {
  TelegramService,
  escapeHtml,
} from '../common/services/telegram.service';
import { UpdateVersionDto } from './dto/update-version.dto';

export interface VersionInfo {
  minVersion: string;
  latestVersion: string;
  latestBuild: number;
  forceUpdate: boolean;
  updateMessage: string | null;
  storeUrl: string | null;
  bypassPhoneVerification: boolean;
  showAd: boolean;
}

export interface VersionCheckLogInput {
  userId: string | null;
  platform: string;
  appVersion: string | null;
  latitude: number | null;
  longitude: number | null;
  ipAddress: string | null;
  userAgent: string | null;
}

export interface CheckLogQuery {
  page: number;
  pageSize: number;
  platform?: string;
  userId?: string;
  hasLocation?: boolean;
}

@Injectable()
export class VersionService {
  private readonly logger = new Logger(VersionService.name);

  // redis 없이 단일 인스턴스 가정 — IP→지역 24h 캐시, 앱 접속 알림 1h throttle.
  private readonly ipCache = new Map<
    string,
    { value: string | null; expiresAt: number }
  >();
  private readonly notifyThrottle = new Map<string, number>();
  private readonly IP_CACHE_TTL_MS = 24 * 60 * 60 * 1000;
  private readonly NOTIFY_TTL_MS = 60 * 60 * 1000;

  constructor(
    @InjectRepository(AppVersion)
    private readonly appVersionRepository: Repository<AppVersion>,
    @InjectRepository(AppVersionCheckLog)
    private readonly versionCheckLogRepository: Repository<AppVersionCheckLog>,
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    private readonly telegramService: TelegramService,
  ) {}

  async getVersionInfo(platform: string): Promise<VersionInfo> {
    const normalized = (platform || '').toUpperCase();
    const record = await this.appVersionRepository.findOne({
      where: { platform: normalized },
    });

    if (record) {
      return {
        minVersion: record.minVersion,
        latestVersion: record.latestVersion,
        latestBuild: record.latestBuild,
        forceUpdate: record.forceUpdate,
        updateMessage: record.updateMessage,
        storeUrl: record.storeUrl,
        bypassPhoneVerification: record.bypassPhoneVerification,
        showAd: record.showAd,
      };
    }

    // 해당 platform 레코드가 없으면 — 강제 업데이트 없음, 광고는 켜둠(기존 동작).
    return {
      minVersion: '1.0.0',
      latestVersion: '1.0.0',
      latestBuild: 1,
      forceUpdate: false,
      updateMessage: null,
      storeUrl: null,
      bypassPhoneVerification: false,
      showAd: true,
    };
  }

  /**
   * 가입 시점에 KCP 본인인증을 우회할지 판단. platform row 중 하나라도 true 면 우회.
   */
  async isPhoneVerificationBypassed(): Promise<boolean> {
    const count = await this.appVersionRepository.count({
      where: { bypassPhoneVerification: true },
    });
    return count > 0;
  }

  /**
   * 앱 부트스트랩(/app-version) 호출 로그 저장. userId 가 있으면 사용자 정보(닉네임/이메일/
   * 핸드폰)를, IP 가 있으면 지역 문자열을 함께 채운다. 통계/추적용이라 실패해도 응답엔 영향 없음.
   */
  async logVersionCheck(input: VersionCheckLogInput): Promise<void> {
    try {
      let nickname: string | null = null;
      let email: string | null = null;
      let phoneNumber: string | null = null;
      if (input.userId) {
        const user = await this.userRepository.findOne({
          where: { id: input.userId },
          select: { id: true, nickname: true, email: true, phoneNumber: true },
        });
        if (user) {
          nickname = user.nickname ?? null;
          email = user.email ?? null;
          phoneNumber = user.phoneNumber ?? null;
        }
      }

      const ipLocation = await this.lookupIpLocation(input.ipAddress);

      await this.versionCheckLogRepository.insert({
        userId: input.userId,
        nickname,
        email,
        phoneNumber,
        platform: input.platform,
        appVersion: input.appVersion,
        latitude: input.latitude,
        longitude: input.longitude,
        ipAddress: input.ipAddress,
        ipLocation,
        userAgent: input.userAgent,
      });
    } catch (e) {
      this.logger.warn(`버전 체크 로그 저장 실패: ${(e as Error).message}`);
    }
  }

  /**
   * 앱 접속(버전 체크) 텔레그램 알림 — 같은 user(또는 IP)당 1시간 1회. 실패해도 무시.
   */
  async notifyAppOpen(
    userId: string | null,
    platform: string,
    ipAddress: string | null,
  ): Promise<void> {
    try {
      const key = userId ? `u:${userId}` : `ip:${ipAddress ?? 'unknown'}`;
      const now = Date.now();
      const exp = this.notifyThrottle.get(key);
      if (exp && exp > now) return; // 이미 1시간 내 알림 발송됨
      this.notifyThrottle.set(key, now + this.NOTIFY_TTL_MS);

      let who: string;
      if (userId) {
        const user = await this.userRepository.findOne({
          where: { id: userId },
          select: { id: true, nickname: true },
        });
        who = `${escapeHtml(user?.nickname ?? '-')} <code>${escapeHtml(userId)}</code>`;
      } else {
        who = `익명 (IP <code>${escapeHtml(ipAddress ?? '-')}</code>)`;
      }

      const location = await this.lookupIpLocation(ipAddress);
      const locationLine = location ? `\n• 위치: ${escapeHtml(location)}` : '';

      void this.telegramService.sendAdminAlert(
        `📲 <b>앱 접속</b>\n• ${who}\n• 플랫폼: ${escapeHtml(platform)}${locationLine}`,
      );
    } catch (e) {
      this.logger.warn(`앱 접속 알림 실패: ${(e as Error).message}`);
    }
  }

  // ─────────────────────────────────────
  // Admin
  // ─────────────────────────────────────
  async listVersions(): Promise<AppVersion[]> {
    return this.appVersionRepository.find({ order: { platform: 'ASC' } });
  }

  async updateVersion(id: string, dto: UpdateVersionDto): Promise<AppVersion> {
    const record = await this.appVersionRepository.findOne({ where: { id } });
    if (!record) {
      throw new NotFoundException('버전 정보를 찾을 수 없습니다.');
    }

    const updates: Partial<AppVersion> = {};
    if (dto.minVersion !== undefined) {
      if (!/^\d+\.\d+\.\d+$/.test(dto.minVersion)) {
        throw new BadRequestException('minVersion은 x.y.z 형식이어야 합니다.');
      }
      updates.minVersion = dto.minVersion;
    }
    if (dto.latestVersion !== undefined) {
      if (!/^\d+\.\d+\.\d+$/.test(dto.latestVersion)) {
        throw new BadRequestException('latestVersion은 x.y.z 형식이어야 합니다.');
      }
      updates.latestVersion = dto.latestVersion;
    }
    if (dto.latestBuild !== undefined) {
      if (!Number.isInteger(dto.latestBuild) || dto.latestBuild < 1) {
        throw new BadRequestException('latestBuild는 1 이상의 정수여야 합니다.');
      }
      updates.latestBuild = dto.latestBuild;
    }
    if (dto.forceUpdate !== undefined) updates.forceUpdate = dto.forceUpdate;
    if (dto.updateMessage !== undefined)
      updates.updateMessage = dto.updateMessage;
    if (dto.storeUrl !== undefined) updates.storeUrl = dto.storeUrl;
    if (dto.showAd !== undefined) updates.showAd = dto.showAd;
    if (dto.bypassPhoneVerification !== undefined)
      updates.bypassPhoneVerification = dto.bypassPhoneVerification;

    if (Object.keys(updates).length === 0) {
      throw new BadRequestException('수정할 필드가 없습니다.');
    }

    await this.appVersionRepository.update(id, updates);
    return (await this.appVersionRepository.findOne({ where: { id } }))!;
  }

  async getCheckLogs(query: CheckLogQuery): Promise<{
    data: AppVersionCheckLog[];
    total: number;
    page: number;
    pageSize: number;
  }> {
    const page = query.page >= 1 ? query.page : 1;
    const pageSize = Math.min(Math.max(query.pageSize, 1), 200);

    const qb = this.versionCheckLogRepository
      .createQueryBuilder('log')
      .orderBy('log.createdAt', 'DESC');

    if (query.platform) {
      qb.andWhere('log.platform = :platform', {
        platform: query.platform.toUpperCase(),
      });
    }
    if (query.userId) {
      qb.andWhere('log.userId = :userId', { userId: query.userId });
    }
    if (query.hasLocation === true) {
      qb.andWhere('log.latitude IS NOT NULL AND log.longitude IS NOT NULL');
    } else if (query.hasLocation === false) {
      qb.andWhere('(log.latitude IS NULL OR log.longitude IS NULL)');
    }

    const total = await qb.getCount();
    const data = await qb
      .skip((page - 1) * pageSize)
      .take(pageSize)
      .getMany();

    return { data, total, page, pageSize };
  }

  // ─────────────────────────────────────
  // IP → 지역 문자열 (ip-api.com, 인메모리 24h 캐시). 실패/사설IP는 null.
  // ─────────────────────────────────────
  private async lookupIpLocation(
    ip: string | null | undefined,
  ): Promise<string | null> {
    if (!ip) return null;
    if (
      ip === '127.0.0.1' ||
      ip === '::1' ||
      ip.startsWith('10.') ||
      ip.startsWith('192.168.') ||
      /^172\.(1[6-9]|2\d|3[01])\./.test(ip) ||
      ip.startsWith('fe80:') ||
      ip.startsWith('fc') ||
      ip.startsWith('fd')
    ) {
      return null;
    }

    const cached = this.ipCache.get(ip);
    if (cached && cached.expiresAt > Date.now()) return cached.value;

    const result = await this.fetchIpLocation(ip);
    this.ipCache.set(ip, {
      value: result,
      expiresAt: Date.now() + this.IP_CACHE_TTL_MS,
    });
    return result;
  }

  private fetchIpLocation(ip: string): Promise<string | null> {
    // ip-api.com — 무료 HTTP, lang=ko. EC2 IPv6 미지원 → family:4 강제.
    return new Promise((resolve) => {
      const req = http.get(
        `http://ip-api.com/json/${encodeURIComponent(ip)}?fields=status,country,regionName,city,isp&lang=ko`,
        { family: 4, timeout: 3000 },
        (res) => {
          let data = '';
          res.on('data', (chunk) => (data += chunk));
          res.on('end', () => {
            try {
              const json = JSON.parse(data) as {
                status?: string;
                country?: string;
                regionName?: string;
                city?: string;
                isp?: string;
              };
              if (json.status === 'success') {
                const region = [json.country, json.regionName, json.city]
                  .filter(Boolean)
                  .join(' ');
                resolve((json.isp ? `${region} (${json.isp})` : region) || null);
              } else {
                resolve(null);
              }
            } catch {
              resolve(null);
            }
          });
        },
      );
      req.on('error', () => resolve(null));
      req.on('timeout', () => {
        req.destroy();
        resolve(null);
      });
    });
  }
}
