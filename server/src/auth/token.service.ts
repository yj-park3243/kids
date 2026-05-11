import {
  Injectable,
  Logger,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService, TokenExpiredError } from '@nestjs/jwt';
import { randomUUID } from 'crypto';

const ISSUER = 'kids-app';

export interface TokenPayload {
  sub: string;
  email?: string | null;
  isAdmin?: boolean;
}

export interface AccessTokenClaims extends TokenPayload {
  type: 'access';
  iat: number;
  exp: number;
  iss: string;
  jti: string;
}

export interface RefreshTokenClaims extends TokenPayload {
  type: 'refresh';
  iat: number;
  exp: number;
  iss: string;
  jti: string;
}

/**
 * JWT 발급/검증 통합. match 패턴 포팅:
 * - `type` claim으로 access/refresh 강제 구분
 * - `iss` claim으로 외부 발급 토큰 차단
 * - `jti`로 같은 시각에도 토큰 문자열 유니크
 */
@Injectable()
export class TokenService {
  private readonly logger = new Logger(TokenService.name);

  constructor(
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
  ) {}

  private get accessExpiry(): string {
    return this.configService.get<string>('JWT_ACCESS_EXPIRES', '1h');
  }

  private get refreshExpiry(): string {
    return this.configService.get<string>('JWT_REFRESH_EXPIRES', '14d');
  }

  signAccessToken(payload: TokenPayload): string {
    return this.jwtService.sign(
      { ...payload, type: 'access' },
      {
        issuer: ISSUER,
        expiresIn: this.accessExpiry,
        jwtid: randomUUID(),
      },
    );
  }

  signRefreshToken(payload: TokenPayload): string {
    return this.jwtService.sign(
      { ...payload, type: 'refresh' },
      {
        issuer: ISSUER,
        expiresIn: this.refreshExpiry,
        jwtid: randomUUID(),
      },
    );
  }

  issueTokenPair(payload: TokenPayload): {
    accessToken: string;
    refreshToken: string;
  } {
    return {
      accessToken: this.signAccessToken(payload),
      refreshToken: this.signRefreshToken(payload),
    };
  }

  verifyAccessToken(token: string): AccessTokenClaims {
    return this.verifyWithType<AccessTokenClaims>(token, 'access');
  }

  verifyRefreshToken(token: string): RefreshTokenClaims {
    return this.verifyWithType<RefreshTokenClaims>(token, 'refresh');
  }

  private verifyWithType<T extends { type: string }>(
    token: string,
    expectedType: 'access' | 'refresh',
  ): T {
    try {
      const decoded = this.jwtService.verify<T>(token, {
        issuer: ISSUER,
      });
      if (decoded.type !== expectedType) {
        throw new UnauthorizedException({
          code: 'INVALID_TOKEN_TYPE',
          message: `${expectedType} 토큰이 아닙니다.`,
        });
      }
      return decoded;
    } catch (err) {
      if (err instanceof TokenExpiredError) {
        throw new UnauthorizedException({
          code: 'EXPIRED_TOKEN',
          message: '토큰이 만료되었습니다.',
        });
      }
      if (err instanceof UnauthorizedException) throw err;
      throw new UnauthorizedException({
        code: 'INVALID_TOKEN',
        message: '유효하지 않은 토큰입니다.',
      });
    }
  }

  /**
   * refresh JWT에 들어있는 exp(seconds) → Date 변환
   */
  refreshExpiresAt(token: string): Date {
    const decoded = this.jwtService.decode(token) as
      | { exp?: number }
      | null;
    if (!decoded?.exp) {
      // fallback: 14일
      const d = new Date();
      d.setDate(d.getDate() + 14);
      return d;
    }
    return new Date(decoded.exp * 1000);
  }
}
