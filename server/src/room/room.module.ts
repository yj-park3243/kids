import { Module, forwardRef } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { RoomController } from './room.controller';
import { RoomAttendanceController } from './room-attendance.controller';
import { RoomService } from './room.service';
import { RoomParticipationService } from './room-participation.service';
import { RoomSchedulerService } from './room-scheduler.service';
import { RoomVisibilityService } from './room-visibility.service';
import { RoomAttendanceService } from './room-attendance.service';
import { Room } from './entities/room.entity';
import { RoomMember } from './entities/room-member.entity';
import { JoinRequest } from './entities/join-request.entity';
import { User } from '../user/entities/user.entity';
import { Child } from '../child/entities/child.entity';
import { ChatModule } from '../chat/chat.module';
import { NotificationModule } from '../notification/notification.module';
import { UserModule } from '../user/user.module';
import { BlockModule } from '../block/block.module';
import { FollowModule } from '../follow/follow.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([Room, RoomMember, JoinRequest, User, Child]),
    forwardRef(() => ChatModule),
    forwardRef(() => NotificationModule),
    forwardRef(() => UserModule),
    forwardRef(() => BlockModule),
    forwardRef(() => FollowModule),
  ],
  controllers: [RoomController, RoomAttendanceController],
  providers: [
    RoomService,
    RoomParticipationService,
    RoomSchedulerService,
    RoomVisibilityService,
    RoomAttendanceService,
  ],
  exports: [RoomService, RoomParticipationService],
})
export class RoomModule {}
