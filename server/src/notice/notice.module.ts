import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Notice } from './entities/notice.entity';
import { NoticeService } from './notice.service';
import { NoticeController } from './notice.controller';
import { NoticeAdminController } from './notice-admin.controller';

@Module({
  imports: [TypeOrmModule.forFeature([Notice])],
  controllers: [NoticeController, NoticeAdminController],
  providers: [NoticeService],
  exports: [NoticeService],
})
export class NoticeModule {}
