import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { NotificationController } from './notification.controller';
import { NotificationService } from './notification.service';
import { Notification } from './entities/notification.entity';
import { DeviceToken } from './entities/device-token.entity';
import { PushLog } from './entities/push-log.entity';
import { User } from '../user/entities/user.entity';
import { PushLogCleanupService } from './push-log-cleanup.service';
import { FirebaseModule } from '../firebase/firebase.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([Notification, DeviceToken, PushLog, User]),
    FirebaseModule,
  ],
  controllers: [NotificationController],
  providers: [NotificationService, PushLogCleanupService],
  exports: [NotificationService],
})
export class NotificationModule {}
