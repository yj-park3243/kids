import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { JwtModule } from '@nestjs/jwt';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { AdminController } from './admin.controller';
import { AdminService } from './admin.service';
import { User } from '../user/entities/user.entity';
import { UserVisit } from '../user/entities/user-visit.entity';
import { Room } from '../room/entities/room.entity';
import { Child } from '../child/entities/child.entity';
import { UserReport } from '../support/entities/user-report.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([User, UserVisit, Room, Child, UserReport]),
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => ({
        secret: configService.get('JWT_SECRET'),
      }),
    }),
  ],
  controllers: [AdminController],
  providers: [AdminService],
})
export class AdminModule {}
