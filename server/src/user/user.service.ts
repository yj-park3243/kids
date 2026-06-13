import {
  Injectable,
  Logger,
  NotFoundException,
  ConflictException,
  BadRequestException,
  UnprocessableEntityException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, Not } from 'typeorm';
import { User } from './entities/user.entity';
import { Child } from '../child/entities/child.entity';
import { RoomMember } from '../room/entities/room-member.entity';
import { AppleService } from '../auth/social/apple.service';
import { CreateProfileDto } from './dto/create-profile.dto';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { ProfanityFilterService } from '../common/services/profanity-filter.service';
import { fallbackCoord } from '../common/services/region-coords';

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
    private profanityFilter: ProfanityFilterService,
  ) {}

  async createProfile(userId: string, dto: CreateProfileDto) {
    const user = await this.userRepository.findOne({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('사용자를 찾을 수 없습니다.');
    }

    if (user.isProfileComplete) {
      throw new ConflictException({
        code: 'PROFILE_ALREADY_COMPLETED',
        message: '이미 프로필이 완료된 사용자입니다.',
      });
    }

    if (dto.parentGender !== 'MOM' && dto.parentGender !== 'DAD') {
      throw new UnprocessableEntityException({
        code: 'PARENT_GENDER_REQUIRED',
        message: '부모 성별(MOM/DAD)을 선택해야 합니다.',
      });
    }

    // Apple Guideline 1.2: UGC 자동 필터 (닉네임/소개).
    this.profanityFilter.assertClean(dto.nickname, '닉네임');
    this.profanityFilter.assertClean(dto.introduction, '소개');

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
    // 좌표 — 클라가 보내면 우선, 없으면 입력한 동네 기준 대략 좌표(폴백)를 저장.
    if (dto.latitude != null && dto.longitude != null) {
      user.latitude = dto.latitude;
      user.longitude = dto.longitude;
    } else if (dto.regionSido && dto.regionSigungu) {
      const fb = fallbackCoord(dto.regionSido, dto.regionSigungu, dto.regionDong);
      user.latitude = fb.lat;
      user.longitude = fb.lng;
    }
    user.profileImageUrl = dto.profileImageUrl || user.profileImageUrl;
    user.introduction = dto.introduction || user.introduction;
    user.parentGender = dto.parentGender;
    user.isSingleParent = dto.isSingleParent === true;
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
        photoUrl: child.photoUrl,
        verificationPhotoUrl: child.verificationPhotoUrl,
        napTime: child.napTime ?? null,
        temperamentTags: child.temperamentTags ?? [],
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

    // Apple Guideline 1.2: UGC 자동 필터 (닉네임/소개).
    if (dto.nickname !== undefined) {
      this.profanityFilter.assertClean(dto.nickname, '닉네임');
    }
    if (dto.introduction !== undefined) {
      this.profanityFilter.assertClean(dto.introduction, '소개');
    }

    // parentGender / isSingleParent 는 가입 후 수정 불가 — 요청에 섞여 들어와도 무시.
    const { parentGender: _pg, isSingleParent: _sp, ...patch } = dto as any;
    Object.assign(user, patch);
    const saved = await this.userRepository.save(user);
    return this.sanitizeUser(saved);
  }

  async checkNickname(nickname: string) {
    const existing = await this.userRepository.findOne({
      where: { nickname },
    });
    return { available: !existing };
  }

  async getUserById(userId: string, requesterId?: string) {
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

    // 받은 후기 정성 태그 top3 (review 테이블이 아직 동기화 전이면 빈 배열)
    let mannerTags: string[] = [];
    try {
      const rows = await this.userRepository.query(
        `SELECT tag, COUNT(*)::int AS c
         FROM (
           SELECT UNNEST(tags) AS tag FROM review WHERE target_user_id = $1
         ) t
         GROUP BY tag
         ORDER BY c DESC
         LIMIT 3`,
        [userId],
      );
      mannerTags = rows.map((r: { tag: string }) => r.tag);
    } catch {
      mannerTags = [];
    }

    // 노쇼 카운트 -> 3단계 텍스트로만 노출
    const nsc = Number(user.noShowCount ?? 0);
    const noShowLevel: 'NONE' | 'OCCASIONAL' | 'FREQUENT' =
      nsc < 1 ? 'NONE' : nsc < 3 ? 'OCCASIONAL' : 'FREQUENT';

    // 팔로우/차단 관계 (요청자 vs target) — 테이블 미존재 시 false fallback
    let isFollowing = false;
    let isBlocked = false;
    if (requesterId && requesterId !== userId) {
      try {
        const fRows = await this.userRepository.query(
          `SELECT 1 FROM follow WHERE follower_id = $1 AND target_user_id = $2 LIMIT 1`,
          [requesterId, userId],
        );
        isFollowing = fRows.length > 0;
      } catch {
        isFollowing = false;
      }
      try {
        const bRows = await this.userRepository.query(
          `SELECT 1 FROM block
           WHERE (blocker_id = $1 AND target_user_id = $2)
              OR (blocker_id = $2 AND target_user_id = $1)
           LIMIT 1`,
          [requesterId, userId],
        );
        isBlocked = bRows.length > 0;
      } catch {
        isBlocked = false;
      }
    }

    // 공개 응답: isSingleParent 는 절대 포함하지 않는다 (한부모 전용 방 내부에서만 노출).
    return {
      id: user.id,
      nickname: user.nickname,
      regionSigungu: user.regionSigungu,
      profileImageUrl: user.profileImageUrl,
      introduction: user.introduction,
      parentGender: user.parentGender,
      children: user.children?.map((child) => ({
        nickname: child.nickname,
        ageMonths: this.calculateAgeMonths(child.birthYear, child.birthMonth),
        gender: child.gender,
        napTime: child.napTime ?? null,
        temperamentTags: child.temperamentTags ?? [],
      })),
      roomCount,
      mannerScore: Number(user.mannerScore),
      mannerTags,
      noShowLevel,
      isFollowing,
      isBlocked,
      createdAt: user.createdAt,
    };
  }

  // ─── 관리자 정정 ───
  async adminCorrectIdentity(
    userId: string,
    parentGender: 'MOM' | 'DAD' | null,
    isSingleParent: boolean,
  ) {
    const user = await this.userRepository.findOne({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('사용자를 찾을 수 없습니다.');
    }
    if (parentGender !== null && parentGender !== 'MOM' && parentGender !== 'DAD') {
      throw new BadRequestException('parentGender 는 MOM | DAD | null 만 허용됩니다.');
    }
    user.parentGender = parentGender as string;
    user.isSingleParent = isSingleParent === true;
    await this.userRepository.save(user);
    return {
      id: user.id,
      parentGender: user.parentGender,
      isSingleParent: user.isSingleParent,
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

  /** 정지(SUSPENDED) 해제 요청용 증거 사진 제출. */
  async submitAppeal(userId: string, photoUrl: string) {
    const user = await this.userRepository.findOne({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('사용자를 찾을 수 없습니다.');
    }
    user.appealPhotoUrl = photoUrl;
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
