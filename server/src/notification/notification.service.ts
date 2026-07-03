import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Notification } from './entities/notification.entity';
import { DeviceToken } from './entities/device-token.entity';
import { PushLog } from './entities/push-log.entity';
import { User } from '../user/entities/user.entity';
import { FirebaseAdminService } from '../firebase/firebase-admin.service';

interface CreateNotificationInput {
  userId: string;
  type: string;
  title: string;
  body: string;
  data?: any;
  // false 면 인앱 알림 목록(notification 테이블)에 저장하지 않고 푸시만 보낸다.
  // 채팅처럼 빈도가 높아 알림함을 더럽히면 안 되는 타입에 사용.
  persist?: boolean;
}

// 알림 설정 카테고리 매핑. 여기 없는 type 은 notifyAll 로만 게이팅(시스템 알림).
const ROOM_TYPES = new Set([
  'JOIN_REQUEST',
  'JOIN_ACCEPTED',
  'JOIN_REJECTED',
  'ROOM_CANCELLED',
  'ROOM_COMPLETED',
  'ROOM_REMINDER',
  'NEW_ROOM',
  'NEW_FLASH',
  'REVIEW_REQUEST',
  'FOLLOW_NEW_ROOM',
  'NEW_PHOTO',
  'PHOTO_COMMENT',
  'PHOTO_TAG',
]);
const CHAT_TYPES = new Set(['NEW_CHAT']);

// 신규 type 알림용 기본 템플릿 (호출자가 title/body 안 넘기면 fallback).
export function defaultTemplate(
  type: string,
  data?: any,
): { title: string; body: string } | null {
  switch (type) {
    case 'NEW_FLASH':
      return { title: '번개 모임 등록', body: '근처 번개 모임이 등록되었어요.' };
    case 'REVIEW_REQUEST':
      return { title: '후기 작성 요청', body: '모임은 어땠나요? 매너 점수를 남겨주세요.' };
    case 'FOLLOW_NEW_ROOM':
      return { title: '단골 부모의 새 방', body: '팔로우 중인 부모가 새 방을 만들었어요.' };
    case 'NOSHOW_WARNING':
      return { title: '노쇼 경고', body: '노쇼가 누적되었어요. 3회 도달 시 참여가 제한됩니다.' };
    case 'REPORT_RESOLVED':
      return { title: '신고 처리 결과', body: '신고하신 건이 처리되었어요.' };
    default:
      return null;
  }
}

// FCM data 페이로드는 모든 값이 string 이어야 한다. null/undefined 는 제외하고
// 숫자 등은 문자열로 변환해 평평하게 내려보낸다.
function stringifyData(obj: Record<string, any>): Record<string, string> {
  const out: Record<string, string> = {};
  for (const [k, v] of Object.entries(obj)) {
    if (v === null || v === undefined) continue;
    out[k] = typeof v === 'string' ? v : String(v);
  }
  return out;
}

@Injectable()
export class NotificationService {
  private readonly logger = new Logger(NotificationService.name);

  constructor(
    @InjectRepository(Notification)
    private notificationRepository: Repository<Notification>,
    @InjectRepository(DeviceToken)
    private deviceTokenRepository: Repository<DeviceToken>,
    @InjectRepository(PushLog)
    private pushLogRepository: Repository<PushLog>,
    @InjectRepository(User)
    private userRepository: Repository<User>,
    private firebaseAdminService: FirebaseAdminService,
  ) {}

  async create(input: CreateNotificationInput) {
    // title/body 가 비어있으면 type 별 기본 템플릿으로 폴백
    let title = input.title;
    let body = input.body;
    if (!title || !body) {
      const tpl = defaultTemplate(input.type, input.data);
      if (tpl) {
        title = title || tpl.title;
        body = body || tpl.body;
      }
    }

    // Save notification to DB (persist:false 면 푸시만)
    let notification: Notification | null = null;
    if (input.persist !== false) {
      notification = this.notificationRepository.create({
        userId: input.userId,
        type: input.type,
        title,
        body,
        data: input.data,
      });
      await this.notificationRepository.save(notification);
    }

    // Send push notification
    await this.sendPush(input.userId, input.type, title, body, {
      type: input.type,
      ...input.data,
    });

    return notification;
  }

  async getSettings(userId: string) {
    const user = await this.userRepository.findOne({
      where: { id: userId },
      select: ['id', 'notifyAll', 'notifyRoom', 'notifyChat'],
    });
    return {
      notifyAll: user?.notifyAll ?? true,
      notifyRoom: user?.notifyRoom ?? true,
      notifyChat: user?.notifyChat ?? true,
    };
  }

  async updateSettings(
    userId: string,
    patch: { notifyAll?: boolean; notifyRoom?: boolean; notifyChat?: boolean },
  ) {
    const fields: Partial<User> = {};
    if (patch.notifyAll !== undefined) fields.notifyAll = patch.notifyAll;
    if (patch.notifyRoom !== undefined) fields.notifyRoom = patch.notifyRoom;
    if (patch.notifyChat !== undefined) fields.notifyChat = patch.notifyChat;
    if (Object.keys(fields).length > 0) {
      await this.userRepository.update({ id: userId }, fields);
    }
    return this.getSettings(userId);
  }

  async registerDeviceToken(userId: string, token: string, platform: string) {
    // Upsert device token
    const existing = await this.deviceTokenRepository.findOne({
      where: { userId, token },
    });

    if (existing) {
      existing.platform = platform;
      return this.deviceTokenRepository.save(existing);
    }

    const deviceToken = this.deviceTokenRepository.create({
      userId,
      token,
      platform,
    });
    return this.deviceTokenRepository.save(deviceToken);
  }

  async findAll(userId: string, cursor?: string, limit: number = 20) {
    const qb = this.notificationRepository
      .createQueryBuilder('notification')
      .where('notification.userId = :userId', { userId })
      .orderBy('notification.createdAt', 'DESC');

    if (cursor) {
      const cursorNotification = await this.notificationRepository.findOne({
        where: { id: cursor },
      });
      if (cursorNotification) {
        qb.andWhere('notification.createdAt < :cursorDate', {
          cursorDate: cursorNotification.createdAt,
        });
      }
    }

    qb.take(limit + 1);

    const notifications = await qb.getMany();
    const hasMore = notifications.length > limit;
    if (hasMore) notifications.pop();

    return {
      items: notifications,
      nextCursor:
        hasMore && notifications.length > 0
          ? notifications[notifications.length - 1].id
          : null,
      hasMore,
    };
  }

  async markAsRead(userId: string, notificationId: string) {
    const notification = await this.notificationRepository.findOne({
      where: { id: notificationId, userId },
    });

    if (!notification) {
      throw new NotFoundException('알림을 찾을 수 없습니다.');
    }

    notification.isRead = true;
    return this.notificationRepository.save(notification);
  }

  async markAllAsRead(userId: string) {
    await this.notificationRepository.update(
      { userId, isRead: false },
      { isRead: true },
    );
    return { success: true };
  }

  async getUnreadCount(userId: string) {
    const count = await this.notificationRepository.count({
      where: { userId, isRead: false },
    });
    return { count };
  }

  private async sendPush(
    userId: string,
    type: string,
    title: string,
    body: string,
    data?: any,
  ) {
    // 모든 시도/결과를 push_log 에 한 행씩 — 7일 보관 후 자동 삭제.
    const log = this.pushLogRepository.create({
      userId,
      type,
      title: title.slice(0, 200),
      body: body.slice(0, 500),
      tokenCount: 0,
      successCount: 0,
      failureCount: 0,
      skipReason: null,
      errorMessage: null,
    });

    try {
      const messaging = this.firebaseAdminService.getMessaging();
      if (!messaging) {
        log.skipReason = 'messaging_unavailable';
        await this.pushLogRepository.save(log);
        return;
      }

      // 모임·채팅 등 서비스 알림은 사용자가 끌 수 없다(항상 발송).
      // 광고/마케팅 알림 타입이 생기면 그때 notifyAll(광고 수신 동의)로만 게이팅한다.

      const tokens = await this.deviceTokenRepository.find({
        where: { userId },
      });
      log.tokenCount = tokens.length;

      if (tokens.length === 0) {
        log.skipReason = 'no_device_tokens';
        await this.pushLogRepository.save(log);
        return;
      }

      const message = {
        notification: { title, body },
        // FCM data 값은 전부 문자열이어야 한다. 앱은 평평한 키(type/roomId/chatRoomId)를
        // 직접 읽으므로 nesting 없이 펼쳐 보낸다.
        data: data ? stringifyData(data) : undefined,
        tokens: tokens.map((t) => t.token),
      };

      const response = await messaging.sendEachForMulticast(message);
      log.successCount = response.successCount;
      log.failureCount = response.failureCount;

      // Remove invalid tokens
      if (response.failureCount > 0) {
        const failedTokens: string[] = [];
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            failedTokens.push(tokens[idx].token);
          }
        });
        if (failedTokens.length > 0) {
          await this.deviceTokenRepository
            .createQueryBuilder()
            .delete()
            .where('token IN (:...tokens)', { tokens: failedTokens })
            .execute();
        }
      }
      await this.pushLogRepository.save(log);
    } catch (error) {
      this.logger.error('Failed to send push notification', error);
      log.errorMessage = String(error?.message ?? error).slice(0, 500);
      try {
        await this.pushLogRepository.save(log);
      } catch {
        // 로그 저장조차 실패해도 메인 흐름은 건드리지 않는다.
      }
    }
  }
}
