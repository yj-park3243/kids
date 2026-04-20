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
export class KakaoService {
  constructor(private configService: ConfigService) {}

  async getUserInfo(accessToken: string): Promise<SocialUserInfo> {
    try {
      const response = await axios.get('https://kapi.kakao.com/v2/user/me', {
        headers: {
          Authorization: `Bearer ${accessToken}`,
        },
      });

      const { id, kakao_account } = response.data;

      return {
        socialId: String(id),
        email: kakao_account?.email,
        nickname: kakao_account?.profile?.nickname,
        profileImageUrl: kakao_account?.profile?.profile_image_url,
      };
    } catch (error) {
      throw new UnauthorizedException('카카오 인증에 실패했습니다.');
    }
  }
}
