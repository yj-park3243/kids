import {
  Injectable,
  ForbiddenException,
  NotFoundException,
  Inject,
  forwardRef,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ChatMessage, ChatMessageType } from './entities/chat-message.entity';
import { Room } from '../room/entities/room.entity';
import { RoomMember } from '../room/entities/room-member.entity';
import { User } from '../user/entities/user.entity';
import { ChatGateway } from './chat.gateway';
import { ProfanityFilterService } from '../common/services/profanity-filter.service';

export interface ChatMessageView {
  id: string;
  roomId: string;
  senderId: string | null;
  senderNickname: string;
  content: string;
  type: ChatMessageType;
  createdAt: Date;
  unreadCount: number;
}

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
    @Inject(forwardRef(() => ChatGateway))
    private chatGateway: ChatGateway,
    private profanityFilter: ProfanityFilterService,
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

  /**
   * "본인을 제외한 멤버 중 lastReadAt이 createdAt 이전(또는 NULL)인 사람 수".
   * sender 본인은 자동 읽음으로 처리해 카운트에서 제외한다.
   */
  private computeUnreadCount(
    message: Pick<ChatMessage, 'senderId' | 'createdAt'>,
    members: RoomMember[],
  ): number {
    let count = 0;
    for (const m of members) {
      if (message.senderId && m.userId === message.senderId) continue;
      if (m.lastReadAt == null || m.lastReadAt < message.createdAt) count++;
    }
    return count;
  }

  private toView(msg: ChatMessage, unreadCount: number): ChatMessageView {
    return {
      id: msg.id,
      roomId: msg.roomId,
      senderId: msg.senderId,
      senderNickname: msg.senderNickname,
      content: msg.content,
      type: msg.type,
      createdAt: msg.createdAt,
      unreadCount,
    };
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
    if (roomIds.length === 0) return [];

    const lastMessages = await this.chatMessageRepository
      .createQueryBuilder('m')
      .where('m.roomId IN (:...roomIds)', { roomIds })
      .orderBy('m.createdAt', 'DESC')
      .getMany();
    const lastByRoom = new Map<string, ChatMessage>();
    for (const m of lastMessages) {
      if (!lastByRoom.has(m.roomId)) lastByRoom.set(m.roomId, m);
    }

    // 내 멤버 행만 모아서 lastReadAt 확인 후 unread 메시지 수 카운트.
    const myMembers = await this.roomMemberRepository.find({
      where: roomIds.map((roomId) => ({ roomId, userId })),
    });
    const myMemberByRoom = new Map<string, RoomMember>();
    for (const mm of myMembers) myMemberByRoom.set(mm.roomId, mm);

    const unreadRows = await this.chatMessageRepository
      .createQueryBuilder('m')
      .select('m.roomId', 'roomId')
      .addSelect('COUNT(*)', 'count')
      .where('m.roomId IN (:...roomIds)', { roomIds })
      .andWhere('m.senderId <> :userId OR m.senderId IS NULL', { userId })
      .andWhere(
        // 멤버가 있고 lastReadAt이 있으면 그 시점 이후만, 없으면 전체.
        `(
          SELECT COALESCE(rm.last_read_at, 'epoch'::timestamp)
          FROM room_member rm
          WHERE rm.room_id = m.room_id AND rm.user_id = :userId
          LIMIT 1
        ) < m.created_at`,
        { userId },
      )
      .groupBy('m.roomId')
      .getRawMany<{ roomId: string; count: string }>();
    const unreadByRoom = new Map<string, number>();
    for (const r of unreadRows) unreadByRoom.set(r.roomId, Number(r.count));

    return rows.map((room) => {
      const last = lastByRoom.get(room.id);
      return {
        id: room.id,
        roomId: room.id,
        roomTitle: room.title,
        lastMessage: last?.content ?? null,
        lastMessageAt: last?.createdAt ?? null,
        unreadCount: unreadByRoom.get(room.id) ?? 0,
      };
    });
  }

  async listMessages(
    roomId: string,
    userId: string,
    opts: { cursor?: string; limit?: number } = {},
  ): Promise<{ items: ChatMessageView[]; nextCursor: string | null; hasMore: boolean }> {
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

    const members = await this.roomMemberRepository.find({ where: { roomId } });
    const views = items.map((msg) =>
      this.toView(msg, this.computeUnreadCount(msg, members)),
    );

    return { items: views, nextCursor, hasMore };
  }

  async sendUserMessage(
    roomId: string,
    userId: string,
    content: string,
    type: ChatMessageType = 'TEXT',
  ): Promise<ChatMessageView> {
    await this.ensureMembership(roomId, userId);
    const trimmed = content.trim();
    if (!trimmed) {
      throw new ForbiddenException('빈 메시지는 보낼 수 없습니다.');
    }

    // Apple Guideline 1.2: UGC 자동 필터.
    this.profanityFilter.assertClean(trimmed, '메시지');

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

    // sender 본인은 자기 메시지를 곧바로 읽은 것으로 처리.
    await this.roomMemberRepository.update(
      { roomId, userId },
      { lastReadAt: saved.createdAt },
    );

    await this.roomRepository.update(roomId, { updatedAt: new Date() });

    const members = await this.roomMemberRepository.find({ where: { roomId } });
    const view = this.toView(saved, this.computeUnreadCount(saved, members));
    this.chatGateway.broadcastMessage(roomId, view);
    return view;
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
    const members = await this.roomMemberRepository.find({ where: { roomId } });
    const view = this.toView(saved, this.computeUnreadCount(saved, members));
    this.chatGateway.broadcastMessage(roomId, view);
  }

  /**
   * Mark all messages in the room as read for this user up to `asOf` (defaults to now).
   * Broadcasts a `read` event so other clients can decrement their badge counters.
   */
  async markRoomRead(
    roomId: string,
    userId: string,
    asOfIso?: string,
  ): Promise<{ lastReadAt: string }> {
    await this.ensureMembership(roomId, userId);
    const asOf = asOfIso ? new Date(asOfIso) : new Date();
    await this.roomMemberRepository.update(
      { roomId, userId },
      { lastReadAt: asOf },
    );
    this.chatGateway.broadcastRead(roomId, userId, asOf);
    return { lastReadAt: asOf.toISOString() };
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
