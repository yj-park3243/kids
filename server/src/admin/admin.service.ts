import {
  Injectable,
  UnauthorizedException,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { User } from '../user/entities/user.entity';
import { Room } from '../room/entities/room.entity';
import { Child } from '../child/entities/child.entity';
import { AdminLoginDto } from './dto/admin-login.dto';
import { AdminUserQueryDto, AdminRoomQueryDto } from './dto/admin-query.dto';

@Injectable()
export class AdminService {
  constructor(
    @InjectRepository(User)
    private userRepository: Repository<User>,
    @InjectRepository(Room)
    private roomRepository: Repository<Room>,
    @InjectRepository(Child)
    private childRepository: Repository<Child>,
    private jwtService: JwtService,
  ) {}

  async login(dto: AdminLoginDto) {
    const user = await this.userRepository.findOne({
      where: { email: dto.email, isAdmin: true },
    });

    if (!user) {
      throw new UnauthorizedException('관리자 계정이 아닙니다.');
    }

    const isPasswordValid = await bcrypt.compare(dto.password, user.passwordHash);
    if (!isPasswordValid) {
      throw new UnauthorizedException('비밀번호가 올바르지 않습니다.');
    }

    const payload = {
      sub: user.id,
      email: user.email,
      isAdmin: true,
    };

    const accessToken = this.jwtService.sign(payload, { expiresIn: '8h' });

    return {
      accessToken,
      user: {
        id: user.id,
        email: user.email,
        nickname: user.nickname,
        isAdmin: user.isAdmin,
      },
    };
  }

  async getDashboard() {
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const [
      totalUsers,
      totalRooms,
      todayUsers,
      todayRooms,
      activeRooms,
      bannedUsers,
    ] = await Promise.all([
      this.userRepository.count(),
      this.roomRepository.count(),
      this.userRepository
        .createQueryBuilder('user')
        .where('user.createdAt >= :today', { today })
        .getCount(),
      this.roomRepository
        .createQueryBuilder('room')
        .where('room.createdAt >= :today', { today })
        .getCount(),
      this.roomRepository.count({
        where: [
          { status: 'RECRUITING' },
          { status: 'CLOSED' },
          { status: 'IN_PROGRESS' },
        ],
      }),
      this.userRepository.count({ where: { status: 'BANNED' } }),
    ]);

    return {
      totalUsers,
      totalRooms,
      todayUsers,
      todayRooms,
      activeRooms,
      bannedUsers,
    };
  }

  async getUsers(query: AdminUserQueryDto) {
    const page = query.page || 1;
    const limit = query.limit || 20;
    const skip = (page - 1) * limit;

    const qb = this.userRepository
      .createQueryBuilder('user')
      .leftJoinAndSelect('user.children', 'children')
      .orderBy('user.createdAt', 'DESC');

    if (query.search) {
      qb.where(
        '(user.nickname ILIKE :search OR user.email ILIKE :search)',
        { search: `%${query.search}%` },
      );
    }

    const [users, total] = await qb.skip(skip).take(limit).getManyAndCount();

    return {
      items: users.map((u) => {
        const { passwordHash, ...rest } = u;
        return rest;
      }),
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    };
  }

  async getUserDetail(userId: string) {
    const user = await this.userRepository.findOne({
      where: { id: userId },
      relations: ['children'],
    });

    if (!user) {
      throw new NotFoundException('사용자를 찾을 수 없습니다.');
    }

    const { passwordHash, ...result } = user;

    // Get room count
    const roomCount = await this.roomRepository.count({
      where: { hostId: userId },
    });

    return {
      ...result,
      roomCount,
    };
  }

  async banUser(userId: string, banned: boolean) {
    const user = await this.userRepository.findOne({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('사용자를 찾을 수 없습니다.');
    }

    user.status = banned ? 'BANNED' : 'ACTIVE';
    await this.userRepository.save(user);

    return { success: true, status: user.status };
  }

  async getRooms(query: AdminRoomQueryDto) {
    const page = query.page || 1;
    const limit = query.limit || 20;
    const skip = (page - 1) * limit;

    const qb = this.roomRepository
      .createQueryBuilder('room')
      .leftJoinAndSelect('room.host', 'host')
      .orderBy('room.createdAt', 'DESC');

    if (query.search) {
      qb.where('room.title ILIKE :search', { search: `%${query.search}%` });
    }

    if (query.status) {
      qb.andWhere('room.status = :status', { status: query.status });
    }

    const [rooms, total] = await qb.skip(skip).take(limit).getManyAndCount();

    return {
      items: rooms.map((room) => ({
        id: room.id,
        title: room.title,
        date: room.date,
        startTime: room.startTime,
        regionDong: room.regionDong,
        status: room.status,
        currentMembers: room.currentMembers,
        maxMembers: room.maxMembers,
        host: room.host
          ? {
              id: room.host.id,
              nickname: room.host.nickname,
              email: room.host.email,
            }
          : null,
        createdAt: room.createdAt,
      })),
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    };
  }

  async getRoomDetail(roomId: string) {
    const room = await this.roomRepository.findOne({
      where: { id: roomId },
      relations: ['host', 'members', 'members.user'],
    });

    if (!room) {
      throw new NotFoundException('방을 찾을 수 없습니다.');
    }

    // Sanitize user data to exclude passwordHash
    if (room.host) {
      const { passwordHash, ...hostData } = room.host;
      room.host = hostData as any;
    }
    if (room.members) {
      room.members.forEach((member) => {
        if (member.user) {
          const { passwordHash, ...userData } = member.user;
          member.user = userData as any;
        }
      });
    }

    return room;
  }

  async deleteRoom(roomId: string) {
    const room = await this.roomRepository.findOne({ where: { id: roomId } });
    if (!room) {
      throw new NotFoundException('방을 찾을 수 없습니다.');
    }

    room.status = 'CANCELLED';
    await this.roomRepository.save(room);

    return { success: true };
  }
}
