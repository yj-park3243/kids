import {
  Injectable,
  Logger,
  NotFoundException,
  ForbiddenException,
  ConflictException,
  BadRequestException,
  Inject,
  forwardRef,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import { Room } from './entities/room.entity';
import { RoomMember } from './entities/room-member.entity';
import { JoinRequest } from './entities/join-request.entity';
import { User } from '../user/entities/user.entity';
import { Child } from '../child/entities/child.entity';
import { ChatService } from '../chat/chat.service';
import { NotificationService } from '../notification/notification.service';
import { BlockService } from '../block/block.service';
import { NoShowService } from '../user/no-show.service';

@Injectable()
export class RoomParticipationService {
  private readonly logger = new Logger(RoomParticipationService.name);

  constructor(
    @InjectRepository(Room)
    private roomRepository: Repository<Room>,
    @InjectRepository(RoomMember)
    private roomMemberRepository: Repository<RoomMember>,
    @InjectRepository(JoinRequest)
    private joinRequestRepository: Repository<JoinRequest>,
    @InjectRepository(User)
    private userRepository: Repository<User>,
    @InjectRepository(Child)
    private childRepository: Repository<Child>,
    private chatService: ChatService,
    private notificationService: NotificationService,
    private dataSource: DataSource,
    @Inject(forwardRef(() => BlockService))
    private blockService: BlockService,
    @Inject(forwardRef(() => NoShowService))
    private noShowService: NoShowService,
  ) {}

  async join(userId: string, roomId: string) {
    return this.dataSource.transaction(async (manager) => {
      // Lock the room row to prevent race conditions
      const room = await manager
        .getRepository(Room)
        .createQueryBuilder('room')
        .setLock('pessimistic_write')
        .where('room.id = :roomId', { roomId })
        .getOne();

      if (!room) {
        throw new NotFoundException('방을 찾을 수 없습니다.');
      }

      const joiningUser = await manager
        .getRepository(User)
        .findOne({ where: { id: userId } });
      if (
        joiningUser?.status === 'SUSPENDED' ||
        joiningUser?.status === 'BANNED'
      ) {
        throw new ForbiddenException({
          code: 'USER_SUSPENDED',
          message:
            '정지된 계정은 모임에 참여할 수 없습니다. 증거 사진을 제출해 정지 해제를 요청해 주세요.',
        });
      }

      if (room.status !== 'RECRUITING') {
        throw new ForbiddenException({
          code: 'ROOM_NOT_RECRUITING',
          message: '모집 중인 방이 아닙니다.',
        });
      }

      // 모임 종료 시각까지만 입장 가능 (종료시간 없으면 당일 자정까지).
      const endAt = new Date(`${room.date}T${room.endTime ?? '23:59'}`);
      if (!Number.isNaN(endAt.getTime()) && Date.now() > endAt.getTime()) {
        throw new ForbiddenException({
          code: 'ROOM_ENDED',
          message: '이미 종료된 모임입니다.',
        });
      }

      if (room.currentMembers >= room.maxMembers) {
        throw new ConflictException({
          code: 'ROOM_FULL',
          message: '인원이 가득 찼습니다.',
        });
      }

      // Check if already joined or requested
      const existingMember = await manager
        .getRepository(RoomMember)
        .findOne({ where: { roomId, userId } });
      if (existingMember) {
        throw new ConflictException({
          code: 'ALREADY_JOINED',
          message: '이미 참여 중입니다.',
        });
      }

      const existingRequest = await manager
        .getRepository(JoinRequest)
        .findOne({ where: { roomId, userId, status: 'PENDING' } });
      if (existingRequest) {
        throw new ConflictException({
          code: 'ALREADY_JOINED',
          message: '이미 참여를 신청했습니다.',
        });
      }

      const user = await this.userRepository.findOne({ where: { id: userId } });
      if (!user) {
        throw new NotFoundException('사용자를 찾을 수 없습니다.');
      }

      // ─── 자격 검증 ───
      // 1. genderFilter
      if (
        (room.genderFilter === 'MOM_ONLY' && user.parentGender !== 'MOM') ||
        (room.genderFilter === 'DAD_ONLY' && user.parentGender !== 'DAD')
      ) {
        throw new ForbiddenException({
          code: 'GENDER_NOT_MATCH',
          message: '방의 성별 조건과 맞지 않습니다.',
        });
      }
      // 2. singleParentOnly
      if (room.singleParentOnly === true && user.isSingleParent !== true) {
        throw new ForbiddenException({
          code: 'SINGLE_PARENT_REQUIRED',
          message: '한부모 가정 전용 방입니다.',
        });
      }
      // 2.5 parentAgeMatch — 방장 만나이 ±5 안의 부모만.
      if (room.parentAgeMatch === true) {
        const host = await this.userRepository.findOne({
          where: { id: room.hostId },
        });
        const calcAge = (bd?: Date | string | null): number | null => {
          if (!bd) return null;
          const b = new Date(bd);
          if (Number.isNaN(b.getTime())) return null;
          const t = new Date();
          let a = t.getFullYear() - b.getFullYear();
          const md = t.getMonth() - b.getMonth();
          if (md < 0 || (md === 0 && t.getDate() < b.getDate())) a--;
          return a;
        };
        const vAge = calcAge(user.birthDate);
        const hAge = calcAge(host?.birthDate);
        if (vAge == null || hAge == null || Math.abs(vAge - hAge) > 5) {
          throw new ForbiddenException({
            code: 'PARENT_AGE_REQUIRED',
            message: '부모 또래(±5세) 전용 방입니다.',
          });
        }
      }
      // 3. 자녀 중 한 명 이상이 ageMonth 범위에 포함
      const myChildren = await this.childRepository.find({ where: { userId } });
      const now = new Date();
      const childAges = myChildren.map(
        (c) => (now.getFullYear() - c.birthYear) * 12 + (now.getMonth() + 1 - c.birthMonth),
      );
      const hasMatchingChild = childAges.some(
        (m) => m >= room.ageMonthMin && m <= room.ageMonthMax,
      );
      if (!hasMatchingChild) {
        throw new ForbiddenException({
          code: 'AGE_NOT_MATCH',
          message: '자녀 개월수가 방의 조건과 맞지 않습니다.',
        });
      }
      // 4. 방장과 차단 관계 양방향
      const blocked = await this.blockService.isBlockedEitherDirection(
        userId,
        room.hostId,
      );
      if (blocked) {
        throw new ForbiddenException({
          code: 'BLOCKED_BY_HOST',
          message: '차단 관계로 참여할 수 없습니다.',
        });
      }
      // 5. 노쇼 제한 중
      if (user.canJoinAt && user.canJoinAt.getTime() > Date.now()) {
        throw new ForbiddenException({
          code: 'NOSHOW_RESTRICTED',
          message: '노쇼 누적으로 참여가 제한되었습니다.',
        });
      }

      if (room.joinType === 'FREE') {
        // Direct join - add member within the transaction
        const member = manager.getRepository(RoomMember).create({
          roomId: room.id,
          userId,
          isHost: false,
        });
        await manager.getRepository(RoomMember).save(member);

        room.currentMembers += 1;
        if (room.currentMembers >= room.maxMembers) {
          room.status = 'CLOSED';
        }
        await manager.getRepository(Room).save(room);

        // Create join request record as ACCEPTED
        const joinRequest = manager.getRepository(JoinRequest).create({
          roomId,
          userId,
          status: 'ACCEPTED',
        });
        await manager.getRepository(JoinRequest).save(joinRequest);

        // 부수 효과(chat/notification)는 트랜잭션 밖에서 fire-and-forget — 외부 호출이
        // hang 해도 join 자체가 막히지 않도록.
        return {
          status: 'ACCEPTED' as const,
          chatRoomId: room.chatRoomId,
          hostId: room.hostId,
          roomTitle: room.title,
          userNickname: user?.nickname ?? '알 수 없음',
        };
      } else {
        // Approval needed
        const joinRequest = manager.getRepository(JoinRequest).create({
          roomId,
          userId,
          status: 'PENDING',
        });
        await manager.getRepository(JoinRequest).save(joinRequest);

        return {
          status: 'PENDING' as const,
          hostId: room.hostId,
          roomTitle: room.title,
          userNickname: user?.nickname ?? '알 수 없음',
        };
      }
    }).then((result) => {
      // 트랜잭션 외부 — fire-and-forget side effects.
      if (result.status === 'ACCEPTED' && 'chatRoomId' in result) {
        void this.chatService
          .sendSystemMessage(
            result.chatRoomId!,
            `${result.userNickname}님이 참여했습니다.`,
          )
          .catch((e) =>
            this.logger.warn(`join chat side-effect 실패: ${e?.message}`),
          );
        void this.notificationService
          .create({
            userId: result.hostId,
            type: 'JOIN_REQUEST',
            title: '참여 알림',
            body: `${result.userNickname}님이 [${result.roomTitle}]에 참여했습니다.`,
            data: { roomId },
          })
          .catch((e) =>
            this.logger.warn(`join notif side-effect 실패: ${e?.message}`),
          );
        return { status: 'ACCEPTED', chatRoomId: result.chatRoomId };
      }
      // PENDING
      void this.notificationService
        .create({
          userId: result.hostId,
          type: 'JOIN_REQUEST',
          title: '참여 신청',
          body: `${result.userNickname}님이 [${result.roomTitle}]에 참여를 신청했습니다.`,
          data: { roomId },
        })
        .catch((e) =>
          this.logger.warn(`join request notif side-effect 실패: ${e?.message}`),
        );
      return { status: 'PENDING' };
    });
  }

  async cancelJoin(userId: string, roomId: string) {
    // Remove from members if exists
    const member = await this.roomMemberRepository.findOne({
      where: { roomId, userId },
    });

    if (member) {
      if (member.isHost) {
        throw new BadRequestException('방장은 참여를 취소할 수 없습니다. 방을 취소해주세요.');
      }

      await this.roomMemberRepository.remove(member);

      // Update current members count
      const room = await this.roomRepository.findOne({ where: { id: roomId } });
      if (room) {
        room.currentMembers = Math.max(0, room.currentMembers - 1);

        // Re-open room if it was CLOSED and now has capacity
        if (room.status === 'CLOSED' && room.currentMembers < room.maxMembers) {
          room.status = 'RECRUITING';
        }

        await this.roomRepository.save(room);

        // 시작 24시간 이내 본인 취소 → 노쇼 +0.5
        const startDt = new Date(`${room.date}T${room.startTime}`);
        const hoursBeforeStart = (startDt.getTime() - Date.now()) / (60 * 60 * 1000);
        void this.noShowService
          .incrementForCancellation(userId, hoursBeforeStart)
          .catch(() => undefined);

        // Remove from chat room
        await this.chatService.removeMember(room.chatRoomId, userId);

        // System message
        const user = await this.userRepository.findOne({ where: { id: userId } });
        await this.chatService.sendSystemMessage(
          room.chatRoomId,
          `${user?.nickname || '알 수 없음'}님이 나갔습니다.`,
        );
      }
    }

    // Cancel pending request
    const request = await this.joinRequestRepository.findOne({
      where: { roomId, userId, status: 'PENDING' },
    });
    if (request) {
      request.status = 'CANCELLED';
      await this.joinRequestRepository.save(request);
    }

    return { success: true };
  }

  async getJoinRequests(userId: string, roomId: string) {
    const room = await this.roomRepository.findOne({ where: { id: roomId } });
    if (!room) {
      throw new NotFoundException('방을 찾을 수 없습니다.');
    }
    if (room.hostId !== userId) {
      throw new ForbiddenException('방장만 조회할 수 있습니다.');
    }

    const requests = await this.joinRequestRepository.find({
      where: { roomId },
      relations: ['user', 'user.children'],
      order: { createdAt: 'DESC' },
    });

    const now = new Date();
    return {
      items: requests.map((req) => ({
        id: req.id,
        user: req.user
          ? {
              id: req.user.id,
              nickname: req.user.nickname,
              profileImageUrl: req.user.profileImageUrl,
              children: req.user.children?.map((c) => ({
                nickname: c.nickname,
                ageMonths:
                  (now.getFullYear() - c.birthYear) * 12 +
                  (now.getMonth() + 1 - c.birthMonth),
                gender: c.gender,
              })),
            }
          : null,
        status: req.status,
        createdAt: req.createdAt,
      })),
    };
  }

  async handleJoinRequest(
    userId: string,
    roomId: string,
    requestId: string,
    action: string,
  ) {
    // 트랜잭션 내부는 DB 변경만. chat/notification 같은 외부 호출은 commit
    // 후로 빼서 ① pg connection 이 외부 I/O 동안 점유되지 않도록 하고,
    // ② 외부 호출이 hang 해도 transaction 의 commit/runner 가 영향 받지
    // 않게 한다. (`join()` 도 같은 패턴.)
    const result = await this.dataSource.transaction(async (manager) => {
      const room = await manager
        .getRepository(Room)
        .createQueryBuilder('room')
        .setLock('pessimistic_write')
        .where('room.id = :roomId', { roomId })
        .getOne();

      if (!room) {
        throw new NotFoundException('방을 찾을 수 없습니다.');
      }
      if (room.hostId !== userId) {
        throw new ForbiddenException('방장만 처리할 수 있습니다.');
      }

      const request = await manager.getRepository(JoinRequest).findOne({
        where: { id: requestId, roomId },
        relations: ['user'],
      });
      if (!request) {
        throw new NotFoundException('신청을 찾을 수 없습니다.');
      }
      if (request.status !== 'PENDING') {
        throw new BadRequestException('이미 처리된 신청입니다.');
      }

      if (action === 'ACCEPT') {
        if (room.currentMembers >= room.maxMembers) {
          throw new ConflictException('인원이 가득 찼습니다.');
        }

        request.status = 'ACCEPTED';
        await manager.getRepository(JoinRequest).save(request);

        const member = manager.getRepository(RoomMember).create({
          roomId: room.id,
          userId: request.userId,
          isHost: false,
        });
        await manager.getRepository(RoomMember).save(member);

        room.currentMembers += 1;
        if (room.currentMembers >= room.maxMembers) {
          room.status = 'CLOSED';
        }
        await manager.getRepository(Room).save(room);

        const user = await manager
          .getRepository(User)
          .findOne({ where: { id: request.userId } });

        return {
          action: 'ACCEPT' as const,
          chatRoomId: room.chatRoomId,
          targetUserId: request.userId,
          targetNickname: user?.nickname ?? '알 수 없음',
          roomTitle: room.title,
        };
      }
      // REJECT
      request.status = 'REJECTED';
      await manager.getRepository(JoinRequest).save(request);

      return {
        action: 'REJECT' as const,
        targetUserId: request.userId,
        roomTitle: room.title,
      };
    });

    // ── 트랜잭션 외부: 외부 사이드이펙트(chat/notification). fire-and-forget
    //    실패해도 사용자 응답은 success — 채팅/알림 누락은 별도 모니터링.
    if (result.action === 'ACCEPT') {
      void this.chatService
        .addMember(result.chatRoomId, result.targetUserId)
        .catch((e) =>
          this.logger.warn(`handleJoinRequest chat addMember 실패: ${e?.message}`),
        );
      void this.chatService
        .sendSystemMessage(
          result.chatRoomId,
          `${result.targetNickname}님이 참여했습니다.`,
        )
        .catch((e) =>
          this.logger.warn(`handleJoinRequest chat sys msg 실패: ${e?.message}`),
        );
      void this.notificationService
        .create({
          userId: result.targetUserId,
          type: 'JOIN_ACCEPTED',
          title: '참여 수락',
          body: `[${result.roomTitle}] 참여가 수락되었습니다.`,
          data: { roomId, chatRoomId: result.chatRoomId },
        })
        .catch((e) =>
          this.logger.warn(`handleJoinRequest notif(ACCEPT) 실패: ${e?.message}`),
        );
    } else {
      void this.notificationService
        .create({
          userId: result.targetUserId,
          type: 'JOIN_REJECTED',
          title: '참여 거절',
          body: `[${result.roomTitle}] 참여가 거절되었습니다.`,
          data: { roomId },
        })
        .catch((e) =>
          this.logger.warn(`handleJoinRequest notif(REJECT) 실패: ${e?.message}`),
        );
    }

    return { success: true };
  }

  async kickMember(hostUserId: string, roomId: string, targetUserId: string) {
    const room = await this.roomRepository.findOne({ where: { id: roomId } });
    if (!room) {
      throw new NotFoundException('방을 찾을 수 없습니다.');
    }
    if (room.hostId !== hostUserId) {
      throw new ForbiddenException('방장만 강퇴할 수 있습니다.');
    }
    if (hostUserId === targetUserId) {
      throw new BadRequestException('자기 자신을 강퇴할 수 없습니다.');
    }

    const member = await this.roomMemberRepository.findOne({
      where: { roomId, userId: targetUserId },
    });
    if (!member) {
      throw new NotFoundException('해당 참여자를 찾을 수 없습니다.');
    }

    await this.roomMemberRepository.remove(member);

    // Update current members
    room.currentMembers = Math.max(0, room.currentMembers - 1);

    // Re-open room if it was CLOSED and now has capacity
    if (room.status === 'CLOSED' && room.currentMembers < room.maxMembers) {
      room.status = 'RECRUITING';
    }

    await this.roomRepository.save(room);

    // Remove from chat room
    await this.chatService.removeMember(room.chatRoomId, targetUserId);

    // System message
    const user = await this.userRepository.findOne({ where: { id: targetUserId } });
    await this.chatService.sendSystemMessage(
      room.chatRoomId,
      `${user?.nickname || '알 수 없음'}님이 내보내졌습니다.`,
    );

    // Notify the kicked user
    await this.notificationService.create({
      userId: targetUserId,
      type: 'ROOM_CANCELLED',
      title: '모임 강퇴',
      body: `[${room.title}] 모임에서 내보내졌습니다.`,
      data: { roomId },
    });

    return { success: true };
  }

  private async addMember(room: Room, userId: string) {
    const member = this.roomMemberRepository.create({
      roomId: room.id,
      userId,
      isHost: false,
    });
    await this.roomMemberRepository.save(member);

    // Update current members
    room.currentMembers += 1;
    await this.roomRepository.save(room);

    // Add to chat room
    await this.chatService.addMember(room.chatRoomId, userId);

    // System message
    const user = await this.userRepository.findOne({ where: { id: userId } });
    await this.chatService.sendSystemMessage(
      room.chatRoomId,
      `${user?.nickname || '알 수 없음'}님이 참여했습니다.`,
    );

    // Auto close if full
    if (room.currentMembers >= room.maxMembers) {
      room.status = 'CLOSED';
      await this.roomRepository.save(room);
    }
  }
}
