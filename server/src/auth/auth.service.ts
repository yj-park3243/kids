import {
  Injectable,
  UnauthorizedException,
  ConflictException,
  ForbiddenException,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import * as bcrypt from 'bcrypt';
import { User } from '../user/entities/user.entity';
import { RefreshToken } from './entities/refresh-token.entity';
import { SocialAccount } from './entities/social-account.entity';
import { SocialLoginDto, AuthProvider } from './dto/social-login.dto';
import { EmailRegisterDto } from './dto/email-register.dto';
import { EmailLoginDto } from './dto/email-login.dto';
import { KakaoService } from './social/kakao.service';
import { AppleService } from './social/apple.service';
import { GoogleService } from './social/google.service';
import { TokenService, TokenPayload } from './token.service';
import {
  TelegramService,
  escapeHtml,
} from '../common/services/telegram.service';
import { VersionService } from '../version/version.service';
import { randomUUID } from 'crypto';

type PhoneVerificationEntry = { code: string; expiresAt: number; verified: boolean };

interface SocialNormalized {
  providerId: string;
  email: string | null;
  nickname: string | null;
  profileImageUrl: string | null;
}

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  private readonly phoneCodes = new Map<string, PhoneVerificationEntry>();
  private readonly PHONE_CODE_TTL_MS = 3 * 60 * 1000;

  constructor(
    @InjectRepository(User)
    private userRepository: Repository<User>,
    @InjectRepository(RefreshToken)
    private refreshTokenRepository: Repository<RefreshToken>,
    @InjectRepository(SocialAccount)
    private socialAccountRepository: Repository<SocialAccount>,
    private dataSource: DataSource,
    private jwtService: JwtService,
    private configService: ConfigService,
    private kakaoService: KakaoService,
    private appleService: AppleService,
    private googleService: GoogleService,
    private tokenService: TokenService,
    private telegramService: TelegramService,
    private versionService: VersionService,
  ) {}

  /**
   * 앱 심사 모드(app_version.bypass_phone_verification=true)에서 신규 가입 시
   * KCP 본인인증을 우회하기 위한 더미 데이터. ci/di 는 unique 제약이 있어 user 별로 unique.
   */
  private buildBypassIdentity(): Partial<User> {
    const uniq = randomUUID();
    return {
      isPhoneVerified: true,
      isVerified: true,
      verifiedAt: new Date(),
      phoneNumber: '01000000000',
      realName: '심사용계정',
      carrier: 'REVIEW',
      birthDate: new Date('1990-01-01'),
      gender: 'MALE',
      ci: `REVIEW_${uniq}`,
      di: `REVIEW_${uniq}`,
    };
  }

  private notifyNewSignup(provider: string, user: User): void {
    void this.telegramService.sendAdminAlert(
      `🆕 <b>신규 회원가입</b> (${escapeHtml(provider)})\n` +
        `• ID: <code>${escapeHtml(user.id)}</code>\n` +
        `• 닉네임: ${escapeHtml(user.nickname ?? '-')}\n` +
        `• 이메일: ${escapeHtml(user.email ?? '-')}`,
    );
  }

  // ─────────────────────────────────────
  // 소셜 로그인 — providerId → SocialAccount → email → 신규 가입
  // ─────────────────────────────────────
  async socialLogin(dto: SocialLoginDto) {
    let normalized: SocialNormalized;

    switch (dto.provider) {
      case AuthProvider.KAKAO: {
        if (!dto.accessToken) {
          throw new UnauthorizedException('카카오 로그인에는 accessToken이 필요합니다.');
        }
        const info = await this.kakaoService.getUserInfo(dto.accessToken);
        normalized = {
          providerId: info.socialId,
          email: info.email ?? null,
          nickname: info.nickname ?? null,
          profileImageUrl: info.profileImageUrl ?? null,
        };
        break;
      }
      case AuthProvider.APPLE: {
        if (!dto.idToken) {
          throw new UnauthorizedException('Apple 로그인에는 idToken이 필요합니다.');
        }
        const info = await this.appleService.getUserInfo(dto.idToken);
        normalized = {
          providerId: info.socialId,
          email: info.email ?? null,
          nickname: null,
          profileImageUrl: null,
        };
        break;
      }
      case AuthProvider.GOOGLE: {
        if (!dto.idToken) {
          throw new UnauthorizedException('Google 로그인에는 idToken이 필요합니다.');
        }
        const info = await this.googleService.getUserInfo(dto.idToken);
        normalized = {
          providerId: info.socialId,
          email: info.email ?? null,
          nickname: info.nickname ?? null,
          profileImageUrl: info.profileImageUrl ?? null,
        };
        break;
      }
      default:
        throw new BadRequestException(`지원하지 않는 provider: ${dto.provider}`);
    }

    // 1. providerId로 기존 SocialAccount 조회
    const existingSocial = await this.socialAccountRepository.findOne({
      where: { provider: dto.provider, providerId: normalized.providerId },
      relations: { user: true },
    });

    let user: User;
    let isNewUser = false;

    if (existingSocial) {
      user = existingSocial.user;
      this.assertActiveStatus(user);
    } else if (normalized.email) {
      // 2. 같은 이메일 유저가 있으면 SocialAccount만 연결
      const existingUserByEmail = await this.userRepository.findOne({
        where: { email: normalized.email },
      });
      if (existingUserByEmail) {
        this.assertActiveStatus(existingUserByEmail);
        await this.socialAccountRepository.save(
          this.socialAccountRepository.create({
            userId: existingUserByEmail.id,
            provider: dto.provider,
            providerId: normalized.providerId,
          }),
        );
        user = existingUserByEmail;
      } else {
        user = await this.createNewSocialUser(dto.provider, normalized);
        isNewUser = true;
      }
    } else {
      // 3. 완전 신규 — 이메일 없을 수도 있음 (Apple)
      user = await this.createNewSocialUser(dto.provider, normalized);
      isNewUser = true;
    }

    // Apple authorizationCode → refresh_token 교환·저장 (계정 삭제 시 revoke용)
    if (
      dto.provider === AuthProvider.APPLE &&
      dto.accessToken &&
      !user.appleRefreshToken
    ) {
      try {
        const exchanged = await this.appleService.exchangeAuthCode(dto.accessToken);
        if (exchanged.refreshToken) {
          await this.userRepository.update(user.id, {
            appleRefreshToken: exchanged.refreshToken,
          });
          user.appleRefreshToken = exchanged.refreshToken;
        }
      } catch (e: any) {
        this.logger.warn(`Apple authCode 교환 실패: ${e?.message}`);
      }
    }

    await this.touchLastLogin(user.id);
    const tokens = await this.issueAndStoreTokens(user);

    return {
      ...tokens,
      user: this.sanitizeUser(user),
      isNewUser,
    };
  }

  private async createNewSocialUser(
    provider: string,
    n: SocialNormalized,
  ): Promise<User> {
    const nickname = await this.generateUniqueNickname(n.nickname);
    // Apple은 두 번째 로그인부터 email 안 줘서 placeholder로 채움
    const safeEmail =
      n.email ?? (provider === AuthProvider.APPLE
        ? `apple_${n.providerId}@privaterelay.kids.local`
        : null);

    const bypass = await this.versionService.isPhoneVerificationBypassed();
    const bypassFields = bypass ? this.buildBypassIdentity() : {};

    return await this.dataSource.transaction(async (manager) => {
      const newUser = manager.create(User, {
        authProvider: provider,
        socialId: n.providerId,
        email: safeEmail ?? undefined,
        nickname,
        profileImageUrl: n.profileImageUrl ?? undefined,
        isProfileComplete: false,
        lastLoginAt: new Date(),
        ...bypassFields,
      });
      await manager.save(User, newUser);

      await manager.save(
        SocialAccount,
        manager.create(SocialAccount, {
          userId: newUser.id,
          provider,
          providerId: n.providerId,
        }),
      );
      return newUser;
    }).then((user) => {
      this.notifyNewSignup(provider, user);
      return user;
    });
  }

  // ─────────────────────────────────────
  // 이메일 가입/로그인 — match엔 Firebase지만 kids는 자체 비밀번호 유지
  // ─────────────────────────────────────
  async emailRegister(dto: EmailRegisterDto) {
    const existing = await this.userRepository.findOne({
      where: { email: dto.email },
    });
    if (existing) {
      throw new ConflictException({
        code: 'EMAIL_ALREADY_EXISTS',
        message: '이미 사용 중인 이메일입니다.',
      });
    }

    const passwordHash = await bcrypt.hash(dto.password, 10);
    const bypass = await this.versionService.isPhoneVerificationBypassed();
    const bypassFields = bypass ? this.buildBypassIdentity() : {};
    const user = await this.userRepository.save(
      this.userRepository.create({
        authProvider: 'EMAIL',
        email: dto.email,
        passwordHash,
        isProfileComplete: false,
        lastLoginAt: new Date(),
        ...bypassFields,
      }),
    );

    this.notifyNewSignup('EMAIL', user);

    const tokens = await this.issueAndStoreTokens(user);
    return {
      ...tokens,
      user: this.sanitizeUser(user),
      isNewUser: true,
    };
  }

  async emailLogin(dto: EmailLoginDto) {
    const user = await this.userRepository.findOne({
      where: { email: dto.email, authProvider: 'EMAIL' },
    });
    if (!user || !user.passwordHash) {
      // passwordHash null이면 소셜로만 가입된 계정 — 이메일 로그인 차단
      throw new UnauthorizedException({
        code: 'INVALID_CREDENTIALS',
        message: '이메일 또는 비밀번호가 올바르지 않습니다.',
      });
    }
    this.assertActiveStatus(user);

    const valid = await bcrypt.compare(dto.password, user.passwordHash);
    if (!valid) {
      throw new UnauthorizedException({
        code: 'INVALID_CREDENTIALS',
        message: '이메일 또는 비밀번호가 올바르지 않습니다.',
      });
    }

    await this.touchLastLogin(user.id);
    const tokens = await this.issueAndStoreTokens(user);
    return {
      ...tokens,
      user: this.sanitizeUser(user),
      isNewUser: false,
    };
  }

  // ─────────────────────────────────────
  // 토큰 갱신
  // ─────────────────────────────────────
  async refresh(refreshTokenStr: string) {
    // 1. JWT 자체 검증 (type=refresh, issuer)
    const claims = this.tokenService.verifyRefreshToken(refreshTokenStr);

    // 2. DB에 저장된 토큰과 일치 확인
    const stored = await this.refreshTokenRepository.findOne({
      where: { token: refreshTokenStr },
      relations: ['user'],
    });
    if (!stored) {
      throw new UnauthorizedException('유효하지 않은 리프레시 토큰입니다.');
    }
    if (stored.expiresAt < new Date()) {
      await this.refreshTokenRepository.delete({ id: stored.id });
      throw new UnauthorizedException('리프레시 토큰이 만료되었습니다.');
    }

    const user = stored.user;
    if (!user || user.id !== claims.sub) {
      throw new UnauthorizedException('유효하지 않은 사용자입니다.');
    }
    this.assertActiveStatus(user);

    return await this.issueAndStoreTokens(user);
  }

  async logout(userId: string) {
    await this.refreshTokenRepository.delete({ userId });
    return { success: true };
  }

  // ─────────────────────────────────────
  // 폰 인증
  // ─────────────────────────────────────
  async verifyPhone(userId: string, phoneNumber: string, code?: string) {
    const key = `${userId}:${phoneNumber}`;
    if (!code) {
      const generated = Math.floor(100000 + Math.random() * 900000).toString();
      this.phoneCodes.set(key, {
        code: generated,
        expiresAt: Date.now() + this.PHONE_CODE_TTL_MS,
        verified: false,
      });
      this.logger.log(`[phone-verify] 발송 phone=${phoneNumber} code=${generated}`);
      return { sent: true, expiresInSeconds: this.PHONE_CODE_TTL_MS / 1000 };
    }

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

    const dup = await this.userRepository.findOne({
      where: { phoneNumber, isPhoneVerified: true },
    });
    if (dup && dup.id !== userId) {
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

  // ─────────────────────────────────────
  // 토큰 발급 + 저장 (1 user 1 active refresh)
  // ─────────────────────────────────────
  private async issueAndStoreTokens(user: User): Promise<{
    accessToken: string;
    refreshToken: string;
  }> {
    const payload: TokenPayload = {
      sub: user.id,
      email: user.email,
      isAdmin: user.isAdmin,
    };
    const tokens = this.tokenService.issueTokenPair(payload);

    // 기존 refresh token 삭제 후 upsert.
    // 동일 시각 동시 로그인 시 같은 페이로드로 동일 JWT 가 발급되면
    // token UNIQUE 제약(UQ_c31d0a2f38e6e99110df62ab0af) 에 충돌하므로
    // ON CONFLICT(token) DO UPDATE 로 idempotent 하게 처리.
    await this.refreshTokenRepository.delete({ userId: user.id });
    await this.refreshTokenRepository.upsert(
      {
        userId: user.id,
        token: tokens.refreshToken,
        expiresAt: this.tokenService.refreshExpiresAt(tokens.refreshToken),
      },
      { conflictPaths: ['token'] },
    );

    return tokens;
  }

  // ─────────────────────────────────────
  // 헬퍼
  // ─────────────────────────────────────
  private assertActiveStatus(user: User): void {
    if (user.status === 'BANNED') {
      throw new ForbiddenException({
        code: 'USER_BANNED',
        message: '정지된 계정입니다.',
      });
    }
    if (user.status === 'WITHDRAWN') {
      throw new ForbiddenException({
        code: 'USER_WITHDRAWN',
        message: '탈퇴한 계정입니다.',
      });
    }
  }

  private async touchLastLogin(userId: string): Promise<void> {
    await this.userRepository.update(userId, { lastLoginAt: new Date() });
  }

  private async generateUniqueNickname(base: string | null): Promise<string> {
    const baseNickname = (base ?? '부모').slice(0, 14);
    const exists = await this.userRepository.findOne({
      where: { nickname: baseNickname },
    });
    if (!exists) return baseNickname;

    for (let i = 0; i < 10; i++) {
      const suffix = Math.floor(Math.random() * 9999) + 1;
      const candidate = `${baseNickname}${suffix}`.slice(0, 20);
      const dup = await this.userRepository.findOne({
        where: { nickname: candidate },
      });
      if (!dup) return candidate;
    }
    return `부모${Date.now().toString().slice(-8)}`;
  }

  private sanitizeUser(user: User) {
    const { passwordHash, ...result } = user;
    // pg numeric → string 으로 내려오므로 클라이언트 `as num` 캐스트 실패 방지.
    if (result.mannerScore != null) {
      result.mannerScore = Number(result.mannerScore);
    }
    return result;
  }
}
