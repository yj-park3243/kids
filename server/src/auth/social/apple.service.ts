import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as jwt from 'jsonwebtoken';
import * as jwksClient from 'jwks-rsa';

export interface SocialUserInfo {
  socialId: string;
  email?: string;
}

@Injectable()
export class AppleService {
  private jwksClient: jwksClient.JwksClient;

  constructor(private configService: ConfigService) {
    this.jwksClient = jwksClient({
      jwksUri: 'https://appleid.apple.com/auth/keys',
      cache: true,
      cacheMaxAge: 86400000, // 24 hours
    });
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
