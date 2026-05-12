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
   * 주소 문자열을 네이버 Geocoding API 로 좌표 변환.
   * 키 미설정/실패/응답 없음 시 null. 방 생성 등이 막히지 않도록 graceful.
   */
  async geocode(address: string): Promise<GeocodeResult | null> {
    const trimmed = (address ?? '').trim();
    if (!trimmed) return null;

    const clientId = this.configService.get<string>('NAVER_MAP_CLIENT_ID');
    const clientSecret = this.configService.get<string>(
      'NAVER_MAP_CLIENT_SECRET',
    );
    if (!clientId || !clientSecret) {
      this.logger.warn('NAVER_MAP_CLIENT_ID/SECRET 미설정 — geocoding skip');
      return null;
    }

    try {
      const response = await axios.get(this.endpoint, {
        params: { query: trimmed },
        headers: {
          'X-NCP-APIGW-API-KEY-ID': clientId,
          'X-NCP-APIGW-API-KEY': clientSecret,
        },
        timeout: 3000,
      });

      const addresses = response.data?.addresses;
      if (!Array.isArray(addresses) || addresses.length === 0) {
        return null;
      }
      const first = addresses[0];
      const lat = parseFloat(first.y);
      const lng = parseFloat(first.x);
      if (Number.isNaN(lat) || Number.isNaN(lng)) return null;
      return { latitude: lat, longitude: lng };
    } catch (err: any) {
      this.logger.warn(
        `Geocoding 실패 (${trimmed}): ${err?.response?.status ?? err?.message}`,
      );
      return null;
    }
  }
}
