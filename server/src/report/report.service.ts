import {
  Injectable,
  Logger,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Report } from './entities/report.entity';
import { User } from '../user/entities/user.entity';
import { Room } from '../room/entities/room.entity';
import { CreateReportDto } from './dto/create-report.dto';
import { ResolveReportDto, AdminReportListQueryDto } from './dto/resolve-report.dto';
import { NotificationService } from '../notification/notification.service';
import { MannerScoreService } from '../user/manner-score.service';

@Injectable()
export class ReportService {
  private readonly logger = new Logger(ReportService.name);

  constructor(
    @InjectRepository(Report)
    private reportRepository: Repository<Report>,
    @InjectRepository(User)
    private userRepository: Repository<User>,
    @InjectRepository(Room)
    private roomRepository: Repository<Room>,
    private notificationService: NotificationService,
    private mannerScoreService: MannerScoreService,
  ) {}

  async create(reporterId: string, dto: CreateReportDto) {
    // 자기 자신 신고 방지 (USER 타입만)
    if (dto.targetType === 'USER' && dto.targetId === reporterId) {
      throw new BadRequestException('자기 자신은 신고할 수 없습니다.');
    }

    const report = this.reportRepository.create({
      reporterId,
      targetType: dto.targetType,
      targetId: dto.targetId,
      reason: dto.reason,
      description: dto.description ?? null,
      status: 'PENDING',
    });
    const saved = await this.reportRepository.save(report);

    return {
      id: saved.id,
      status: saved.status,
      createdAt: saved.createdAt,
    };
  }

  async findAllAdmin(query: AdminReportListQueryDto) {
    const page = Number(query.page) || 1;
    const limit = Number(query.limit) || 20;
    const skip = (page - 1) * limit;

    const qb = this.reportRepository
      .createQueryBuilder('r')
      .orderBy('r.createdAt', 'DESC');

    if (query.status) {
      qb.andWhere('r.status = :status', { status: query.status });
    }

    const [items, total] = await qb.skip(skip).take(limit).getManyAndCount();

    return {
      items,
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    };
  }

  async resolveAdmin(reportId: string, adminId: string, dto: ResolveReportDto) {
    const report = await this.reportRepository.findOne({ where: { id: reportId } });
    if (!report) {
      throw new NotFoundException('신고를 찾을 수 없습니다.');
    }

    report.status = dto.status;
    report.adminAction = dto.adminAction;
    report.adminNote = dto.adminNote ?? null;
    report.resolvedBy = adminId;
    report.resolvedAt = new Date();
    await this.reportRepository.save(report);

    // BAN_* 액션이면 신고 대상 유저 status = BANNED
    if (dto.adminAction === 'BAN_7D' || dto.adminAction === 'BAN_PERMANENT') {
      const targetUserId = await this.resolveTargetUserId(report.targetType, report.targetId);
      if (targetUserId) {
        await this.userRepository.update({ id: targetUserId }, { status: 'BANNED' });
      }
    }

    // 신고 인정(RESOLVED) 시 신고 대상 유저의 매너 온도 재계산 (-1.0°C 가산)
    if (dto.status === 'RESOLVED') {
      const targetUserId = await this.resolveTargetUserId(report.targetType, report.targetId);
      if (targetUserId) {
        try {
          await this.mannerScoreService.recalc(targetUserId);
        } catch (e) {
          this.logger.warn(`mannerScore recalc failed for ${targetUserId}: ${(e as Error).message}`);
        }
      }
    }

    // 신고자에게 처리 결과 알림
    try {
      await this.notificationService.create({
        userId: report.reporterId,
        type: 'REPORT_RESOLVED',
        title: '신고 처리 결과',
        body:
          dto.status === 'RESOLVED'
            ? '신고가 처리되었습니다.'
            : '신고가 반려되었습니다.',
        data: { reportId: report.id, status: report.status, adminAction: report.adminAction },
      });
    } catch (e) {
      this.logger.error('Failed to send REPORT_RESOLVED notification', e as Error);
    }

    return report;
  }

  // target_type 에 따른 실제 user_id 해석 (USER → targetId, ROOM → 호스트, CHAT_MESSAGE 는 미지원)
  private async resolveTargetUserId(targetType: string, targetId: string): Promise<string | null> {
    if (targetType === 'USER') return targetId;
    if (targetType === 'ROOM') {
      const room = await this.roomRepository.findOne({ where: { id: targetId } });
      return room?.hostId ?? null;
    }
    return null;
  }
}
