import { Injectable, ForbiddenException, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { LessThan, Repository } from 'typeorm';
import { ChatMessage, ChatMessageType } from './entities/chat-message.entity';
import { Room } from '../room/entities/room.entity';
import { RoomMember } from '../room/entities/room-member.entity';
import { User } from '../user/entities/user.entity';
import { ChatGateway } from './chat.gateway';

@Injectable()
export class ChatService {
  constructor(
    @InjectRepository(ChatMessage)
    private chatMessageRepository: Repository<ChatMessage>,
    @InjectRepository(Room)
    private roomRepository: Repository<Room>,
    @InjectRepository(RoomMember)
    private roomMemberRepository: Repository<RoomMember>,
    @InjectRepository(User)
    private userRepository: Repository<User>,
    private chatGateway: ChatGateway,
  ) {}

  /**
   * Confirm the user has access to the chat room (host or active member).
   */
  private async ensureMembership(roomId: string, userId: string): Promise<Room> {
    const room = await this.roomRepository.findOne({ where: { id: roomId } });
    if (!room) {
      throw new NotFoundException('채팅방이 존재하지 않습니다.');
    }
    if (room.hostId === userId) return room;

    const member = await this.roomMemberRepository.findOne({
      where: { roomId, userId },
    });
    if (!member) {
      throw new ForbiddenException('채팅방 멤버가 아닙니다.');
    }
    return room;
  }

  async listMyChatRooms(userId: string) {
    const rows = await this.roomRepository
      .createQueryBuilder('room')
      .leftJoin('room.members', 'member')
      .where('room.hostId = :userId OR member.userId = :userId', { userId })
      .andWhere("room.status <> 'CANCELLED'")
      .orderBy('room.updatedAt', 'DESC')
      .getMany();

    const roomIds = rows.map((r) => r.id);
    const lastMessages = roomIds.length
      ? await this.chatMessageRepository
          .createQueryBuilder('m')
          .where('m.roomId IN (:...roomIds)', { roomIds })
          .orderBy('m.createdAt', 'DESC')
          .getMany()
      : [];
    const lastByRoom = new Map<string, ChatMessage>();
    for (const m of lastMessages) {
      if (!lastByRoom.has(m.roomId)) lastByRoom.set(m.roomId, m);
    }

    return rows.map((room) => {
      const last = lastByRoom.get(room.id);
      return {
        id: room.id,
        roomId: room.id,
        roomTitle: room.title,
        lastMessage: last?.content ?? null,
        lastMessageAt: last?.createdAt ?? null,
      };
    });
  }

  async listMessages(
    roomId: string,
    userId: string,
    opts: { cursor?: string; limit?: number } = {},
  ) {
    await this.ensureMembership(roomId, userId);
    const limit = Math.min(opts.limit ?? 50, 100);

    const qb = this.chatMessageRepository
      .createQueryBuilder('m')
      .where('m.roomId = :roomId', { roomId })
      .orderBy('m.createdAt', 'DESC')
      .take(limit + 1);

    if (opts.cursor) {
      qb.andWhere('m.createdAt < :cursor', {
        cursor: new Date(opts.cursor),
      });
    }

    const rows = await qb.getMany();
    const hasMore = rows.length > limit;
    const items = hasMore ? rows.slice(0, limit) : rows;
    const nextCursor =
      hasMore && items.length
        ? items[items.length - 1].createdAt.toISOString()
        : null;

    return { items, nextCursor, hasMore };
  }

  async sendUserMessage(
    roomId: string,
    userId: string,
    content: string,
    type: ChatMessageType = 'TEXT',
  ): Promise<ChatMessage> {
    await this.ensureMembership(roomId, userId);
    const trimmed = content.trim();
    if (!trimmed) {
      throw new ForbiddenException('빈 메시지는 보낼 수 없습니다.');
    }

    const sender = await this.userRepository.findOne({ where: { id: userId } });
    const nickname = sender?.nickname ?? '익명';

    const saved = await this.chatMessageRepository.save(
      this.chatMessageRepository.create({
        roomId,
        senderId: userId,
        senderNickname: nickname,
        content: trimmed,
        type,
      }),
    );

    await this.roomRepository.update(roomId, { updatedAt: new Date() });
    this.chatGateway.broadcastMessage(roomId, saved);
    return saved;
  }

  /**
   * Called by room-participation service for join/leave/kick events.
   */
  async sendSystemMessage(roomId: string, content: string): Promise<void> {
    const saved = await this.chatMessageRepository.save(
      this.chatMessageRepository.create({
        roomId,
        senderId: null,
        senderNickname: '시스템',
        content,
        type: 'SYSTEM',
      }),
    );
    this.chatGateway.broadcastMessage(roomId, saved);
  }

  /**
   * Called from room.service.ts during room creation.
   * With PostgreSQL the room's own id is the chat room id — no separate doc needed.
   * Kept for source compatibility with existing callers.
   */
  async createChatRoom(roomId: string, _hostUserId: string): Promise<string> {
    return roomId;
  }

  async deleteChatRoom(chatRoomId: string): Promise<void> {
    if (!chatRoomId) return;
    await this.chatMessageRepository.delete({ roomId: chatRoomId });
  }

  /**
   * Membership changes are tracked via RoomMember table; these methods remain as
   * hooks so existing callers keep working without changes.
   */
  async addMember(_chatRoomId: string, _userId: string): Promise<void> {
    // No-op for DB-based chat. Membership lives on RoomMember.
  }

  async removeMember(_chatRoomId: string, _userId: string): Promise<void> {
    // No-op for DB-based chat. Membership lives on RoomMember.
  }
}
