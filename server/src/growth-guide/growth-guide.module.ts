import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { GrowthGuide } from './entities/growth-guide.entity';
import { Child } from '../child/entities/child.entity';
import { Room } from '../room/entities/room.entity';
import { GrowthGuideService } from './growth-guide.service';
import { GrowthSchedulerService } from './growth-scheduler.service';
import { GrowthGuideController } from './growth-guide.controller';
import { GrowthGuideAdminController } from './growth-guide-admin.controller';
import { NotificationModule } from '../notification/notification.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([GrowthGuide, Child, Room]),
    NotificationModule,
  ],
  controllers: [GrowthGuideController, GrowthGuideAdminController],
  providers: [GrowthGuideService, GrowthSchedulerService],
  exports: [GrowthGuideService],
})
export class GrowthGuideModule {}
