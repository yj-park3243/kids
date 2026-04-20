import {
  Injectable,
  UnauthorizedException,
  ConflictException,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as bcrypt from 'bcrypt';
import { User } from '../user/entities/user.entity';
import { RefreshToken } from './entities/refresh-token.entity';
import { SocialLoginDto, AuthProvider } from './dto/social-login.dto';
import { EmailRegisterDto } from './dto/email-register.dto';
import { EmailLoginDto } from './dto/email-login.dto';
import { KakaoService } from './social/kakao.service';
import { AppleService } from './social/apple.service';
import { GoogleService } from './social/google.service';

type PhoneVerificationEntry = { code: string; expiresAt: number; verified: boolean };

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  // In-memory store. Replace with Redis / DB in production.
  private readonly phoneCodes = new Map<string, PhoneVerificationEntry>();
  private readonly PHONE_CODE_TTL_MS = 3 * 60 * 1000;

  constructor(
    @InjectRepository(User)
    private userRepository: Repository<User>,
    @InjectRepository(RefreshToken)
    private refreshTokenRepository: Repository<RefreshToken>,
    private jwtService: JwtService,
    private configService: ConfigService,
    private kakaoService: KakaoService,
    private appleService: AppleService,
    private googleService: GoogleService,
  ) {}

  async socialLogin(dto: SocialLoginDto) {
    let socialUserInfo;

    switch (dto.provider) {
      case AuthProvider.KAKAO:
        if (!dto.accessToken) {
          throw new UnauthorizedException('카카오 로그인에는 accessToken이 필요합니다.');
        }
        socialUserInfo = await this.kakaoService.getUserInfo(dto.accessToken);
        break;
      case AuthProvider.APPLE:
        if (!dto.idToken) {
          throw new UnauthorizedException('Apple 로그인에는 idToken이 필요합니다.');
        }
        socialUserInfo = await this.appleService.getUserInfo(dto.idToken);
        break;
      case AuthProvider.GOOGLE:
        if (!dto.idToken) {
          throw new UnauthorizedException('Google 로그인에는 idToken이 필요합니다.');
        }
        socialUserInfo = await this.googleService.getUserInfo(dto.idToken);
        break;
    }

    // Check if user exists
    let user = await this.userRepository.findOne({
      where: {
        authProvider: dto.provider,
        socialId: socialUserInfo.socialId,
      },
    });

    const isNewUser = !user;

    if (!user) {
      // Create new user
      user = this.userRepository.create({
        authProvider: dto.provider,
        socialId: socialUserInfo.socialId,
        email: socialUserInfo.email,
        isProfileComplete: false,
      });
      user = await this.userRepository.save(user);
    }

    // Check if user is banned
    if (user.status === 'BANNED') {
      throw new UnauthorizedException({
        code: 'USER_BANNED',
        message: '정지된 계정입니다.',
      });
    }

    const tokens = await this.generateTokens(user);

    return {
      ...tokens,
      user: this.sanitizeUser(user),
      isNewUser,
    };
  }

  async emailRegister(dto: EmailRegisterDto) {
    // Check if email already exists
    const existing = await this.userRepository.findOne({
      where: { email: dto.email },
    });

    if (existing) {
      throw new ConflictException({
        code: 'EMAIL_ALREADY_EXISTS',
        message: '이미 사용 중인 이메일입니다.',
      });
    }

    // Hash password
    const passwordHash = await bcrypt.hash(dto.password, 10);

    // Create user
    const user = this.userRepository.create({
      authProvider: 'EMAIL',
      email: dto.email,
      passwordHash,
      isProfileComplete: false,
    });

    const savedUser = await this.userRepository.save(user);
    const tokens = await this.generateTokens(savedUser);

    return {
      ...tokens,
      user: this.sanitizeUser(savedUser),
      isNewUser: true,
    };
  }

  async emailLogin(dto: EmailLoginDto) {
    const user = await this.userRepository.findOne({
      where: { email: dto.email, authProvider: 'EMAIL' },
    });

    if (!user) {
      throw new UnauthorizedException({
        code: 'INVALID_CREDENTIALS',
        message: '이메일 또는 비밀번호가 올바르지 않습니다.',
      });
    }

    if (user.status === 'BANNED') {
      throw new UnauthorizedException({
        code: 'USER_BANNED',
        message: '정지된 계정입니다.',
      });
    }

    const isPasswordValid = await bcrypt.compare(dto.password, user.passwordHash);
    if (!isPasswordValid) {
      throw new UnauthorizedException({
        code: 'INVALID_CREDENTIALS',
        message: '이메일 또는 비밀번호가 올바르지 않습니다.',
      });
    }

    const tokens = await this.generateTokens(user);

    return {
      ...tokens,
      user: this.sanitizeUser(user),
      isNewUser: false,
    };
  }

  async refresh(refreshTokenStr: string) {
    const refreshTokenEntity = await this.refreshTokenRepository.findOne({
      where: { token: refreshTokenStr },
      relations: ['user'],
    });

    if (!refreshTokenEntity) {
      throw new UnauthorizedException('유효하지 않은 리프레시 토큰입니다.');
    }

    if (refreshTokenEntity.expiresAt < new Date()) {
      await this.refreshTokenRepository.remove(refreshTokenEntity);
      throw new UnauthorizedException('리프레시 토큰이 만료되었습니다.');
    }

    const user = refreshTokenEntity.user;
    if (!user || user.status !== 'ACTIVE') {
      throw new UnauthorizedException('유효하지 않은 사용자입니다.');
    }

    // Remove old refresh token
    await this.refreshTokenRepository.remove(refreshTokenEntity);

    // Generate new tokens
    const tokens = await this.generateTokens(user);

    return tokens;
  }

  async logout(userId: string) {
    // Remove all refresh tokens for user
    await this.refreshTokenRepository.delete({ userId });
    return { success: true };
  }

  async requestPasswordReset(email: string) {
    const user = await this.userRepository.findOne({
      where: { email, authProvider: 'EMAIL' },
    });

    // TODO: 실제 이메일 발송 연동 필요 (SES/SendGrid 등).
    // 계정 존재 여부를 응답으로 노출하지 않기 위해 항상 동일 응답을 반환한다.
    if (user) {
      const resetToken = this.jwtService.sign(
        { sub: user.id, purpose: 'password-reset' },
        { expiresIn: '30m' },
      );
      this.logger.log(
        `[password-reset] to=${email} token=${resetToken.slice(0, 12)}... (email 발송 미연동)`,
      );
    } else {
      this.logger.log(`[password-reset] to=${email} (존재하지 않는 계정)`);
    }

    return {
      success: true,
      message: '입력하신 이메일로 재설정 안내를 보냈습니다.',
    };
  }

  async verifyPhone(userId: string, phoneNumber: string, code?: string) {
    const key = `${userId}:${phoneNumber}`;

    if (!code) {
      // 인증번호 발송 단계
      const generated = Math.floor(100000 + Math.random() * 900000).toString();
      this.phoneCodes.set(key, {
        code: generated,
        expiresAt: Date.now() + this.PHONE_CODE_TTL_MS,
        verified: false,
      });
      // TODO: 실제 SMS 발송 연동 필요 (NHN Cloud SMS / Naver Cloud SENS / CoolSMS 등).
      this.logger.log(`[phone-verify] 발송 phone=${phoneNumber} code=${generated}`);
      return { sent: true, expiresInSeconds: this.PHONE_CODE_TTL_MS / 1000 };
    }

    // 검증 단계
    const entry = this.phoneCodes.get(key);
    if (!entry) {
      throw new BadRequestException({
        code: 'VERIFICATION_NOT_REQUESTED',
        message: '인증번호 발송을 먼저 요청해주세요.',
      });
    }

    if (entry.expiresAt < Date.now()) {
      this.phoneCodes.delete(key);
      throw new BadRequestException({
        code: 'VERIFICATION_EXPIRED',
        message: '인증번호가 만료되었습니다.',
      });
    }

    if (entry.code !== code) {
      throw new BadRequestException({
        code: 'VERIFICATION_MISMATCH',
        message: '인증번호가 일치하지 않습니다.',
      });
    }

    const existing = await this.userRepository.findOne({
      where: { phoneNumber, isPhoneVerified: true },
    });
    if (existing && existing.id !== userId) {
      throw new ConflictException({
        code: 'PHONE_ALREADY_USED',
        message: '이미 다른 계정에서 사용 중인 전화번호입니다.',
      });
    }

    await this.userRepository.update(userId, {
      phoneNumber,
      isPhoneVerified: true,
    });
    this.phoneCodes.delete(key);

    const masked = phoneNumber.replace(/^(\d{3})\d{3,4}(\d{4})$/, '$1-****-$2');

    return { verified: true, phoneNumber: masked };
  }

  private async generateTokens(user: User) {
    const payload = {
      sub: user.id,
      email: user.email,
      isAdmin: user.isAdmin,
    };

    const accessToken = this.jwtService.sign(payload, {
      expiresIn: this.configService.get('JWT_ACCESS_EXPIRES', '1h'),
    });

    const refreshExpiresIn = this.configService.get('JWT_REFRESH_EXPIRES', '14d');
    const refreshToken = this.jwtService.sign(payload, {
      expiresIn: refreshExpiresIn,
    });

    // Parse the refresh token expiry to calculate the DB expiration date
    const expiresAt = new Date();
    const match = refreshExpiresIn.match(/^(\d+)(d|h|m|s)$/);
    if (match) {
      const value = parseInt(match[1], 10);
      const unit = match[2];
      switch (unit) {
        case 'd': expiresAt.setDate(expiresAt.getDate() + value); break;
        case 'h': expiresAt.setHours(expiresAt.getHours() + value); break;
        case 'm': expiresAt.setMinutes(expiresAt.getMinutes() + value); break;
        case 's': expiresAt.setSeconds(expiresAt.getSeconds() + value); break;
      }
    } else {
      // Fallback: 14 days
      expiresAt.setDate(expiresAt.getDate() + 14);
    }

    const refreshTokenEntity = this.refreshTokenRepository.create({
      userId: user.id,
      token: refreshToken,
      expiresAt,
    });
    await this.refreshTokenRepository.save(refreshTokenEntity);

    return { accessToken, refreshToken };
  }

  private sanitizeUser(user: User) {
    const { passwordHash, ...result } = user;
    return result;
  }
}
