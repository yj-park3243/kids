import {
  Injectable,
  UnauthorizedException,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { In } from 'typeorm';
import { User } from '../user/entities/user.entity';
import { UserVisit } from '../user/entities/user-visit.entity';
import { Room } from '../room/entities/room.entity';
import { Child } from '../child/entities/child.entity';
import { UserReport } from '../support/entities/user-report.entity';
import { SupportInquiry } from '../support/entities/support-inquiry.entity';
import { AdminLoginDto } from './dto/admin-login.dto';
import {
  AdminUserQueryDto,
  AdminRoomQueryDto,
  AdminReportQueryDto,
  AdminInquiryQueryDto,
  ResolveReportDto,
  ReplyInquiryDto,
} from './dto/admin-query.dto';
import { UserService } from '../user/user.service';

const ONLINE_THRESHOLD_MIN = 5;

@Injectable()
export class AdminService {
  constructor(
    @InjectRepository(User)
    private userRepository: Repository<User>,
    @InjectRepository(UserVisit)
    private visitRepository: Repository<UserVisit>,
    @InjectRepository(Room)
    private roomRepository: Repository<Room>,
    @InjectRepository(Child)
    private childRepository: Repository<Child>,
    @InjectRepository(UserReport)
    private reportRepository: Repository<UserReport>,
    @InjectRepository(SupportInquiry)
    private inquiryRepository: Repository<SupportInquiry>,
    private jwtService: JwtService,
    private userService: UserService,
  ) {}

  async correctIdentity(
    userId: string,
    parentGender: 'MOM' | 'DAD' | null,
    isSingleParent: boolean,
  ) {
    return this.userService.adminCorrectIdentity(userId, parentGender, isSingleParent);
  }

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
      type: 'access',
    };

    const accessToken = this.jwtService.sign(payload, {
      expiresIn: '8h',
      issuer: 'kids-app',
    });

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
    const now = new Date();
    const today = new Date(now);
    today.setHours(0, 0, 0, 0);

    const sevenDaysAgo = new Date(today);
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

    const thirtyDaysAgo = new Date(today);
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 29); // 오늘 포함 30일

    const todayDateStr = today.toISOString().slice(0, 10);
    const onlineCutoff = new Date(now.getTime() - ONLINE_THRESHOLD_MIN * 60_000);

    const [
      totalUsers,
      totalRooms,
      todayUsers,
      todayRooms,
      activeRooms,
      bannedUsers,
      currentOnline,
      todayVisitors,
      last7DaysSignups,
      signupTrendRows,
      visitorTrendRows,
      roomTrendRows,
      reportsPendingRows,
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
      this.userRepository
        .createQueryBuilder('user')
        .where('user.lastSeenAt >= :cutoff', { cutoff: onlineCutoff })
        .getCount(),
      this.visitRepository
        .createQueryBuilder('v')
        .where('v.visitDate = :d', { d: todayDateStr })
        .getCount(),
      this.userRepository
        .createQueryBuilder('user')
        .where('user.createdAt >= :since', { since: sevenDaysAgo })
        .getCount(),
      this.userRepository
        .createQueryBuilder('u')
        .select(`TO_CHAR(u.created_at AT TIME ZONE 'Asia/Seoul', 'YYYY-MM-DD')`, 'date')
        .addSelect('COUNT(*)', 'count')
        .where('u.created_at >= :since', { since: thirtyDaysAgo })
        .groupBy(`TO_CHAR(u.created_at AT TIME ZONE 'Asia/Seoul', 'YYYY-MM-DD')`)
        .orderBy(`TO_CHAR(u.created_at AT TIME ZONE 'Asia/Seoul', 'YYYY-MM-DD')`, 'ASC')
        .getRawMany<{ date: string; count: string }>(),
      this.visitRepository
        .createQueryBuilder('v')
        .select(`TO_CHAR(v.visit_date, 'YYYY-MM-DD')`, 'date')
        .addSelect('COUNT(*)', 'count')
        .where('v.visit_date >= :since', { since: thirtyDaysAgo })
        .groupBy('v.visit_date')
        .orderBy('v.visit_date', 'ASC')
        .getRawMany<{ date: string; count: string }>(),
      // QueryBuilder 가 ORDER BY 시 hidden column 을 주입해서 GROUP BY 위반이
      // 발생한 이력이 있어 raw SQL 로 작성. count 도 int 로 cast.
      this.roomRepository.query(
        `SELECT TO_CHAR(created_at AT TIME ZONE 'Asia/Seoul', 'YYYY-MM-DD') AS date,
                COUNT(*)::int AS count
         FROM room
         WHERE created_at >= $1
         GROUP BY 1
         ORDER BY 1 ASC`,
        [thirtyDaysAgo],
      ) as Promise<{ date: string; count: string }[]>,
      // 신규 report 테이블 PENDING 카운트 (테이블 미존재 시 0)
      this.roomRepository
        .query(`SELECT COUNT(*)::int AS c FROM report WHERE status = 'PENDING'`)
        .catch(() => [{ c: 0 }]) as Promise<{ c: number }[]>,
    ]);

    const reportsPending = reportsPendingRows?.[0]?.c ?? 0;

    return {
      // 회원
      totalUsers,
      todayUsers,
      last7DaysSignups,
      bannedUsers,
      // 활성/접속
      currentOnline,
      todayVisitors,
      // 모임
      totalRooms,
      activeRooms,
      todayRooms,
      // 신고
      reportsPending,
      // 추이 (오늘 포함 최근 30일, YYYY-MM-DD ASC)
      signupTrend: signupTrendRows.map((r) => ({
        date: r.date,
        count: parseInt(r.count, 10),
      })),
      visitorTrend: visitorTrendRows.map((r) => ({
        date: r.date,
        count: parseInt(r.count, 10),
      })),
      roomTrend: roomTrendRows.map((r) => ({
        date: r.date,
        count: parseInt(r.count, 10),
      })),
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

  async setPhoneVerified(userId: string, isPhoneVerified: boolean) {
    const user = await this.userRepository.findOne({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('사용자를 찾을 수 없습니다.');
    }

    await this.userRepository.update(userId, {
      isPhoneVerified,
      // KCP 본인인증 통과로도 간주: isVerified + verifiedAt 동기화
      isVerified: isPhoneVerified ? true : user.isVerified,
      verifiedAt: isPhoneVerified ? user.verifiedAt ?? new Date() : user.verifiedAt,
    });

    return { success: true, isPhoneVerified };
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

  // ─── 신고 ─────────────────────────────────────────────────────────

  async getReports(query: AdminReportQueryDto) {
    const page = query.page || 1;
    const limit = query.limit || 20;
    const skip = (page - 1) * limit;

    const qb = this.reportRepository
      .createQueryBuilder('r')
      .orderBy('r.createdAt', 'DESC');

    if (query.status) qb.andWhere('r.status = :status', { status: query.status });
    if (query.reason) qb.andWhere('r.reason = :reason', { reason: query.reason });

    const [reports, total] = await qb.skip(skip).take(limit).getManyAndCount();

    const userIds = Array.from(
      new Set(
        reports
          .flatMap((r) => [r.reporterId, r.targetUserId])
          .filter((v): v is string => !!v),
      ),
    );
    const users = userIds.length
      ? await this.userRepository.find({ where: { id: In(userIds) } })
      : [];
    const userMap = new Map(users.map((u) => [u.id, { id: u.id, nickname: u.nickname, email: u.email }]));

    return {
      items: reports.map((r) => ({
        id: r.id,
        reason: r.reason,
        status: r.status,
        detail: r.detail,
        createdAt: r.createdAt,
        reporter: userMap.get(r.reporterId) ?? { id: r.reporterId },
        targetUser: r.targetUserId ? userMap.get(r.targetUserId) ?? { id: r.targetUserId } : null,
        targetRoomId: r.targetRoomId,
      })),
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    };
  }

  async getReport(reportId: string) {
    const report = await this.reportRepository.findOne({ where: { id: reportId } });
    if (!report) {
      throw new NotFoundException('신고를 찾을 수 없습니다.');
    }

    const ids = [report.reporterId, report.targetUserId].filter(
      (v): v is string => !!v,
    );
    const users = ids.length
      ? await this.userRepository.find({ where: { id: In(ids) } })
      : [];
    const userMap = new Map(users.map((u) => [u.id, { id: u.id, nickname: u.nickname, email: u.email }]));

    let targetRoom: { id: string; title: string } | null = null;
    if (report.targetRoomId) {
      const room = await this.roomRepository.findOne({ where: { id: report.targetRoomId } });
      if (room) targetRoom = { id: room.id, title: room.title };
    }

    return {
      id: report.id,
      reason: report.reason,
      status: report.status,
      detail: report.detail,
      adminAction: report.adminAction,
      adminNote: report.adminNote,
      resolvedAt: report.resolvedAt,
      createdAt: report.createdAt,
      reporter: userMap.get(report.reporterId) ?? { id: report.reporterId },
      targetUser: report.targetUserId
        ? userMap.get(report.targetUserId) ?? { id: report.targetUserId }
        : null,
      targetRoom,
    };
  }

  /**
   * 신고 처리 — 상태 변경 + 관리자 조치/메모 기록.
   * adminAction 이 BAN_* 이면 신고 대상 유저를 ban 시키는 게 자연스럽지만,
   * 별도 ban 엔드포인트와 분리해 두고 여기서는 메타만 저장한다.
   */
  async resolveReport(reportId: string, dto: ResolveReportDto) {
    const report = await this.reportRepository.findOne({ where: { id: reportId } });
    if (!report) {
      throw new NotFoundException('신고를 찾을 수 없습니다.');
    }
    report.status = dto.status;
    report.adminAction = dto.adminAction ?? null;
    report.adminNote = dto.adminNote ?? null;
    report.resolvedAt = new Date();
    await this.reportRepository.save(report);
    return { success: true };
  }

  // ─── 문의(1:1) 관리 ─────────────────────────────────────────

  async getInquiries(query: AdminInquiryQueryDto) {
    const page = query.page ?? 1;
    const limit = query.limit ?? 20;
    const qb = this.inquiryRepository
      .createQueryBuilder('i')
      .orderBy('i.created_at', 'DESC');
    if (query.status) qb.andWhere('i.status = :s', { s: query.status });

    const [rows, total] = await qb
      .skip((page - 1) * limit)
      .take(limit)
      .getManyAndCount();

    // user join — 직접 한 번에 fetch.
    const userIds = Array.from(new Set(rows.map((r) => r.userId)));
    const users = userIds.length
      ? await this.userRepository.find({ where: { id: In(userIds) } })
      : [];
    const userMap = new Map(
      users.map((u) => [u.id, { id: u.id, nickname: u.nickname, email: u.email }]),
    );

    return {
      items: rows.map((r) => ({
        id: r.id,
        subject: r.subject,
        message: r.message,
        reply: r.reply,
        status: r.status,
        createdAt: r.createdAt,
        repliedAt: r.repliedAt,
        user: userMap.get(r.userId) ?? { id: r.userId },
      })),
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    };
  }

  async getInquiry(id: string) {
    const inquiry = await this.inquiryRepository.findOne({ where: { id } });
    if (!inquiry) throw new NotFoundException('문의를 찾을 수 없습니다.');
    const user = await this.userRepository.findOne({ where: { id: inquiry.userId } });
    return {
      ...inquiry,
      user: user ? { id: user.id, nickname: user.nickname, email: user.email } : null,
    };
  }

  async replyInquiry(id: string, dto: ReplyInquiryDto) {
    const inquiry = await this.inquiryRepository.findOne({ where: { id } });
    if (!inquiry) throw new NotFoundException('문의를 찾을 수 없습니다.');
    inquiry.reply = dto.reply;
    inquiry.status = dto.status ?? 'REPLIED';
    inquiry.repliedAt = new Date();
    await this.inquiryRepository.save(inquiry);
    return { success: true };
  }
}
