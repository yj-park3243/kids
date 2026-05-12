import { Module, forwardRef } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { UserController } from './user.controller';
import { UserService } from './user.service';
import { MannerScoreService } from './manner-score.service';
import { NoShowService } from './no-show.service';
import { User } from './entities/user.entity';
import { Child } from '../child/entities/child.entity';
import { RoomMember } from '../room/entities/room-member.entity';
import { AppleService } from '../auth/social/apple.service';
import { NotificationModule } from '../notification/notification.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([User, Child, RoomMember]),
    forwardRef(() => NotificationModule),
  ],
  controllers: [UserController],
  providers: [UserService, MannerScoreService, NoShowService, AppleService],
  exports: [UserService, MannerScoreService, NoShowService],
})
export class UserModule {}
