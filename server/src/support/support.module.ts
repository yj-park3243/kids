import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { JwtModule } from '@nestjs/jwt';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { AppErrorLog } from './entities/app-error-log.entity';
import { SupportInquiry } from './entities/support-inquiry.entity';
import { UserReport } from './entities/user-report.entity';
import { User } from '../user/entities/user.entity';
import { SupportService } from './support.service';
import { SupportController } from './support.controller';

@Module({
  imports: [
    TypeOrmModule.forFeature([AppErrorLog, SupportInquiry, UserReport, User]),
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => ({
        secret: configService.get('JWT_SECRET'),
      }),
    }),
  ],
  controllers: [SupportController],
  providers: [SupportService],
})
export class SupportModule {}
