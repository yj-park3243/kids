import { Inject, Injectable, Logger, forwardRef } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In, LessThanOrEqual } from 'typeorm';
import { Room } from './entities/room.entity';
import { RoomMember } from './entities/room-member.entity';
import { NotificationService } from '../notification/notification.service';

@Injectable()
export class RoomSchedulerService {
  private readonly logger = new Logger(RoomSchedulerService.name);

  constructor(
    @InjectRepository(Room)
    private roomRepository: Repository<Room>,
    @InjectRepository(RoomMember)
    private roomMemberRepository: Repository<RoomMember>,
    @Inject(forwardRef(() => NotificationService))
    private notificationService: NotificationService,
  ) {}

  // Run every 5 minutes
  @Cron('*/5 * * * *')
  async handleRoomStatusTransitions() {
    const now = new Date();
    const currentDate = now.toISOString().split('T')[0];
    const currentTime = now.toTimeString().split(' ')[0].substring(0, 5); // HH:mm

    // RECRUITING/CLOSED -> IN_PROGRESS (start time reached)
    const toInProgress = await this.roomRepository
      .createQueryBuilder('room')
      .where('room.status IN (:...statuses)', {
        statuses: ['RECRUITING', 'CLOSED'],
      })
      .andWhere('room.date <= :date', { date: currentDate })
      .andWhere('room.startTime <= :time', { time: currentTime })
      .getMany();

    for (const room of toInProgress) {
      // Only if date has passed or same date and time has passed
      const roomDate = new Date(room.date + 'T' + room.startTime);
      if (roomDate <= now) {
        room.status = 'IN_PROGRESS';
        await this.roomRepository.save(room);
        this.logger.log(`Room ${room.id} transitioned to IN_PROGRESS`);
      }
    }

    // IN_PROGRESS -> COMPLETED (end time reached or 3 hours after start)
    const inProgressRooms = await this.roomRepository.find({
      where: { status: 'IN_PROGRESS' },
    });

    for (const room of inProgressRooms) {
      let shouldComplete = false;

      if (room.endTime) {
        const endDateTime = new Date(room.date + 'T' + room.endTime);
        shouldComplete = endDateTime <= now;
      } else {
        // 3 hours after start
        const startDateTime = new Date(room.date + 'T' + room.startTime);
        const threeHoursLater = new Date(startDateTime.getTime() + 3 * 60 * 60 * 1000);
        shouldComplete = threeHoursLater <= now;
      }

      if (shouldComplete) {
        room.status = 'COMPLETED';
        room.completedAt = new Date();
        await this.roomRepository.save(room);
        this.logger.log(`Room ${room.id} transitioned to COMPLETED`);
        // 종료 직후 1회 REVIEW_REQUEST 발송 (fire-and-forget)
        void this.dispatchReviewRequest(room.id, room.title).catch(() => undefined);
      }
    }
  }

  // 매 시각 정각 — 종료 +6일(D+6) 멤버 중 후기 미작성자에게 리마인드.
  @Cron('0 0 * * * *')
  async handleReviewReminders() {
    const since = new Date(Date.now() - 6 * 24 * 60 * 60 * 1000 - 60 * 60 * 1000);
    const until = new Date(Date.now() - 6 * 24 * 60 * 60 * 1000);
    const rooms = await this.roomRepository
      .createQueryBuilder('room')
      .where('room.status = :s', { s: 'COMPLETED' })
      .andWhere('room.completedAt BETWEEN :since AND :until', { since, until })
      .getMany();
    for (const room of rooms) {
      await this.dispatchReviewRequest(room.id, room.title, /*excludeReviewed*/ true);
    }
  }

  private async dispatchReviewRequest(
    roomId: string,
    roomTitle: string,
    excludeReviewed = false,
  ) {
    const members = await this.roomMemberRepository.find({ where: { roomId } });
    let reviewedIds = new Set<string>();
    if (excludeReviewed) {
      try {
        const rows = await this.roomRepository.query(
          `SELECT DISTINCT author_id AS "userId" FROM review WHERE room_id = $1`,
          [roomId],
        );
        reviewedIds = new Set(rows.map((r: { userId: string }) => r.userId));
      } catch {
        reviewedIds = new Set();
      }
    }
    const deadline = new Date(Date.now() + 24 * 60 * 60 * 1000);
    for (const m of members) {
      if (reviewedIds.has(m.userId)) continue;
      try {
        await this.notificationService.create({
          userId: m.userId,
          type: 'REVIEW_REQUEST',
          title: '후기 작성 요청',
          body: `[${roomTitle}] 모임은 어땠나요? 매너 점수를 남겨주세요.`,
          data: { roomId, reviewableUntil: deadline.toISOString() },
        });
      } catch (e) {
        this.logger.warn(`failed to push REVIEW_REQUEST to ${m.userId}: ${(e as Error).message}`);
      }
    }
  }
}
