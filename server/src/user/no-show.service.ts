import { Inject, Injectable, Logger, forwardRef } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { LessThanOrEqual, Repository } from 'typeorm';
import { Cron } from '@nestjs/schedule';
import { User } from './entities/user.entity';
import { NotificationService } from '../notification/notification.service';
import { MannerScoreService } from './manner-score.service';

const RESTRICT_THRESHOLD = 3;
const PERMANENT_THRESHOLD = 5;
const RESTRICT_DAYS = 7;
const FAR_FUTURE_YEARS = 100;

@Injectable()
export class NoShowService {
  private readonly logger = new Logger(NoShowService.name);

  constructor(
    @InjectRepository(User)
    private userRepository: Repository<User>,
    @Inject(forwardRef(() => NotificationService))
    private notificationService: NotificationService,
    private mannerScoreService: MannerScoreService,
  ) {}

  // 시작 24시간 이내 본인 취소 → +0.5
  async incrementForCancellation(userId: string, hoursBeforeStart: number) {
    if (hoursBeforeStart >= 24) return;
    await this.bump(userId, 0.5);
    await this.applyRestriction(userId);
  }

  // 방장 출석체크 결과 불참 → +1.0
  async incrementForAbsence(userId: string) {
    await this.bump(userId, 1.0);
    await this.applyRestriction(userId);
  }

  async applyRestriction(userId: string) {
    const user = await this.userRepository.findOne({ where: { id: userId } });
    if (!user) return;
    const count = Number(user.noShowCount ?? 0);

    if (count >= PERMANENT_THRESHOLD) {
      const far = new Date();
      far.setFullYear(far.getFullYear() + FAR_FUTURE_YEARS);
      user.canJoinAt = far;
      await this.userRepository.save(user);
    } else if (count >= RESTRICT_THRESHOLD) {
      const until = new Date();
      until.setDate(until.getDate() + RESTRICT_DAYS);
      user.canJoinAt = until;
      await this.userRepository.save(user);
    }

    // NOSHOW_WARNING 푸시 — 카운트 변동마다 1회 발송 (운영 정책 검토 포인트)
    try {
      await this.notificationService.create({
        userId,
        type: 'NOSHOW_WARNING',
        title: '노쇼 경고',
        body: `노쇼 ${count.toFixed(1)}회 누적되었어요. 누적 3회부터 참여가 제한됩니다.`,
        data: { noShowCount: count },
      });
    } catch (e) {
      this.logger.warn(`failed to send NOSHOW_WARNING for ${userId}: ${(e as Error).message}`);
    }
  }

  // 매일 새벽 4시 — canJoinAt 만료 유저의 제한 해제 (count 는 유지)
  @Cron('0 0 4 * * *')
  async releaseExpired() {
    const now = new Date();
    const expired = await this.userRepository.find({
      where: { canJoinAt: LessThanOrEqual(now) },
    });
    for (const u of expired) {
      // 영구 제한(100년 뒤)은 release 대상이 아니므로 자동 제외됨 (now 보다 미래라 조회 안 됨)
      u.canJoinAt = null as unknown as Date;
      await this.userRepository.save(u);
      this.logger.log(`released noshow restriction for user=${u.id}`);
    }
  }

  private async bump(userId: string, delta: number) {
    const user = await this.userRepository.findOne({ where: { id: userId } });
    if (!user) return;
    const next = Math.round((Number(user.noShowCount ?? 0) + delta) * 10) / 10;
    user.noShowCount = next;
    await this.userRepository.save(user);

    try {
      await this.mannerScoreService.recalc(userId);
    } catch (e) {
      this.logger.warn(`mannerScore recalc failed for ${userId}: ${(e as Error).message}`);
    }
  }
}
