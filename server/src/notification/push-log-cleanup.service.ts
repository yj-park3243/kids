import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { InjectRepository } from '@nestjs/typeorm';
import { LessThan, Repository } from 'typeorm';
import { PushLog } from './entities/push-log.entity';

/**
 * 매일 04:00 (서버 시각) — 7일 지난 push_log 행을 삭제한다.
 * 운영 디버깅 용 로그라 길게 들고 있을 필요가 없다.
 */
@Injectable()
export class PushLogCleanupService {
  private readonly logger = new Logger(PushLogCleanupService.name);

  constructor(
    @InjectRepository(PushLog)
    private pushLogRepository: Repository<PushLog>,
  ) {}

  @Cron('0 0 4 * * *')
  async cleanupOldLogs() {
    const cutoff = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
    const result = await this.pushLogRepository.delete({
      createdAt: LessThan(cutoff),
    });
    this.logger.log(
      `push_log 정리 — ${result.affected ?? 0}건 삭제 (cutoff=${cutoff.toISOString()})`,
    );
  }
}
