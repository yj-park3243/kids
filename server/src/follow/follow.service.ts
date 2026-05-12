import {
  Injectable,
  Logger,
  BadRequestException,
  ConflictException,
  ForbiddenException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Follow } from './entities/follow.entity';
import { User } from '../user/entities/user.entity';
import { NotificationService } from '../notification/notification.service';

@Injectable()
export class FollowService {
  private readonly logger = new Logger(FollowService.name);

  constructor(
    @InjectRepository(Follow)
    private followRepository: Repository<Follow>,
    @InjectRepository(User)
    private userRepository: Repository<User>,
    private notificationService: NotificationService,
  ) {}

  async follow(followerId: string, targetUserId: string) {
    if (followerId === targetUserId) {
      throw new BadRequestException('자기 자신은 팔로우할 수 없습니다.');
    }

    // 차단 관계 검증 (block 테이블 직접 raw query — 양방향)
    const blocked = await this.isBlockedEitherDirection(followerId, targetUserId);
    if (blocked) {
      throw new ForbiddenException({ code: 'BLOCKED', message: '차단 관계로 팔로우할 수 없습니다.' });
    }

    const existing = await this.followRepository.findOne({
      where: { followerId, targetUserId },
    });
    if (existing) {
      throw new ConflictException({
        code: 'ALREADY_FOLLOWING',
        message: '이미 팔로우 중입니다.',
      });
    }

    const follow = this.followRepository.create({ followerId, targetUserId });
    return this.followRepository.save(follow);
  }

  async unfollow(followerId: string, targetUserId: string) {
    await this.followRepository.delete({ followerId, targetUserId });
    return { success: true };
  }

  async getMyFollowing(followerId: string) {
    const rows = await this.followRepository
      .createQueryBuilder('f')
      .innerJoin(User, 'u', 'u.id = f.target_user_id')
      .where('f.follower_id = :followerId', { followerId })
      .select([
        'f.target_user_id AS "targetUserId"',
        'u.nickname AS nickname',
        'u.profile_image_url AS "profileImageUrl"',
        'u.region_sigungu AS "regionSigungu"',
        'u.manner_score AS "mannerScore"',
        'f.created_at AS "followedAt"',
      ])
      .orderBy('f.created_at', 'DESC')
      .getRawMany();

    return {
      items: rows.map((r) => ({
        targetUserId: r.targetUserId,
        nickname: r.nickname,
        profileImageUrl: r.profileImageUrl,
        regionSigungu: r.regionSigungu,
        mannerScore: Number(r.mannerScore),
        followedAt: r.followedAt,
      })),
    };
  }

  // 호스트의 팔로워 전원에게 FOLLOW_NEW_ROOM 알림 발송 (Room 생성 후 호출)
  async dispatchFollowNewRoomNotification(roomId: string, hostUserId: string) {
    const followers = await this.followRepository.find({
      where: { targetUserId: hostUserId },
    });

    for (const f of followers) {
      try {
        await this.notificationService.create({
          userId: f.followerId,
          type: 'FOLLOW_NEW_ROOM',
          title: '단골 부모의 새 방',
          body: '팔로우 중인 부모가 새 방을 만들었어요.',
          data: { roomId, hostUserId },
        });
      } catch (e) {
        this.logger.error(
          `Failed to notify follower ${f.followerId} for room ${roomId}`,
          e as Error,
        );
      }
    }
  }

  // block 테이블을 양방향으로 조회. BlockModule 신설 중이라 raw query 로 결합도 최소화.
  private async isBlockedEitherDirection(a: string, b: string): Promise<boolean> {
    try {
      const rows = await this.followRepository.query(
        `SELECT 1 FROM block
         WHERE (blocker_id = $1 AND target_user_id = $2)
            OR (blocker_id = $2 AND target_user_id = $1)
         LIMIT 1`,
        [a, b],
      );
      return rows.length > 0;
    } catch (e) {
      // block 테이블이 아직 동기화되지 않은 환경에서는 차단 검사를 건너뜀
      this.logger.warn(`block table query failed: ${(e as Error).message}`);
      return false;
    }
  }
}
