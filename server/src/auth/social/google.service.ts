import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios from 'axios';

export interface SocialUserInfo {
  socialId: string;
  email?: string;
  nickname?: string;
  profileImageUrl?: string;
}

@Injectable()
export class GoogleService {
  constructor(private configService: ConfigService) {}

  async getUserInfo(idToken: string): Promise<SocialUserInfo> {
    try {
      // Verify the token with Google
      const response = await axios.get(
        `https://oauth2.googleapis.com/tokeninfo?id_token=${idToken}`,
      );

      const { sub, email, name, picture, aud } = response.data;

      // 같은 프로젝트 prefix로 audience 검증. 환경변수 미설정이면 검증 거부 (security fail-closed)
      const expectedPrefix = this.configService
        .get<string>('GOOGLE_CLIENT_ID', '')
        .split('-')[0];
      if (!expectedPrefix) {
        throw new UnauthorizedException(
          'GOOGLE_CLIENT_ID가 설정되지 않아 Google 토큰을 검증할 수 없습니다.',
        );
      }
      if (typeof aud !== 'string' || !aud.startsWith(`${expectedPrefix}-`)) {
        throw new UnauthorizedException('Google 토큰이 다른 프로젝트에서 발급되었습니다.');
      }

      if (!sub) {
        throw new UnauthorizedException('Google 토큰에 사용자 ID가 없습니다.');
      }

      return {
        socialId: sub,
        email,
        nickname: name,
        profileImageUrl: picture,
      };
    } catch (error) {
      if (error instanceof UnauthorizedException) throw error;
      throw new UnauthorizedException('Google 인증에 실패했습니다.');
    }
  }
}
