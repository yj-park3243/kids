import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  ConflictException,
  BadRequestException,
  Inject,
  forwardRef,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, SelectQueryBuilder } from 'typeorm';
import { Room } from './entities/room.entity';
import { RoomMember } from './entities/room-member.entity';
import { JoinRequest } from './entities/join-request.entity';
import { User } from '../user/entities/user.entity';
import { Child } from '../child/entities/child.entity';
import { CreateRoomDto } from './dto/create-room.dto';
import { UpdateRoomDto } from './dto/update-room.dto';
import { RoomQueryDto, MapQueryDto, MyRoomQueryDto } from './dto/room-query.dto';
import { ChatService } from '../chat/chat.service';
import { NotificationService } from '../notification/notification.service';
import { FollowService } from '../follow/follow.service';
import { RoomVisibilityService } from './room-visibility.service';
import {
  TelegramService,
  escapeHtml,
} from '../common/services/telegram.service';
import { GeocodingService } from '../common/services/geocoding.service';
import { ProfanityFilterService } from '../common/services/profanity-filter.service';
import { fallbackCoord } from '../common/services/region-coords';

@Injectable()
export class RoomService {
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
    private telegramService: TelegramService,
    private roomVisibility: RoomVisibilityService,
    private geocodingService: GeocodingService,
    private profanityFilter: ProfanityFilterService,
    @Inject(forwardRef(() => FollowService))
    private followService: FollowService,
  ) {}

  async create(userId: string, dto: CreateRoomDto) {
    const host = await this.userRepository.findOne({ where: { id: userId } });
    if (!host) throw new NotFoundException('사용자를 찾을 수 없습니다.');

    if (host.status === 'SUSPENDED' || host.status === 'BANNED') {
      throw new ForbiddenException({
        code: 'USER_SUSPENDED',
        message:
          '정지된 계정은 모임을 만들 수 없습니다. 증거 사진을 제출해 정지 해제를 요청해 주세요.',
      });
    }

    // 번개 모임 검증: 오늘 + 현재 +1h 이후
    if (dto.isFlashMeeting === true) {
      const today = new Date().toISOString().slice(0, 10);
      if (dto.date !== today) {
        throw new BadRequestException({
          code: 'FLASH_DATE_INVALID',
          message: '번개 모임은 오늘 날짜만 가능합니다.',
        });
      }
      const start = new Date(`${dto.date}T${dto.startTime}`);
      const minStart = new Date(Date.now() + 60 * 60 * 1000);
      if (start.getTime() < minStart.getTime()) {
        throw new BadRequestException({
          code: 'FLASH_START_INVALID',
          message: '번개 모임은 현재 시각 +1시간 이후로만 설정 가능합니다.',
        });
      }
    }

    // 한부모 전용 방은 방장이 한부모일 때만 생성 가능
    if (dto.singleParentOnly === true && host.isSingleParent !== true) {
      throw new ForbiddenException({
        code: 'SINGLE_PARENT_ONLY_REQUIRES_SINGLE_PARENT_HOST',
        message: '한부모 전용 방은 한부모 가정 방장만 생성할 수 있습니다.',
      });
    }

    // requiredItems 길이 검증 — DTO 에서 1차 검증되지만 방어적으로 한 번 더.
    if (dto.requiredItems && dto.requiredItems.length > 10) {
      throw new BadRequestException('준비물은 최대 10개까지 가능합니다.');
    }
    if (dto.requiredItems?.some((it) => (it ?? '').length > 20)) {
      throw new BadRequestException('준비물 각 항목은 20자 이내여야 합니다.');
    }

    // Apple Guideline 1.2: UGC 자동 필터 (제목/설명/준비물).
    this.profanityFilter.assertClean(dto.title, '제목');
    this.profanityFilter.assertClean(dto.description, '설명');
    if (dto.requiredItems) {
      for (const item of dto.requiredItems) {
        this.profanityFilter.assertClean(item, '준비물');
      }
    }

    // 주소 → 좌표 변환 (클라이언트가 좌표를 직접 보낸 경우 우선 사용)
    let latitude = dto.latitude;
    let longitude = dto.longitude;
    if ((latitude == null || longitude == null) && dto.placeAddress) {
      const geo = await this.geocodingService.geocode(dto.placeAddress);
      if (geo) {
        latitude = geo.latitude;
        longitude = geo.longitude;
      }
    }
    // 지오코딩이 실패해도 모임이 반드시 지도에 핀으로 찍히도록,
    // 시군구/동 기반 대략 좌표로 폴백한다.
    if (latitude == null || longitude == null) {
      const fb = fallbackCoord(
        dto.regionSido,
        dto.regionSigungu,
        dto.regionDong,
      );
      latitude = fb.lat;
      longitude = fb.lng;
    }

    // Create room
    const room = this.roomRepository.create({
      hostId: userId,
      ...dto,
      latitude,
      longitude,
      cost: dto.cost || 0,
      status: 'RECRUITING',
      currentMembers: 1,
    });

    const savedRoom = await this.roomRepository.save(room);

    // Create chat room in Firestore
    const chatRoomId = await this.chatService.createChatRoom(savedRoom.id, userId);
    savedRoom.chatRoomId = chatRoomId;
    await this.roomRepository.save(savedRoom);

    // Add host as member
    const member = this.roomMemberRepository.create({
      roomId: savedRoom.id,
      userId,
      isHost: true,
    });
    await this.roomMemberRepository.save(member);

    // 텔레그램 관리자 알림
    void this.telegramService.sendAdminAlert(
      `🏠 <b>신규 모임 생성</b>\n` +
        `• 제목: ${escapeHtml(savedRoom.title)}\n` +
        `• 지역: ${escapeHtml(savedRoom.regionSigungu ?? '')} ${escapeHtml(savedRoom.regionDong ?? '')}\n` +
        `• 일시: ${escapeHtml(savedRoom.date)} ${escapeHtml(savedRoom.startTime)}\n` +
        `• 호스트: ${escapeHtml(host?.nickname ?? '-')} (<code>${escapeHtml(userId)}</code>)`,
    );

    // NEW_FLASH(주변 사용자에게 번개 모임 전파)는 위치 기반 타겟팅 워커가 필요해 보류.
    // 그 전까지는 본인에게 self-발송하던 placeholder 가 노이즈만 만들어 제거했다.
    // 팔로워 대상 알림은 아래 FOLLOW_NEW_ROOM 으로 이미 커버된다.

    // 팔로워에게 FOLLOW_NEW_ROOM 푸시 (fire-and-forget)
    void this.followService
      .dispatchFollowNewRoomNotification(savedRoom.id, userId)
      .catch(() => undefined);

    // 같은 동네(시군구) 사용자에게 NEW_ROOM 푸시 (fire-and-forget)
    void this.dispatchNearbyNewRoomNotification(savedRoom, userId).catch(
      () => undefined,
    );

    // Fetch full room data
    return this.getDetail(savedRoom.id, userId);
  }

  // 같은 동네(시군구) 사용자에게 NEW_ROOM 푸시.
  // 본인 / 팔로워(FOLLOW_NEW_ROOM 중복) / 차단(양방향) 은 제외한다.
  private async dispatchNearbyNewRoomNotification(
    room: Room,
    hostUserId: string,
  ) {
    if (!room.regionSigungu) return;

    // 방 자격에 맞는 사용자에게만 — 한부모 방은 한부모, 성별 방은 해당 성별.
    // (못 보는 방의 알림이 가지 않도록 노출 필터와 동일한 기준 적용)
    const where: {
      regionSigungu: string;
      isSingleParent?: boolean;
      parentGender?: string;
    } = { regionSigungu: room.regionSigungu };
    if (room.singleParentOnly) where.isSingleParent = true;
    if (room.genderFilter === 'MOM_ONLY') where.parentGender = 'MOM';
    else if (room.genderFilter === 'DAD_ONLY') where.parentGender = 'DAD';

    const nearby = await this.userRepository.find({ where, select: ['id'] });
    if (nearby.length === 0) return;

    const exclude = new Set<string>([hostUserId]);

    // 팔로워는 FOLLOW_NEW_ROOM 으로 이미 받으므로 중복 제외
    const followerRows = await this.roomRepository.query(
      `SELECT follower_id FROM follow WHERE target_user_id = $1`,
      [hostUserId],
    );
    for (const r of followerRows) exclude.add(r.follower_id);

    // 차단(양방향) 제외 — block 테이블 미동기화 환경은 건너뜀
    try {
      const blockRows = await this.roomRepository.query(
        `SELECT blocker_id, target_user_id FROM block
         WHERE blocker_id = $1 OR target_user_id = $1`,
        [hostUserId],
      );
      for (const r of blockRows) {
        exclude.add(
          r.blocker_id === hostUserId ? r.target_user_id : r.blocker_id,
        );
      }
    } catch {
      // 차단 제외 생략
    }

    const place = room.regionDong || room.regionSigungu;
    for (const u of nearby) {
      if (exclude.has(u.id)) continue;
      try {
        await this.notificationService.create({
          userId: u.id,
          type: 'NEW_ROOM',
          title: '우리 동네 새 모임',
          body: `${place}에 새 모임이 열렸어요.`,
          data: { roomId: room.id },
        });
      } catch {
        // 개별 발송 실패 무시
      }
    }
  }

  async findAll(userId: string, query: RoomQueryDto) {
    const viewer = await this.userRepository.findOne({ where: { id: userId } });

    const qb = this.roomRepository
      .createQueryBuilder('room')
      .leftJoinAndSelect('room.host', 'host')
      .where('room.date >= CURRENT_DATE')
      .andWhere('room.status IN (:...statuses)', {
        statuses: ['RECRUITING', 'CLOSED'],
      });

    // Apple Guideline 1.2: 차단(양방향)한 유저가 호스트인 방은 피드에서 즉시 제외.
    qb.andWhere(
      `NOT EXISTS (
        SELECT 1 FROM "block" b
        WHERE (b.blocker_id = :viewerId AND b.target_user_id = room.host_id)
           OR (b.blocker_id = room.host_id AND b.target_user_id = :viewerId)
      )`,
      { viewerId: userId },
    );

    // Filters
    if (query.regionDong) {
      qb.andWhere('room.regionDong = :regionDong', { regionDong: query.regionDong });
    }
    if (query.regionSigungu) {
      qb.andWhere('room.regionSigungu = :regionSigungu', { regionSigungu: query.regionSigungu });
    }
    if (query.dateFrom) {
      qb.andWhere('room.date >= :dateFrom', { dateFrom: query.dateFrom });
    }
    if (query.dateTo) {
      qb.andWhere('room.date <= :dateTo', { dateTo: query.dateTo });
    }
    if (query.ageMonth !== undefined) {
      qb.andWhere('room.ageMonthMin <= :ageMax', { ageMax: query.ageMonth + 3 });
      qb.andWhere('room.ageMonthMax >= :ageMin', { ageMin: query.ageMonth - 3 });
    }
    if (query.placeType) {
      qb.andWhere('room.placeType = :placeType', { placeType: query.placeType });
    }
    if (query.joinType) {
      qb.andWhere('room.joinType = :joinType', { joinType: query.joinType });
    }
    if (query.costFree) {
      qb.andWhere('room.cost = 0');
    }
    if (query.genderFilter) {
      qb.andWhere('room.genderFilter = :gf', { gf: query.genderFilter });
    }
    if (query.singleParentOnly !== undefined) {
      qb.andWhere('room.singleParentOnly = :spo', { spo: query.singleParentOnly });
    }
    if (query.isFlashMeeting !== undefined) {
      qb.andWhere('room.isFlashMeeting = :flash', { flash: query.isFlashMeeting });
    }

    // 자격 자동 필터: 본인 parentGender / isSingleParent 기준으로 참여 불가 방은 제외.
    if (viewer) {
      if (viewer.parentGender === 'MOM') {
        qb.andWhere(`room.genderFilter <> 'DAD_ONLY'`);
      } else if (viewer.parentGender === 'DAD') {
        qb.andWhere(`room.genderFilter <> 'MOM_ONLY'`);
      }
      if (viewer.isSingleParent !== true) {
        qb.andWhere(`room.singleParentOnly = false`);
      }
    }

    // Cursor-based pagination
    if (query.cursor) {
      const cursorRoom = await this.roomRepository.findOne({ where: { id: query.cursor } });
      if (cursorRoom) {
        qb.andWhere('(room.date > :cursorDate OR (room.date = :cursorDate AND room.id > :cursorId))', {
          cursorDate: cursorRoom.date,
          cursorId: cursorRoom.id,
        });
      }
    }

    const limit = query.limit || 20;
    qb.orderBy('room.date', 'ASC')
      .addOrderBy('room.startTime', 'ASC')
      .addOrderBy('room.id', 'ASC')
      .take(limit + 1);

    const rooms = await qb.getMany();
    const hasMore = rooms.length > limit;
    if (hasMore) rooms.pop();

    // 내가 방장이거나 참여 중인 방 — 클라이언트에서 거리 표시를 생략한다.
    const roomIds = rooms.map((r) => r.id);
    const memberRows = roomIds.length
      ? await this.roomMemberRepository
          .createQueryBuilder('m')
          .select('m.roomId', 'roomId')
          .where('m.userId = :userId', { userId })
          .andWhere('m.roomId IN (:...ids)', { ids: roomIds })
          .getRawMany()
      : [];
    const memberRoomIds = new Set<string>(memberRows.map((r) => r.roomId));

    const items = rooms.map((room) => {
      const masked = this.roomVisibility.maskCoordinatesForList({
        id: room.id,
        latitude: room.latitude,
        longitude: room.longitude,
      });
      return {
        id: room.id,
        title: room.title,
        date: room.date,
        startTime: room.startTime,
        regionDong: room.regionDong,
        ageMonthMin: room.ageMonthMin,
        ageMonthMax: room.ageMonthMax,
        placeType: room.placeType,
        currentMembers: room.currentMembers,
        maxMembers: room.maxMembers,
        joinType: room.joinType,
        genderFilter: room.genderFilter,
        singleParentOnly: room.singleParentOnly,
        isFlashMeeting: room.isFlashMeeting,
        cost: room.cost,
        tags: room.tags,
        status: room.status,
        host: room.host
          ? {
              id: room.host.id,
              nickname: room.host.nickname,
              profileImageUrl: room.host.profileImageUrl,
            }
          : null,
        joined: room.hostId === userId || memberRoomIds.has(room.id),
        // 마스킹된 좌표만 노출. placeName/placeAddress 는 응답에서 제외.
        latitude: masked.latitude,
        longitude: masked.longitude,
      };
    });

    return {
      items,
      nextCursor: hasMore && rooms.length > 0 ? rooms[rooms.length - 1].id : null,
      hasMore,
    };
  }

  async getDetail(roomId: string, userId?: string) {
    const room = await this.roomRepository.findOne({
      where: { id: roomId },
      relations: ['host', 'members', 'members.user', 'members.user.children'],
    });

    if (!room) {
      throw new NotFoundException('방을 찾을 수 없습니다.');
    }

    // 한부모 전용 방은 한부모 가정만 상세 조회 가능 — 목록/지도 필터와 동일 기준.
    // (목록엔 안 떠도 roomId 직접 조회로 노출되던 갭 차단)
    if (room.singleParentOnly === true) {
      const viewer = userId
        ? await this.userRepository.findOne({ where: { id: userId } })
        : null;
      if (viewer?.isSingleParent !== true) {
        throw new ForbiddenException({
          code: 'SINGLE_PARENT_REQUIRED',
          message: '한부모 가정 전용 방입니다.',
        });
      }
    }

    // Determine user's status in this room
    let myStatus = 'NONE';
    if (userId) {
      const member = await this.roomMemberRepository.findOne({
        where: { roomId, userId },
      });
      if (member) {
        myStatus = 'ACCEPTED';
      } else {
        const joinRequest = await this.joinRequestRepository.findOne({
          where: { roomId, userId },
          order: { createdAt: 'DESC' },
        });
        if (joinRequest) {
          myStatus = joinRequest.status;
        }
      }
    }

    // Check if user can join
    let canJoin = true;
    let canJoinReason: string | null = null;

    if (myStatus === 'ACCEPTED' || myStatus === 'PENDING') {
      canJoin = false;
      canJoinReason = '이미 참여 중이거나 신청 중입니다.';
    } else if (room.status !== 'RECRUITING') {
      canJoin = false;
      canJoinReason = '모집이 종료되었습니다.';
    } else if (room.currentMembers >= room.maxMembers) {
      canJoin = false;
      canJoinReason = '인원이 가득 찼습니다.';
    }

    const now = new Date();
    const members = room.members?.map((m) => ({
      id: m.user?.id,
      nickname: m.user?.nickname,
      profileImageUrl: m.user?.profileImageUrl,
      parentGender: m.user?.parentGender,
      isSingleParent: m.user?.isSingleParent,
      birthYear: m.user?.birthDate ? new Date(m.user.birthDate).getFullYear() : null,
      mannerScore: m.user?.mannerScore != null ? Number(m.user.mannerScore) : undefined,
      children: m.user?.children?.map((c) => ({
        id: c.id,
        nickname: c.nickname,
        ageMonths: (now.getFullYear() - c.birthYear) * 12 + (now.getMonth() + 1 - c.birthMonth),
        gender: c.gender,
      })),
      isHost: m.isHost,
    }));

    const isMember = myStatus === 'ACCEPTED';

    const response: any = {
      id: room.id,
      hostId: room.hostId,
      title: room.title,
      description: room.description,
      date: room.date,
      startTime: room.startTime,
      endTime: room.endTime,
      regionSido: room.regionSido,
      regionSigungu: room.regionSigungu,
      regionDong: room.regionDong,
      ageMonthMin: room.ageMonthMin,
      ageMonthMax: room.ageMonthMax,
      placeType: room.placeType,
      placeName: room.placeName,
      placeAddress: room.placeAddress,
      latitude: room.latitude,
      longitude: room.longitude,
      maxMembers: room.maxMembers,
      currentMembers: room.currentMembers,
      joinType: room.joinType,
      genderFilter: room.genderFilter,
      singleParentOnly: room.singleParentOnly,
      isFlashMeeting: room.isFlashMeeting,
      requiredItems: room.requiredItems,
      cost: room.cost,
      costDescription: room.costDescription,
      tags: room.tags,
      status: room.status,
      host: room.host
        ? {
            id: room.host.id,
            nickname: room.host.nickname,
            profileImageUrl: room.host.profileImageUrl,
            regionSigungu: room.host.regionSigungu,
            parentGender: room.host.parentGender,
            isSingleParent: room.host.isSingleParent,
            birthYear: room.host.birthDate
              ? new Date(room.host.birthDate).getFullYear()
              : null,
            mannerScore:
              room.host.mannerScore != null ? Number(room.host.mannerScore) : undefined,
          }
        : null,
      members,
      myStatus,
      canJoin,
      canJoinReason,
      chatRoomId: room.chatRoomId,
      createdAt: room.createdAt,
    };

    return this.roomVisibility.maskRoomForViewer(response, userId, isMember);
  }

  async update(userId: string, roomId: string, dto: UpdateRoomDto) {
    const room = await this.roomRepository.findOne({ where: { id: roomId } });

    if (!room) {
      throw new NotFoundException('방을 찾을 수 없습니다.');
    }

    if (room.hostId !== userId) {
      throw new ForbiddenException('방장만 수정할 수 있습니다.');
    }

    if (room.status === 'CANCELLED' || room.status === 'COMPLETED') {
      throw new BadRequestException('취소되었거나 완료된 모임은 수정할 수 없습니다.');
    }

    // Validate maxMembers is not below currentMembers
    if (dto.maxMembers !== undefined && dto.maxMembers < room.currentMembers) {
      throw new BadRequestException(
        `최대 인원은 현재 참여 인원(${room.currentMembers}명) 이상이어야 합니다.`,
      );
    }

    // Apple Guideline 1.2: UGC 자동 필터.
    if (dto.title !== undefined) {
      this.profanityFilter.assertClean(dto.title, '제목');
    }
    if (dto.description !== undefined) {
      this.profanityFilter.assertClean(dto.description, '설명');
    }

    Object.assign(room, dto);
    await this.roomRepository.save(room);

    return this.getDetail(roomId, userId);
  }

  async cancel(userId: string, roomId: string) {
    const room = await this.roomRepository.findOne({
      where: { id: roomId },
      relations: ['members'],
    });

    if (!room) {
      throw new NotFoundException('방을 찾을 수 없습니다.');
    }

    if (room.hostId !== userId) {
      throw new ForbiddenException('방장만 취소할 수 있습니다.');
    }

    room.status = 'CANCELLED';
    await this.roomRepository.save(room);

    // Notify all members
    for (const member of room.members) {
      if (member.userId !== userId) {
        await this.notificationService.create({
          userId: member.userId,
          type: 'ROOM_CANCELLED',
          title: '모임 취소',
          body: `[${room.title}] 모임이 취소되었습니다.`,
          data: { roomId: room.id },
        });
      }
    }

    return { success: true };
  }

  /** 모임 종료 — 방장이 언제든지 종료 가능. 출석 체크/후기의 기준점이 된다. */
  async complete(userId: string, roomId: string) {
    const room = await this.roomRepository.findOne({
      where: { id: roomId },
      relations: ['members'],
    });

    if (!room) {
      throw new NotFoundException('방을 찾을 수 없습니다.');
    }

    if (room.hostId !== userId) {
      throw new ForbiddenException('방장만 모임을 종료할 수 있습니다.');
    }

    if (room.status === 'COMPLETED') {
      throw new BadRequestException('이미 종료된 모임입니다.');
    }

    if (room.status === 'CANCELLED') {
      throw new BadRequestException('취소된 모임은 종료할 수 없습니다.');
    }

    room.status = 'COMPLETED';
    room.completedAt = new Date();
    await this.roomRepository.save(room);

    // Notify all members
    for (const member of room.members) {
      if (member.userId !== userId) {
        await this.notificationService.create({
          userId: member.userId,
          type: 'ROOM_COMPLETED',
          title: '모임 종료',
          body: `[${room.title}] 모임이 종료되었습니다. 출석 체크와 후기를 남겨주세요.`,
          data: { roomId: room.id },
        });
      }
    }

    return { success: true };
  }

  async getMyRooms(userId: string, query: MyRoomQueryDto) {
    const qb = this.roomRepository
      .createQueryBuilder('room')
      .innerJoin('room.members', 'member', 'member.userId = :userId', { userId })
      .leftJoinAndSelect('room.host', 'host');

    if (query.type === 'HOSTING') {
      qb.andWhere('room.hostId = :userId', { userId });
    } else if (query.type === 'JOINED') {
      qb.andWhere('room.hostId != :userId', { userId });
    }

    if (query.status === 'UPCOMING') {
      qb.andWhere('room.date >= CURRENT_DATE');
      qb.andWhere('room.status NOT IN (:...statuses)', {
        statuses: ['COMPLETED', 'CANCELLED'],
      });
    } else if (query.status === 'PAST') {
      qb.andWhere('(room.date < CURRENT_DATE OR room.status IN (:...statuses))', {
        statuses: ['COMPLETED', 'CANCELLED'],
      });
    }

    qb.orderBy('room.date', query.status === 'PAST' ? 'DESC' : 'ASC')
      .addOrderBy('room.startTime', 'ASC');

    const rooms = await qb.getMany();

    return rooms.map((room) => ({
      id: room.id,
      title: room.title,
      date: room.date,
      startTime: room.startTime,
      regionDong: room.regionDong,
      ageMonthMin: room.ageMonthMin,
      ageMonthMax: room.ageMonthMax,
      placeType: room.placeType,
      currentMembers: room.currentMembers,
      maxMembers: room.maxMembers,
      status: room.status,
      chatRoomId: room.chatRoomId,
      host: room.host
        ? {
            id: room.host.id,
            nickname: room.host.nickname,
            profileImageUrl: room.host.profileImageUrl,
          }
        : null,
    }));
  }

  async getMapRooms(userId: string, query: MapQueryDto) {
    const viewer = await this.userRepository.findOne({ where: { id: userId } });
    // 본인이 참여 자격이 없는 방(성별/한부모)은 지도에서도 보이지 않게 차단.
    const applyEligibility = (qb: SelectQueryBuilder<Room>) => {
      if (!viewer) return;
      if (viewer.parentGender === 'MOM') {
        qb.andWhere(`room.genderFilter <> 'DAD_ONLY'`);
      } else if (viewer.parentGender === 'DAD') {
        qb.andWhere(`room.genderFilter <> 'MOM_ONLY'`);
      }
      if (viewer.isSingleParent !== true) {
        qb.andWhere(`room.singleParentOnly = false`);
      }
    };

    // Apple Guideline 1.2: 양방향 차단 호스트의 방은 지도에서도 제외.
    const applyBlockFilter = (qb: SelectQueryBuilder<Room>) => {
      qb.andWhere(
        `NOT EXISTS (
          SELECT 1 FROM "block" b
          WHERE (b.blocker_id = :blockViewerId AND b.target_user_id = room.host_id)
             OR (b.blocker_id = room.host_id AND b.target_user_id = :blockViewerId)
        )`,
        { blockViewerId: userId },
      );
    };

    // 사용자가 지정한 필터 — 클러스터/핀 모드 공통 적용.
    const applyFilters = (qb: SelectQueryBuilder<Room>) => {
      if (query.dateFrom) {
        qb.andWhere('room.date >= :dateFrom', { dateFrom: query.dateFrom });
      }
      if (query.dateTo) {
        qb.andWhere('room.date <= :dateTo', { dateTo: query.dateTo });
      }
      if (query.startTimeFrom) {
        qb.andWhere('room.startTime >= :stf', { stf: query.startTimeFrom });
      }
      if (query.startTimeTo) {
        qb.andWhere('room.startTime <= :stt', { stt: query.startTimeTo });
      }
      if (query.ageMonth !== undefined) {
        qb.andWhere('room.ageMonthMin <= :ageMax', {
          ageMax: query.ageMonth + 3,
        });
        qb.andWhere('room.ageMonthMax >= :ageMin', {
          ageMin: query.ageMonth - 3,
        });
      }
      if (query.placeType) {
        qb.andWhere('room.placeType = :placeType', {
          placeType: query.placeType,
        });
      }
      if (query.joinType) {
        qb.andWhere('room.joinType = :joinType', { joinType: query.joinType });
      }
      if (query.costFree) {
        qb.andWhere('room.cost = 0');
      }
      if (query.genderFilter) {
        qb.andWhere('room.genderFilter = :gf', { gf: query.genderFilter });
      }
      if (query.singleParentOnly !== undefined) {
        qb.andWhere('room.singleParentOnly = :spo', {
          spo: query.singleParentOnly,
        });
      }
      if (query.isFlashMeeting !== undefined) {
        qb.andWhere('room.isFlashMeeting = :flash', {
          flash: query.isFlashMeeting,
        });
      }
    };

    // 뷰포트(sw/ne) 파라미터가 모두 있으면 해당 영역으로 한정하고, 빠지면
    // "등록된 모든 활성 방"을 그대로 반환한다 — 지도에서 한 번에 전국 핀을
    // 보여줄 때 클라이언트가 빈 인자로 호출한다.
    const hasViewport =
      query.swLat !== undefined &&
      query.swLng !== undefined &&
      query.neLat !== undefined &&
      query.neLng !== undefined;
    const applyViewport = (qb: SelectQueryBuilder<Room>) => {
      if (!hasViewport) return;
      qb.andWhere('room.latitude BETWEEN :swLat AND :neLat', {
        swLat: query.swLat,
        neLat: query.neLat,
      }).andWhere('room.longitude BETWEEN :swLng AND :neLng', {
        swLng: query.swLng,
        neLng: query.neLng,
      });
    };

    // 클러스터 → 핀 전환 임계값. 11 이하(시·자치구 전체)에서만 동 단위 클러스터로 묶고,
    // 12 부터(주변 동네 보임)는 바로 개별 핀을 그린다. 핀이 같은 좌표에 몰릴 때는
    // 클라이언트가 ~20m 격자로 묶어 "+N" 스택 마커로 표시한다.
    if (query.zoomLevel !== undefined && query.zoomLevel <= 11) {
      // Cluster mode
      const clusterQb = this.roomRepository
        .createQueryBuilder('room')
        .select('room.regionDong', 'regionDong')
        .addSelect('COUNT(*)', 'count')
        .addSelect('AVG(room.latitude)', 'latitude')
        .addSelect('AVG(room.longitude)', 'longitude')
        .where('room.date >= CURRENT_DATE')
        .andWhere('room.status IN (:...statuses)', {
          statuses: ['RECRUITING', 'CLOSED'],
        });
      applyViewport(clusterQb);
      applyEligibility(clusterQb);
      applyBlockFilter(clusterQb);
      applyFilters(clusterQb);
      const clusters = await clusterQb.groupBy('room.regionDong').getRawMany();

      return {
        mode: 'CLUSTER',
        clusters: clusters.map((c) => ({
          regionDong: c.regionDong,
          count: parseInt(c.count),
          latitude: parseFloat(c.latitude),
          longitude: parseFloat(c.longitude),
        })),
      };
    } else {
      // Pin mode
      const qb = this.roomRepository
        .createQueryBuilder('room')
        .where('room.date >= CURRENT_DATE')
        .andWhere('room.status IN (:...statuses)', {
          statuses: ['RECRUITING', 'CLOSED'],
        });

      applyViewport(qb);
      applyEligibility(qb);
      applyBlockFilter(qb);
      applyFilters(qb);

      const rooms = await qb.getMany();

      // viewer 가 참여 중(또는 방장)인 방은 정확한 좌표, 그 외는 fuzzy.
      const roomIds = rooms.map((r) => r.id);
      const memberRows = roomIds.length
        ? await this.roomMemberRepository
            .createQueryBuilder('m')
            .select('m.roomId', 'roomId')
            .where('m.userId = :userId', { userId })
            .andWhere('m.roomId IN (:...ids)', { ids: roomIds })
            .getRawMany()
        : [];
      const memberRoomIds = new Set<string>(memberRows.map((r) => r.roomId));

      return {
        mode: 'PIN',
        pins: rooms.map((room) => {
          // joined: 방장이거나 멤버 — 클라이언트에서 거리 표시를 생략한다.
          const joined =
            room.hostId === userId || memberRoomIds.has(room.id);
          const coord = joined
            ? { latitude: room.latitude, longitude: room.longitude }
            : this.roomVisibility.maskCoordinatesForList({
                id: room.id,
                latitude: room.latitude,
                longitude: room.longitude,
              });
          return {
            id: room.id,
            title: room.title,
            date: room.date,
            startTime: room.startTime,
            ageMonthMin: room.ageMonthMin,
            ageMonthMax: room.ageMonthMax,
            currentMembers: room.currentMembers,
            maxMembers: room.maxMembers,
            placeType: room.placeType,
            joinType: room.joinType,
            genderFilter: room.genderFilter,
            singleParentOnly: room.singleParentOnly,
            isFlashMeeting: room.isFlashMeeting,
            regionDong: room.regionDong,
            joined,
            latitude: coord.latitude,
            longitude: coord.longitude,
          };
        }),
      };
    }
  }

  /** 주소 문자열을 좌표로 변환 — 클라이언트가 방 생성 전 호출. */
  async geocode(address: string) {
    const result = await this.geocodingService.geocode(address ?? '');
    return {
      latitude: result?.latitude ?? null,
      longitude: result?.longitude ?? null,
    };
  }
}
