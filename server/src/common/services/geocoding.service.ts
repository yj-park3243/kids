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
  private readonly endpoint =
    'https://maps.apigw.ntruss.com/map-geocode/v2/geocode';

  constructor(private readonly configService: ConfigService) {}

  /**
   * 주소 → 좌표. 네이버 NCP 시도 후 실패 시 카카오 로컬 API 로 폴백.
   * 둘 다 실패하면 null — 호출부에서 시군구 폴백 좌표 적용.
   */
  async geocode(address: string): Promise<GeocodeResult | null> {
    const trimmed = (address ?? '').trim();
    if (!trimmed) return null;

    const viaNaver = await this._naverGeocode(trimmed);
    if (viaNaver) return viaNaver;
    return this._kakaoGeocode(trimmed);
  }

  private async _naverGeocode(query: string): Promise<GeocodeResult | null> {
    const clientId = this.configService.get<string>('NAVER_MAP_CLIENT_ID');
    const clientSecret = this.configService.get<string>(
      'NAVER_MAP_CLIENT_SECRET',
    );
    if (!clientId || !clientSecret) return null;

    try {
      const response = await axios.get(this.endpoint, {
        params: { query },
        headers: {
          'X-NCP-APIGW-API-KEY-ID': clientId,
          'X-NCP-APIGW-API-KEY': clientSecret,
        },
        timeout: 3000,
      });
      const addresses = response.data?.addresses;
      if (!Array.isArray(addresses) || addresses.length === 0) return null;
      const first = addresses[0];
      const lat = parseFloat(first.y);
      const lng = parseFloat(first.x);
      if (Number.isNaN(lat) || Number.isNaN(lng)) return null;
      return { latitude: lat, longitude: lng };
    } catch (err: any) {
      this.logger.warn(
        `Naver geocode 실패 (${query}): ${err?.response?.status ?? err?.message}`,
      );
      return null;
    }
  }

  private async _kakaoGeocode(query: string): Promise<GeocodeResult | null> {
    const key = this.configService.get<string>('KAKAO_REST_API_KEY');
    if (!key) return null;
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
      if (!Array.isArray(docs) || docs.length === 0) return null;
      const first = docs[0];
      // x = longitude, y = latitude (카카오 좌표 규약).
      const lat = parseFloat(first.y);
      const lng = parseFloat(first.x);
      if (Number.isNaN(lat) || Number.isNaN(lng)) return null;
      return { latitude: lat, longitude: lng };
    } catch (err: any) {
      this.logger.warn(
        `Kakao geocode 실패 (${query}): ${err?.response?.status ?? err?.message}`,
      );
      return null;
    }
  }
}
