import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AppVersion } from './entities/app-version.entity';
import { VersionController } from './version.controller';
import { VersionService } from './version.service';

@Module({
  imports: [TypeOrmModule.forFeature([AppVersion])],
  controllers: [VersionController],
  providers: [VersionService],
  exports: [VersionService],
})
export class VersionModule {}
