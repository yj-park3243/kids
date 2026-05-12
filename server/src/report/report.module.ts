import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Report } from './entities/report.entity';
import { User } from '../user/entities/user.entity';
import { Room } from '../room/entities/room.entity';
import { ReportService } from './report.service';
import { ReportController } from './report.controller';
import { ReportAdminController } from './report-admin.controller';
import { NotificationModule } from '../notification/notification.module';
import { UserModule } from '../user/user.module';

@Module({
  imports: [TypeOrmModule.forFeature([Report, User, Room]), NotificationModule, UserModule],
  controllers: [ReportController, ReportAdminController],
  providers: [ReportService],
  exports: [ReportService],
})
export class ReportModule {}
