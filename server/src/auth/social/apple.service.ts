import { Injectable, Logger, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as jwt from 'jsonwebtoken';
import * as jwksClient from 'jwks-rsa';

export interface SocialUserInfo {
  socialId: string;
  email?: string;
}

@Injectable()
export class AppleService {
  private readonly logger = new Logger(AppleService.name);
  private jwksClient: jwksClient.JwksClient;

  constructor(private configService: ConfigService) {
    this.jwksClient = jwksClient({
      jwksUri: 'https://appleid.apple.com/auth/keys',
      cache: true,
      cacheMaxAge: 86400000, // 24 hours
    });
  }

  /** .env의 APPLE_PRIVATE_KEY는 보통 \n 이스케이프된 한 줄 또는 진짜 줄바꿈 포함 */
  private getPrivateKey(): string {
    const raw = this.configService.get<string>('APPLE_PRIVATE_KEY', '');
    return raw.replace(/\\n/g, '\n');
  }

  /** Apple /auth/token, /auth/revoke 호출 시 client_secret으로 쓰는 ES256 JWT */
  private generateClientSecret(): string {
    const teamId = this.configService.get<string>('APPLE_TEAM_ID');
    const keyId = this.configService.get<string>('APPLE_KEY_ID');
    const clientId = this.configService.get<string>('APPLE_CLIENT_ID');
    const privateKey = this.getPrivateKey();

    if (!teamId || !keyId || !clientId || !privateKey) {
      throw new Error('Apple 환경변수가 누락되었습니다.');
    }

    const now = Math.floor(Date.now() / 1000);
    return jwt.sign(
      {
        iss: teamId,
        iat: now,
        exp: now + 60 * 5, // 5분
        aud: 'https://appleid.apple.com',
        sub: clientId,
      },
      privateKey,
      {
        algorithm: 'ES256',
        header: { alg: 'ES256', kid: keyId },
      },
    );
  }

  /** Sign In with Apple authorization_code → refresh_token 교환 */
  async exchangeAuthCode(authorizationCode: string): Promise<{
    refreshToken: string | null;
    accessToken: string | null;
  }> {
    const clientId = this.configService.get<string>('APPLE_CLIENT_ID');
    if (!clientId) {
      throw new Error('APPLE_CLIENT_ID가 설정되지 않았습니다.');
    }

    const clientSecret = this.generateClientSecret();
    const params = new URLSearchParams({
      client_id: clientId,
      client_secret: clientSecret,
      grant_type: 'authorization_code',
      code: authorizationCode,
    });

    const res = await fetch('https://appleid.apple.com/auth/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: params.toString(),
    });

    if (!res.ok) {
      const text = await res.text();
      this.logger.warn(`Apple /auth/token failed (${res.status}): ${text}`);
      return { refreshToken: null, accessToken: null };
    }

    const data = (await res.json()) as Record<string, any>;
    return {
      refreshToken: data.refresh_token ?? null,
      accessToken: data.access_token ?? null,
    };
  }

  /** Apple refresh_token revoke (계정 삭제 시 호출) */
  async revokeRefreshToken(refreshToken: string): Promise<boolean> {
    if (!refreshToken) return false;
    const clientId = this.configService.get<string>('APPLE_CLIENT_ID');
    if (!clientId) return false;

    try {
      const clientSecret = this.generateClientSecret();
      const params = new URLSearchParams({
        client_id: clientId,
        client_secret: clientSecret,
        token: refreshToken,
        token_type_hint: 'refresh_token',
      });

      const res = await fetch('https://appleid.apple.com/auth/revoke', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: params.toString(),
      });

      if (!res.ok) {
        const text = await res.text();
        this.logger.warn(`Apple /auth/revoke failed (${res.status}): ${text}`);
        return false;
      }
      return true;
    } catch (e: any) {
      this.logger.warn(`Apple revoke error: ${e?.message}`);
      return false;
    }
  }

  async getUserInfo(idToken: string): Promise<SocialUserInfo> {
    try {
      // Decode the token header to find the matching key ID (kid)
      const decodedHeader = jwt.decode(idToken, { complete: true });
      if (!decodedHeader || !decodedHeader.header?.kid) {
        throw new UnauthorizedException('유효하지 않은 Apple 토큰입니다.');
      }

      // Fetch the matching public key from Apple's JWKS
      const key = await this.jwksClient.getSigningKey(decodedHeader.header.kid);
      const publicKey = key.getPublicKey();

      // Verify the token with Apple's public key
      const decoded = jwt.verify(idToken, publicKey, {
        algorithms: ['RS256'],
        issuer: 'https://appleid.apple.com',
        audience: this.configService.get('APPLE_CLIENT_ID'),
      }) as any;

      if (!decoded || !decoded.sub) {
        throw new UnauthorizedException('유효하지 않은 Apple 토큰입니다.');
      }

      return {
        socialId: decoded.sub,
        email: decoded.email,
      };
    } catch (error) {
      if (error instanceof UnauthorizedException) throw error;
      throw new UnauthorizedException('Apple 인증에 실패했습니다.');
    }
  }
}
