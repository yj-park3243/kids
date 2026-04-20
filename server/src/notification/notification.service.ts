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
    // Save notification to DB
    const notification = this.notificationRepository.create({
      userId: input.userId,
      type: input.type,
      title: input.title,
      body: input.body,
      data: input.data,
    });
    await this.notificationRepository.save(notification);

    // Send push notification
    await this.sendPush(input.userId, input.title, input.body, input.data);

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
