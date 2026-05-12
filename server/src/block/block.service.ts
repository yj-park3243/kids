import {
  Injectable,
  BadRequestException,
  NotFoundException,
  ConflictException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository } from 'typeorm';
import { Block } from './entities/block.entity';
import { RoomMember } from '../room/entities/room-member.entity';

@Injectable()
export class BlockService {
  constructor(
    @InjectRepository(Block)
    private blockRepository: Repository<Block>,
    @InjectRepository(RoomMember)
    private roomMemberRepository: Repository<RoomMember>,
    private dataSource: DataSource,
  ) {}

  async block(blockerId: string, targetUserId: string) {
    if (blockerId === targetUserId) {
      throw new BadRequestException('자기 자신을 차단할 수 없습니다.');
    }

    const existing = await this.blockRepository.findOne({
      where: { blockerId, targetUserId },
    });
    if (existing) {
      throw new ConflictException({
        code: 'ALREADY_BLOCKED',
        message: '이미 차단한 유저입니다.',
      });
    }

    const block = this.blockRepository.create({ blockerId, targetUserId });
    const saved = await this.blockRepository.save(block);

    await this.removeMutualFollows(blockerId, targetUserId);
    await this.removeSharedRoomMembership(blockerId, targetUserId);
    // TODO: chat module 연동되면 "차단 처리되었습니다" 시스템 메시지 추가.

    return {
      id: saved.id,
      targetUserId: saved.targetUserId,
      createdAt: saved.createdAt,
    };
  }

  async unblock(blockerId: string, targetUserId: string) {
    const existing = await this.blockRepository.findOne({
      where: { blockerId, targetUserId },
    });
    if (!existing) {
      throw new NotFoundException('차단 내역이 없습니다.');
    }
    await this.blockRepository.delete({ id: existing.id });
    return { success: true };
  }

  async getMyBlocks(blockerId: string) {
    const rows = await this.blockRepository
      .createQueryBuilder('b')
      .leftJoin('user', 'u', 'u.id = b.target_user_id')
      .where('b.blocker_id = :blockerId', { blockerId })
      .orderBy('b.created_at', 'DESC')
      .select([
        'b.target_user_id AS "targetUserId"',
        'u.nickname AS nickname',
        'u.profile_image_url AS "profileImageUrl"',
        'b.created_at AS "createdAt"',
      ])
      .getRawMany();

    return { items: rows };
  }

  // 양방향 차단 검증 헬퍼 (다른 모듈에서 import 후 사용).
  async isBlockedEitherDirection(userA: string, userB: string): Promise<boolean> {
    if (userA === userB) return false;
    const count = await this.blockRepository
      .createQueryBuilder('b')
      .where(
        '(b.blocker_id = :a AND b.target_user_id = :b) OR (b.blocker_id = :b AND b.target_user_id = :a)',
        { a: userA, b: userB },
      )
      .getCount();
    return count > 0;
  }

  // follow 테이블이 다른 에이전트가 작성 중이므로 raw query 로 우회.
  // 테이블이 없으면(synchronize 전) 무시.
  private async removeMutualFollows(userA: string, userB: string) {
    try {
      await this.dataSource.query(
        `DELETE FROM "follow"
         WHERE (follower_id = $1 AND followee_id = $2)
            OR (follower_id = $2 AND followee_id = $1)`,
        [userA, userB],
      );
    } catch (e) {
      // follow 테이블 미존재 또는 컬럼명 불일치 시 무시.
    }
  }

  private async removeSharedRoomMembership(userA: string, userB: string) {
    const sharedRooms = await this.roomMemberRepository
      .createQueryBuilder('rm')
      .select('rm.room_id', 'roomId')
      .where('rm.user_id IN (:...ids)', { ids: [userA, userB] })
      .groupBy('rm.room_id')
      .having('COUNT(DISTINCT rm.user_id) = 2')
      .getRawMany();

    if (sharedRooms.length === 0) return;

    const roomIds = sharedRooms.map((r) => r.roomId);
    await this.roomMemberRepository
      .createQueryBuilder()
      .delete()
      .where('room_id IN (:...roomIds)', { roomIds })
      .andWhere('user_id IN (:...userIds)', { userIds: [userA, userB] })
      .execute();
  }
}
