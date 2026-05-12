import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AppVersion } from './entities/app-version.entity';

export interface VersionInfo {
  minVersion: string;
  latestVersion: string;
  latestBuild: number;
  forceUpdate: boolean;
  updateMessage: string | null;
  storeUrl: string | null;
  bypassPhoneVerification: boolean;
}

@Injectable()
export class VersionService {
  constructor(
    @InjectRepository(AppVersion)
    private readonly appVersionRepository: Repository<AppVersion>,
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
      };
    }

    // 해당 platform 레코드가 없으면 — 강제 업데이트 없음, 현재 버전이 곧 최신.
    return {
      minVersion: '1.0.0',
      latestVersion: '1.0.0',
      latestBuild: 1,
      forceUpdate: false,
      updateMessage: null,
      storeUrl: null,
      bypassPhoneVerification: false,
    };
  }

  /**
   * 가입 시점에 KCP 본인인증을 우회할지 판단. platform row 중 하나라도 true 면 우회.
   * (관리자가 IOS row만 true 로 켜도 글로벌 우회로 동작 — 심사 모드 해제 시 둘 다 false 로 둘 것)
   */
  async isPhoneVerificationBypassed(): Promise<boolean> {
    const count = await this.appVersionRepository.count({
      where: { bypassPhoneVerification: true },
    });
    return count > 0;
  }
}
