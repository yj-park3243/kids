import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ScheduleModule } from '@nestjs/schedule';
import { APP_INTERCEPTOR, APP_FILTER } from '@nestjs/core';
import { AuthModule } from './auth/auth.module';
import { UserModule } from './user/user.module';
import { ChildModule } from './child/child.module';
import { RoomModule } from './room/room.module';
import { ChatModule } from './chat/chat.module';
import { NotificationModule } from './notification/notification.module';
import { UploadModule } from './upload/upload.module';
import { FirebaseModule } from './firebase/firebase.module';
import { AdminModule } from './admin/admin.module';
import { SupportModule } from './support/support.module';
import { VersionModule } from './version/version.module';
import { RoomPhotoModule } from './room-photo/room-photo.module';
import { ReviewModule } from './review/review.module';
import { ReportModule } from './report/report.module';
import { BlockModule } from './block/block.module';
import { FollowModule } from './follow/follow.module';
import { GrowthGuideModule } from './growth-guide/growth-guide.module';
import { ShareModule } from './share/share.module';
import { ActivityTrackerInterceptor } from './common/interceptors/activity-tracker.interceptor';
import { HttpExceptionFilter } from './common/filters/http-exception.filter';
import { CommonModule } from './common/common.module';
import { User } from './user/entities/user.entity';
import { UserVisit } from './user/entities/user-visit.entity';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: process.env.NODE_ENV === 'production' ? '.env.production' : '.env',
    }),
    TypeOrmModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => ({
        type: 'postgres',
        host: configService.get('DB_HOST'),
        port: configService.get<number>('DB_PORT'),
        username: configService.get('DB_USER'),
        password: configService.get('DB_PASSWORD'),
        database: configService.get('DB_NAME'),
        entities: [__dirname + '/**/*.entity{.ts,.js}'],
        // 아직 운영 전 — 엔티티 변경 자동 반영을 위해 강제로 켜둠.
        synchronize: true,
        logging: configService.get('NODE_ENV') !== 'production',
        ssl: configService.get('NODE_ENV') === 'production'
          ? { rejectUnauthorized: false }
          : false,
      }),
    }),
    ScheduleModule.forRoot(),
    CommonModule,
    TypeOrmModule.forFeature([User, UserVisit]),
    AuthModule,
    UserModule,
    ChildModule,
    RoomModule,
    ChatModule,
    NotificationModule,
    UploadModule,
    FirebaseModule,
    AdminModule,
    SupportModule,
    VersionModule,
    RoomPhotoModule,
    ReviewModule,
    ReportModule,
    BlockModule,
    FollowModule,
    GrowthGuideModule,
    ShareModule,
  ],
  providers: [
    {
      provide: APP_INTERCEPTOR,
      useClass: ActivityTrackerInterceptor,
    },
    {
      provide: APP_FILTER,
      useClass: HttpExceptionFilter,
    },
  ],
})
export class AppModule {}
