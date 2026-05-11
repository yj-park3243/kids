import {
  Injectable,
  NestInterceptor,
  ExecutionContext,
  CallHandler,
  Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Observable } from 'rxjs';
import { tap } from 'rxjs/operators';
import { User } from '../../user/entities/user.entity';
import { UserVisit } from '../../user/entities/user-visit.entity';

/**
 * 인증된 요청에 대해 lastSeenAt + user_visit 갱신.
 * - lastSeenAt은 1분에 1회만 UPDATE (over-write 부하 줄이기)
 * - user_visit은 ON CONFLICT DO NOTHING (하루 1회만 의미)
 */
@Injectable()
export class ActivityTrackerInterceptor implements NestInterceptor {
  private readonly logger = new Logger(ActivityTrackerInterceptor.name);
  // 메모리 캐시: userId → 마지막으로 DB 갱신한 시각 (ms)
  private readonly recentTouches = new Map<string, number>();
  private static readonly TOUCH_INTERVAL_MS = 60 * 1000; // 1분

  constructor(
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    @InjectRepository(UserVisit)
    private readonly visitRepo: Repository<UserVisit>,
  ) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const req = context.switchToHttp().getRequest();
    const userId: string | undefined = req.user?.id;

    if (userId) {
      this.touch(userId).catch((err) => {
        this.logger.warn(`activity touch failed: ${err?.message}`);
      });
    }

    return next.handle().pipe(tap(() => undefined));
  }

  private async touch(userId: string): Promise<void> {
    const now = Date.now();
    const last = this.recentTouches.get(userId) ?? 0;
    if (now - last < ActivityTrackerInterceptor.TOUCH_INTERVAL_MS) return;
    this.recentTouches.set(userId, now);

    // 메모리 캐시 cleanup (10분 이상 된 항목)
    if (this.recentTouches.size > 1000) {
      const cutoff = now - 10 * 60 * 1000;
      for (const [k, v] of this.recentTouches.entries()) {
        if (v < cutoff) this.recentTouches.delete(k);
      }
    }

    const today = new Date().toISOString().slice(0, 10);

    await Promise.all([
      this.userRepo.update(userId, { lastSeenAt: new Date() }),
      this.visitRepo.query(
        `INSERT INTO user_visit (user_id, visit_date) VALUES ($1, $2)
         ON CONFLICT (user_id, visit_date) DO NOTHING`,
        [userId, today],
      ),
    ]);
  }
}
