import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  ConflictException,
  BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
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
  ) {}

  async create(userId: string, dto: CreateRoomDto) {
    // Create room
    const room = this.roomRepository.create({
      hostId: userId,
      ...dto,
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

    // Fetch full room data
    return this.getDetail(savedRoom.id, userId);
  }

  async findAll(userId: string, query: RoomQueryDto) {
    const qb = this.roomRepository
      .createQueryBuilder('room')
      .leftJoinAndSelect('room.host', 'host')
      .where('room.date >= CURRENT_DATE')
      .andWhere('room.status IN (:...statuses)', {
        statuses: ['RECRUITING', 'CLOSED'],
      });

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

    const items = rooms.map((room) => ({
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
      latitude: room.latitude,
      longitude: room.longitude,
    }));

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
      children: m.user?.children?.map((c) => ({
        nickname: c.nickname,
        ageMonths: (now.getFullYear() - c.birthYear) * 12 + (now.getMonth() + 1 - c.birthMonth),
        gender: c.gender,
      })),
      isHost: m.isHost,
    }));

    return {
      id: room.id,
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
          }
        : null,
      members,
      myStatus,
      canJoin,
      canJoinReason,
      chatRoomId: room.chatRoomId,
      createdAt: room.createdAt,
    };
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

  async getMyRooms(userId: string, query: MyRoomQueryDto) {
    const qb = this.roomRepository
      .createQueryBuilder('room')
      .innerJoin('room.members', 'member', 'member.userId = :userId', { userId })
      .leftJoinAndSelect('room.host', 'host');

    if (query.type === 'HOSTING') {
      qb.andWhere('room.hostId = :userId', { userId });
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
      host: room.host
        ? {
            id: room.host.id,
            nickname: room.host.nickname,
            profileImageUrl: room.host.profileImageUrl,
          }
        : null,
    }));
  }

  async getMapRooms(query: MapQueryDto) {
    if (query.zoomLevel !== undefined && query.zoomLevel <= 13) {
      // Cluster mode
      const clusters = await this.roomRepository
        .createQueryBuilder('room')
        .select('room.regionDong', 'regionDong')
        .addSelect('COUNT(*)', 'count')
        .addSelect('AVG(room.latitude)', 'latitude')
        .addSelect('AVG(room.longitude)', 'longitude')
        .where('room.latitude BETWEEN :swLat AND :neLat', {
          swLat: query.swLat,
          neLat: query.neLat,
        })
        .andWhere('room.longitude BETWEEN :swLng AND :neLng', {
          swLng: query.swLng,
          neLng: query.neLng,
        })
        .andWhere('room.date >= CURRENT_DATE')
        .andWhere('room.status IN (:...statuses)', {
          statuses: ['RECRUITING', 'CLOSED'],
        })
        .groupBy('room.regionDong')
        .getRawMany();

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
        .where('room.latitude BETWEEN :swLat AND :neLat', {
          swLat: query.swLat,
          neLat: query.neLat,
        })
        .andWhere('room.longitude BETWEEN :swLng AND :neLng', {
          swLng: query.swLng,
          neLng: query.neLng,
        })
        .andWhere('room.date >= CURRENT_DATE')
        .andWhere('room.status IN (:...statuses)', {
          statuses: ['RECRUITING', 'CLOSED'],
        });

      if (query.ageMonth !== undefined) {
        qb.andWhere('room.ageMonthMin <= :ageMax', { ageMax: query.ageMonth + 3 });
        qb.andWhere('room.ageMonthMax >= :ageMin', { ageMin: query.ageMonth - 3 });
      }

      const rooms = await qb.getMany();

      return {
        mode: 'PIN',
        pins: rooms.map((room) => ({
          id: room.id,
          title: room.title,
          date: room.date,
          startTime: room.startTime,
          ageMonthMin: room.ageMonthMin,
          ageMonthMax: room.ageMonthMax,
          currentMembers: room.currentMembers,
          maxMembers: room.maxMembers,
          latitude: room.latitude,
          longitude: room.longitude,
        })),
      };
    }
  }
}
