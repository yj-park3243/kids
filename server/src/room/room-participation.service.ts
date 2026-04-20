import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  ConflictException,
  BadRequestException,
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

@Injectable()
export class RoomParticipationService {
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

      if (room.status !== 'RECRUITING') {
        throw new ForbiddenException({
          code: 'ROOM_NOT_RECRUITING',
          message: '모집 중인 방이 아닙니다.',
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

        // Chat & notifications outside the critical section
        await this.chatService.addMember(room.chatRoomId, userId);
        await this.chatService.sendSystemMessage(
          room.chatRoomId,
          `${user?.nickname || '알 수 없음'}님이 참여했습니다.`,
        );

        await this.notificationService.create({
          userId: room.hostId,
          type: 'JOIN_REQUEST',
          title: '참여 알림',
          body: `${user?.nickname || '알 수 없음'}님이 [${room.title}]에 참여했습니다.`,
          data: { roomId },
        });

        return {
          status: 'ACCEPTED',
          chatRoomId: room.chatRoomId,
        };
      } else {
        // Approval needed
        const joinRequest = manager.getRepository(JoinRequest).create({
          roomId,
          userId,
          status: 'PENDING',
        });
        await manager.getRepository(JoinRequest).save(joinRequest);

        // Notify host
        await this.notificationService.create({
          userId: room.hostId,
          type: 'JOIN_REQUEST',
          title: '참여 신청',
          body: `${user?.nickname || '알 수 없음'}님이 [${room.title}]에 참여를 신청했습니다.`,
          data: { roomId },
        });

        return {
          status: 'PENDING',
        };
      }
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
    return this.dataSource.transaction(async (manager) => {
      // Lock the room to prevent race conditions on ACCEPT
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

        // Add member within transaction
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

        // Chat & notifications
        await this.chatService.addMember(room.chatRoomId, request.userId);
        const user = await this.userRepository.findOne({ where: { id: request.userId } });
        await this.chatService.sendSystemMessage(
          room.chatRoomId,
          `${user?.nickname || '알 수 없음'}님이 참여했습니다.`,
        );

        await this.notificationService.create({
          userId: request.userId,
          type: 'JOIN_ACCEPTED',
          title: '참여 수락',
          body: `[${room.title}] 참여가 수락되었습니다.`,
          data: { roomId, chatRoomId: room.chatRoomId },
        });
      } else if (action === 'REJECT') {
        request.status = 'REJECTED';
        await manager.getRepository(JoinRequest).save(request);

        await this.notificationService.create({
          userId: request.userId,
          type: 'JOIN_REJECTED',
          title: '참여 거절',
          body: `[${room.title}] 참여가 거절되었습니다.`,
          data: { roomId },
        });
      }

      return { success: true };
    });
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
