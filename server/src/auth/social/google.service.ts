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

      // Validate the audience matches our Google Client ID
      const googleClientId = this.configService.get('GOOGLE_CLIENT_ID');
      if (googleClientId && aud !== googleClientId) {
        throw new UnauthorizedException('Google 토큰의 audience가 일치하지 않습니다.');
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
