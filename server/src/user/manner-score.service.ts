import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from './entities/user.entity';

// user.entity 의 manner_score 기본값(20, 떡잎 중간)과 반드시 같아야 한다.
// 기준이 다르면 첫 재계산(후기/신고/노쇼) 때 점수가 기준선으로 점프해 벌점이 승급으로 둔갑한다.
const BASE = 20;
const MIN = 0;
const MAX = 99.9;

function scoreDelta(score: number): number {
  switch (score) {
    case 5: return 0.5;
    case 4: return 0.2;
    case 3: return 0;
    case 2: return -0.2;
    case 1: return -0.5;
    default: return 0;
  }
}

// 매너 온도 통합 재계산. 단일 진입점.
// 20 기준 + Σ scoreDelta(review.score) − confirmedReports × 1.0 − noShowCount × 0.3
// scoreDelta: 5→+0.5, 4→+0.2, 3→0, 2→-0.2, 1→-0.5 (docs/02 §8.3)
@Injectable()
export class MannerScoreService {
  private readonly logger = new Logger(MannerScoreService.name);

  constructor(
    @InjectRepository(User)
    private userRepository: Repository<User>,
  ) {}

  async recalc(targetUserId: string): Promise<number> {
    const user = await this.userRepository.findOne({ where: { id: targetUserId } });
    if (!user) return BASE;

    let reviewDelta = 0;
    try {
      const rows = await this.userRepository.query(
        `SELECT score FROM review WHERE target_user_id = $1`,
        [targetUserId],
      );
      for (const r of rows as { score: number }[]) {
        reviewDelta += scoreDelta(Number(r.score));
      }
    } catch {
      reviewDelta = 0;
    }

    let confirmedReports = 0;
    try {
      const rows = await this.userRepository.query(
        `SELECT COUNT(*)::int AS c FROM report
         WHERE status = 'RESOLVED'
           AND ((target_type = 'USER' AND target_id = $1)
             OR (target_type = 'ROOM' AND target_id IN (SELECT id FROM room WHERE host_id = $1)))`,
        [targetUserId],
      );
      confirmedReports = rows[0]?.c ?? 0;
    } catch {
      confirmedReports = 0;
    }

    const noShowPenalty = Number(user.noShowCount ?? 0) * 0.3;
    let next = BASE + reviewDelta - confirmedReports * 1.0 - noShowPenalty;
    if (next < MIN) next = MIN;
    if (next > MAX) next = MAX;

    const rounded = Math.round(next * 10) / 10;
    user.mannerScore = rounded;
    await this.userRepository.save(user);
    return rounded;
  }
}
