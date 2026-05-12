import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Child } from '../child/entities/child.entity';
import { NotificationService } from '../notification/notification.service';

@Injectable()
export class GrowthSchedulerService {
  private readonly logger = new Logger(GrowthSchedulerService.name);

  constructor(
    @InjectRepository(Child)
    private childRepository: Repository<Child>,
    private notificationService: NotificationService,
  ) {}

  // 매월 1일 02:00
  @Cron('0 0 2 1 * *')
  async handleMonthlyGrowthUpdate() {
    const now = new Date();
    const currentYear = now.getFullYear();
    const currentMonth = now.getMonth() + 1;

    // Last month reference
    const lastDate = new Date(currentYear, currentMonth - 2, 1);
    const lastYear = lastDate.getFullYear();
    const lastMonth = lastDate.getMonth() + 1;

    const children = await this.childRepository.find();

    for (const child of children) {
      const currentAge =
        (currentYear - child.birthYear) * 12 + (currentMonth - child.birthMonth);
      const previousAge =
        (lastYear - child.birthYear) * 12 + (lastMonth - child.birthMonth);

      if (currentAge !== previousAge && currentAge >= 0 && currentAge <= 72) {
        try {
          await this.notificationService.create({
            userId: child.userId,
            type: 'GROWTH_UPDATE',
            title: `${child.nickname}가 ${currentAge}개월에 진입했어요`,
            body: `이 달의 발달 가이드를 확인해 보세요.`,
            data: { childId: child.id, ageMonth: currentAge },
          });
        } catch (err) {
          this.logger.error(
            `Failed to send growth update for child ${child.id}`,
            err as Error,
          );
        }
      }
    }

    this.logger.log(`Monthly growth update completed at ${now.toISOString()}`);
  }
}
