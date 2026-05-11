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
    };
  }
}
