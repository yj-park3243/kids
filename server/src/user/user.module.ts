import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { UserController } from './user.controller';
import { UserService } from './user.service';
import { User } from './entities/user.entity';
import { Child } from '../child/entities/child.entity';
import { RoomMember } from '../room/entities/room-member.entity';

@Module({
  imports: [TypeOrmModule.forFeature([User, Child, RoomMember])],
  controllers: [UserController],
  providers: [UserService],
  exports: [UserService],
})
export class UserModule {}
