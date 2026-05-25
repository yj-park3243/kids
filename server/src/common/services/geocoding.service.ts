import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios from 'axios';

export interface GeocodeResult {
  latitude: number;
  longitude: number;
}

@Injectable()
export class GeocodingService {
  private readonly logger = new Logger(GeocodingService.name);

  constructor(private readonly configService: ConfigService) {}

  /**
   * 주소 → 좌표. 카카오 로컬 API 만 사용.
   * (NCP 네이버 지오코딩은 별도 API Gateway 권한이 필요한데 현재 키는 모바일 SDK 키여서
   *  401/403 만 떨어져 호출 비용만 든다. 카카오 키가 있으니 그쪽으로 직행한다.)
   * 실패하면 null — 호출부에서 시군구 폴백 좌표 적용.
   */
  async geocode(address: string): Promise<GeocodeResult | null> {
    const trimmed = (address ?? '').trim();
    if (!trimmed) return null;
    return this._kakaoGeocode(trimmed);
  }

  private async _kakaoGeocode(query: string): Promise<GeocodeResult | null> {
    const key = this.configService.get<string>('KAKAO_REST_API_KEY');
    if (!key) {
      this.logger.error(
        `KAKAO_REST_API_KEY 가 설정되지 않아 지오코딩 불가 (${query}) — .env 확인 필요`,
      );
      return null;
    }
    try {
      const response = await axios.get(
        'https://dapi.kakao.com/v2/local/search/address.json',
        {
          params: { query },
          headers: { Authorization: `KakaoAK ${key}` },
          timeout: 3000,
        },
      );
      const docs = response.data?.documents;
      if (!Array.isArray(docs) || docs.length === 0) {
        this.logger.warn(`Kakao 지오코딩 결과 없음: "${query}"`);
        return null;
      }
      const first = docs[0];
      // 카카오는 x = longitude, y = latitude.
      const lat = parseFloat(first.y);
      const lng = parseFloat(first.x);
      if (Number.isNaN(lat) || Number.isNaN(lng)) {
        this.logger.warn(
          `Kakao 응답에 좌표가 없음: ${JSON.stringify(first).slice(0, 200)}`,
        );
        return null;
      }
      return { latitude: lat, longitude: lng };
    } catch (err: any) {
      const status = err?.response?.status;
      const body = err?.response?.data;
      this.logger.error(
        `Kakao 지오코딩 실패 "${query}" — status=${status} body=${JSON.stringify(body)?.slice(0, 200) ?? err?.message}`,
      );
      return null;
    }
  }
}
