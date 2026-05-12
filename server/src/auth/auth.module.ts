import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { JwtStrategy } from './strategies/jwt.strategy';
import { KakaoService } from './social/kakao.service';
import { AppleService } from './social/apple.service';
import { GoogleService } from './social/google.service';
import { KcpController } from './kcp/kcp.controller';
import { KcpService } from './kcp/kcp.service';
import { User } from '../user/entities/user.entity';
import { RefreshToken } from './entities/refresh-token.entity';
import { SocialAccount } from './entities/social-account.entity';
import { TokenService } from './token.service';
import { VersionModule } from '../version/version.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([User, RefreshToken, SocialAccount]),
    VersionModule,
    PassportModule.register({ defaultStrategy: 'jwt' }),
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => ({
        secret: configService.get('JWT_SECRET'),
        signOptions: {
          expiresIn: configService.get('JWT_ACCESS_EXPIRES', '1h'),
        },
      }),
    }),
  ],
  controllers: [AuthController, KcpController],
  providers: [
    AuthService,
    JwtStrategy,
    KakaoService,
    AppleService,
    GoogleService,
    KcpService,
    TokenService,
  ],
  exports: [AuthService, KcpService, TokenService, JwtModule, PassportModule],
})
export class AuthModule {}
