import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Notification } from './entities/notification.entity';
import { DeviceToken } from './entities/device-token.entity';
import { FirebaseAdminService } from '../firebase/firebase-admin.service';

interface CreateNotificationInput {
  userId: string;
  type: string;
  title: string;
  body: string;
  data?: any;
}

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
    case 'GROWTH_UPDATE':
      return { title: '발달 가이드', body: '아이의 새 월령 가이드가 도착했어요.' };
    case 'REPORT_RESOLVED':
      return { title: '신고 처리 결과', body: '신고하신 건이 처리되었어요.' };
    default:
      return null;
  }
}

@Injectable()
export class NotificationService {
  private readonly logger = new Logger(NotificationService.name);

  constructor(
    @InjectRepository(Notification)
    private notificationRepository: Repository<Notification>,
    @InjectRepository(DeviceToken)
    private deviceTokenRepository: Repository<DeviceToken>,
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

    // Save notification to DB
    const notification = this.notificationRepository.create({
      userId: input.userId,
      type: input.type,
      title,
      body,
      data: input.data,
    });
    await this.notificationRepository.save(notification);

    // Send push notification
    await this.sendPush(input.userId, title, body, { type: input.type, ...input.data });

    return notification;
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

  private async sendPush(userId: string, title: string, body: string, data?: any) {
    try {
      const messaging = this.firebaseAdminService.getMessaging();
      if (!messaging) return;

      const tokens = await this.deviceTokenRepository.find({
        where: { userId },
      });

      if (tokens.length === 0) return;

      const message = {
        notification: { title, body },
        data: data ? { payload: JSON.stringify(data) } : undefined,
        tokens: tokens.map((t) => t.token),
      };

      const response = await messaging.sendEachForMulticast(message);

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
    } catch (error) {
      this.logger.error('Failed to send push notification', error);
    }
  }
}
