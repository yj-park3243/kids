import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AppErrorLog } from './entities/app-error-log.entity';
import { SupportInquiry } from './entities/support-inquiry.entity';
import { UserReport } from './entities/user-report.entity';
import { User } from '../user/entities/user.entity';
import {
  CreateErrorLogDto,
  CreateInquiryDto,
  CreateReportDto,
} from './dto/support.dto';
import {
  TelegramService,
  escapeHtml,
} from '../common/services/telegram.service';

// 텔레그램 알림에서 제외할 노이즈 패턴 (4xx, 인증 실패, 네트워크 끊김 등)
const TELEGRAM_NOISE_PATTERNS: RegExp[] = [
  /\b401\b/,
  /\b403\b/,
  /\b404\b/,
  /\b409\b/,
  /\b422\b/,
  /AUTH_\d+/,
  /no_refresh_token/i,
  /Network is unreachable/i,
  /Connection (closed|refused|reset)/i,
  /SocketException/i,
  /Failed host lookup/i,
  /CERTIFICATE_VERIFY_FAILED/i,
  /User (canceled|cancelled)/i,
];

function isNoise(message: string): boolean {
  return TELEGRAM_NOISE_PATTERNS.some((re) => re.test(message));
}

@Injectable()
export class SupportService {
  private readonly logger = new Logger(SupportService.name);

  constructor(
    @InjectRepository(AppErrorLog)
    private errorRepo: Repository<AppErrorLog>,
    @InjectRepository(SupportInquiry)
    private inquiryRepo: Repository<SupportInquiry>,
    @InjectRepository(UserReport)
    private reportRepo: Repository<UserReport>,
    @InjectRepository(User)
    private userRepo: Repository<User>,
    private telegramService: TelegramService,
  ) {}

  async createErrorLog(userId: string | null, dto: CreateErrorLogDto) {
    try {
      const log = await this.errorRepo.save(
        this.errorRepo.create({
          userId,
          errorMessage: dto.errorMessage,
          stackTrace: dto.stackTrace ?? null,
          deviceInfo: dto.deviceInfo ?? null,
          screenName: dto.screenName ?? null,
        }),
      );

      if (!isNoise(dto.errorMessage)) {
        void this.telegramService.sendAdminAlert(
          `🛑 <b>앱 에러</b>\n` +
            `• 화면: ${escapeHtml(dto.screenName ?? '-')}\n` +
            `• userId: ${userId ? `<code>${escapeHtml(userId)}</code>` : '-'}\n` +
            `• message: ${escapeHtml(dto.errorMessage.slice(0, 500))}` +
            (dto.stackTrace
              ? `\n• stack:\n<pre>${escapeHtml(dto.stackTrace.slice(0, 1500))}</pre>`
              : ''),
        );
      }
      return { id: log.id };
    } catch (err) {
      // 에러 로깅 자체 실패해도 클라에 에러 반환하지 않음 (신뢰성)
      this.logger.error(
        `Failed to save error log: ${(err as Error).message}`,
      );
      return { id: null };
    }
  }

  async createInquiry(userId: string, dto: CreateInquiryDto) {
    const inquiry = await this.inquiryRepo.save(
      this.inquiryRepo.create({
        userId,
        subject: dto.subject,
        message: dto.message,
      }),
    );

    const user = await this.userRepo.findOne({ where: { id: userId } });
    void this.telegramService.sendAdminAlert(
      `💬 <b>1:1 문의</b>\n` +
        `• 작성자: ${escapeHtml(user?.nickname ?? '-')} (<code>${escapeHtml(userId)}</code>)\n` +
        `• 이메일: ${escapeHtml(user?.email ?? '-')}\n` +
        `• 제목: ${escapeHtml(dto.subject)}\n` +
        `• 내용:\n<pre>${escapeHtml(dto.message.slice(0, 1500))}</pre>`,
    );

    return { id: inquiry.id };
  }

  async createReport(reporterId: string, dto: CreateReportDto) {
    const report = await this.reportRepo.save(
      this.reportRepo.create({
        reporterId,
        targetUserId: dto.targetUserId ?? null,
        targetRoomId: dto.targetRoomId ?? null,
        reason: dto.reason,
        detail: dto.detail ?? null,
      }),
    );

    const reporter = await this.userRepo.findOne({ where: { id: reporterId } });
    const target = dto.targetUserId
      ? await this.userRepo.findOne({ where: { id: dto.targetUserId } })
      : null;

    void this.telegramService.sendAdminAlert(
      `🚨 <b>신고 접수</b>\n` +
        `• 신고자: ${escapeHtml(reporter?.nickname ?? '-')} (<code>${escapeHtml(reporterId)}</code>)\n` +
        (target
          ? `• 대상 유저: ${escapeHtml(target.nickname ?? '-')} (<code>${escapeHtml(target.id)}</code>)\n`
          : '') +
        (dto.targetRoomId
          ? `• 대상 방: <code>${escapeHtml(dto.targetRoomId)}</code>\n`
          : '') +
        `• 사유: ${escapeHtml(dto.reason)}\n` +
        (dto.detail
          ? `• 상세:\n<pre>${escapeHtml(dto.detail.slice(0, 1500))}</pre>`
          : ''),
    );

    return { id: report.id };
  }
}
