import {
  Injectable,
  Logger,
  NotFoundException,
  ConflictException,
  BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, Not } from 'typeorm';
import { User } from './entities/user.entity';
import { Child } from '../child/entities/child.entity';
import { RoomMember } from '../room/entities/room-member.entity';
import { AppleService } from '../auth/social/apple.service';
import { CreateProfileDto } from './dto/create-profile.dto';
import { UpdateProfileDto } from './dto/update-profile.dto';

@Injectable()
export class UserService {
  private readonly logger = new Logger(UserService.name);

  constructor(
    @InjectRepository(User)
    private userRepository: Repository<User>,
    @InjectRepository(Child)
    private childRepository: Repository<Child>,
    @InjectRepository(RoomMember)
    private roomMemberRepository: Repository<RoomMember>,
    private appleService: AppleService,
  ) {}

  async createProfile(userId: string, dto: CreateProfileDto) {
    const user = await this.userRepository.findOne({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('사용자를 찾을 수 없습니다.');
    }

    // Check nickname uniqueness
    const existingNickname = await this.userRepository.findOne({
      where: { nickname: dto.nickname },
    });
    if (existingNickname && existingNickname.id !== userId) {
      throw new ConflictException({
        code: 'NICKNAME_ALREADY_EXISTS',
        message: '이미 사용 중인 닉네임입니다.',
      });
    }

    user.nickname = dto.nickname;
    if (dto.regionSido) user.regionSido = dto.regionSido;
    if (dto.regionSigungu) user.regionSigungu = dto.regionSigungu;
    if (dto.regionDong) user.regionDong = dto.regionDong;
    user.profileImageUrl = dto.profileImageUrl || user.profileImageUrl;
    user.introduction = dto.introduction || user.introduction;
    user.isProfileComplete = true;

    const saved = await this.userRepository.save(user);
    return this.sanitizeUser(saved);
  }

  async getMe(userId: string) {
    const user = await this.userRepository.findOne({
      where: { id: userId },
      relations: ['children'],
    });
    if (!user) {
      throw new NotFoundException('사용자를 찾을 수 없습니다.');
    }

    const result = this.sanitizeUser(user);
    // Add ageMonths to each child
    if (user.children) {
      (result as any).children = user.children.map((child) => ({
        id: child.id,
        nickname: child.nickname,
        birthYear: child.birthYear,
        birthMonth: child.birthMonth,
        ageMonths: this.calculateAgeMonths(child.birthYear, child.birthMonth),
        gender: child.gender,
        createdAt: child.createdAt,
      }));
    }

    return result;
  }

  async updateMe(userId: string, dto: UpdateProfileDto) {
    const user = await this.userRepository.findOne({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('사용자를 찾을 수 없습니다.');
    }

    // Check nickname uniqueness if updating
    if (dto.nickname && dto.nickname !== user.nickname) {
      const existingNickname = await this.userRepository.findOne({
        where: { nickname: dto.nickname, id: Not(userId) },
      });
      if (existingNickname) {
        throw new ConflictException({
          code: 'NICKNAME_ALREADY_EXISTS',
          message: '이미 사용 중인 닉네임입니다.',
        });
      }
    }

    Object.assign(user, dto);
    const saved = await this.userRepository.save(user);
    return this.sanitizeUser(saved);
  }

  async checkNickname(nickname: string) {
    const existing = await this.userRepository.findOne({
      where: { nickname },
    });
    return { available: !existing };
  }

  async getUserById(userId: string) {
    const user = await this.userRepository.findOne({
      where: { id: userId, status: 'ACTIVE' },
      relations: ['children'],
    });

    if (!user) {
      throw new NotFoundException('사용자를 찾을 수 없습니다.');
    }

    // Count rooms the user participated in
    const roomCount = await this.roomMemberRepository.count({
      where: { userId },
    });

    return {
      id: user.id,
      nickname: user.nickname,
      regionSigungu: user.regionSigungu,
      profileImageUrl: user.profileImageUrl,
      introduction: user.introduction,
      children: user.children?.map((child) => ({
        nickname: child.nickname,
        ageMonths: this.calculateAgeMonths(child.birthYear, child.birthMonth),
        gender: child.gender,
      })),
      roomCount,
      createdAt: user.createdAt,
    };
  }

  async deleteMe(userId: string, reason?: string) {
    const user = await this.userRepository.findOne({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('사용자를 찾을 수 없습니다.');
    }

    // Check for active rooms
    const activeRooms = await this.roomMemberRepository
      .createQueryBuilder('rm')
      .innerJoin('rm.room', 'room')
      .where('rm.userId = :userId', { userId })
      .andWhere('room.status IN (:...statuses)', {
        statuses: ['RECRUITING', 'CLOSED', 'IN_PROGRESS'],
      })
      .getCount();

    if (activeRooms > 0) {
      throw new BadRequestException(
        '진행 중인 모임이 있어 탈퇴할 수 없습니다.',
      );
    }

    // Apple 사용자면 Apple 측 토큰 revoke (App Store 5.1.1(v) 준수)
    if (user.authProvider === 'APPLE' && user.appleRefreshToken) {
      const ok = await this.appleService.revokeRefreshToken(
        user.appleRefreshToken,
      );
      this.logger.log(
        `[deleteMe] userId=${userId} apple revoke=${ok ? 'success' : 'failed'}`,
      );
    }

    // Soft delete
    user.status = 'WITHDRAWN';
    user.withdrawnAt = new Date();
    user.appleRefreshToken = null as unknown as string;
    await this.userRepository.save(user);

    return { success: true };
  }

  private sanitizeUser(user: User) {
    const { passwordHash, ...result } = user;
    return result;
  }

  private calculateAgeMonths(birthYear: number, birthMonth: number): number {
    const now = new Date();
    return (now.getFullYear() - birthYear) * 12 + (now.getMonth() + 1 - birthMonth);
  }
}
