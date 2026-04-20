import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In, LessThanOrEqual } from 'typeorm';
import { Room } from './entities/room.entity';

@Injectable()
export class RoomSchedulerService {
  private readonly logger = new Logger(RoomSchedulerService.name);

  constructor(
    @InjectRepository(Room)
    private roomRepository: Repository<Room>,
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
        await this.roomRepository.save(room);
        this.logger.log(`Room ${room.id} transitioned to COMPLETED`);
      }
    }
  }
}
