import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { JwtModule } from '@nestjs/jwt';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { AppVersion } from './entities/app-version.entity';
import { AppVersionCheckLog } from './entities/app-version-check-log.entity';
import { User } from '../user/entities/user.entity';
import { VersionController } from './version.controller';
import { VersionAdminController } from './version-admin.controller';
import { VersionService } from './version.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([AppVersion, AppVersionCheckLog, User]),
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => ({
        secret: configService.get('JWT_SECRET'),
      }),
    }),
  ],
  controllers: [VersionController, VersionAdminController],
  providers: [VersionService],
  exports: [VersionService],
})
export class VersionModule {}
