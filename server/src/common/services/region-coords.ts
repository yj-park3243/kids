// 시군구/시도 단위 대략 좌표 — 네이버 지오코딩 실패 시 폴백.
// 모임이 반드시 지도에 핀으로 찍히도록 보장한다.

interface Coord {
  lat: number;
  lng: number;
}

// 서울 25개 자치구 중심.
const SIGUNGU: Record<string, Coord> = {
  강남구: { lat: 37.5172, lng: 127.0473 },
  강동구: { lat: 37.5301, lng: 127.1238 },
  강북구: { lat: 37.6396, lng: 127.0257 },
  강서구: { lat: 37.5509, lng: 126.8495 },
  관악구: { lat: 37.4784, lng: 126.9516 },
  광진구: { lat: 37.5385, lng: 127.0823 },
  구로구: { lat: 37.4954, lng: 126.8874 },
  금천구: { lat: 37.4569, lng: 126.8956 },
  노원구: { lat: 37.6542, lng: 127.0568 },
  도봉구: { lat: 37.6688, lng: 127.0471 },
  동대문구: { lat: 37.5744, lng: 127.0396 },
  동작구: { lat: 37.5124, lng: 126.9393 },
  마포구: { lat: 37.5663, lng: 126.9019 },
  서대문구: { lat: 37.5791, lng: 126.9368 },
  서초구: { lat: 37.4837, lng: 127.0324 },
  성동구: { lat: 37.5634, lng: 127.0371 },
  성북구: { lat: 37.5894, lng: 127.0167 },
  송파구: { lat: 37.5145, lng: 127.1059 },
  양천구: { lat: 37.5169, lng: 126.8664 },
  영등포구: { lat: 37.5264, lng: 126.8962 },
  용산구: { lat: 37.5326, lng: 126.9905 },
  은평구: { lat: 37.6027, lng: 126.9291 },
  종로구: { lat: 37.573, lng: 126.9794 },
  중구: { lat: 37.5639, lng: 126.9975 },
  중랑구: { lat: 37.6063, lng: 127.0925 },
};

// 시/도 대표 좌표 (시군구 미매칭 시).
const SIDO: Record<string, Coord> = {
  서울특별시: { lat: 37.5665, lng: 126.978 },
  부산광역시: { lat: 35.1796, lng: 129.0756 },
  대구광역시: { lat: 35.8714, lng: 128.6014 },
  인천광역시: { lat: 37.4563, lng: 126.7052 },
  광주광역시: { lat: 35.1595, lng: 126.8526 },
  대전광역시: { lat: 36.3504, lng: 127.3845 },
  울산광역시: { lat: 35.5384, lng: 129.3114 },
  세종특별자치시: { lat: 36.48, lng: 127.289 },
  경기도: { lat: 37.2636, lng: 127.0286 },
  강원특별자치도: { lat: 37.8813, lng: 127.7298 },
  충청북도: { lat: 36.6424, lng: 127.489 },
  충청남도: { lat: 36.6588, lng: 126.6728 },
  전북특별자치도: { lat: 35.8242, lng: 127.148 },
  전라남도: { lat: 34.8161, lng: 126.4629 },
  경상북도: { lat: 36.576, lng: 128.5056 },
  경상남도: { lat: 35.228, lng: 128.6811 },
  제주특별자치도: { lat: 33.4996, lng: 126.5312 },
};

const DEFAULT: Coord = { lat: 37.5665, lng: 126.978 };

/**
 * 지오코딩 실패 시 시군구/동 기준 대략 좌표.
 * - 동 이름 해시로 구 안에서 동별 고정 오프셋 (분산 배치)
 * - 방마다 ±400m 랜덤 — 같은 동 모임이 한 점에 겹치지 않게 (저장 후 고정)
 */
export function fallbackCoord(
  sido?: string,
  sigungu?: string,
  dong?: string,
): Coord {
  const base =
    (sigungu && SIGUNGU[sigungu]) || (sido && SIDO[sido]) || DEFAULT;

  let h = 0;
  for (const ch of dong ?? '') {
    h = (h * 31 + ch.charCodeAt(0)) >>> 0;
  }
  const angle = ((h % 360) * Math.PI) / 180;
  const distKm = 0.2 + (h % 800) / 1000; // 동별 0.2~1.0km
  const jLat = (Math.random() - 0.5) * 0.0036; // ±~200m
  const jLng = (Math.random() - 0.5) * 0.0036;

  const dLat = (distKm / 111) * Math.sin(angle);
  const dLng =
    (distKm / (111 * Math.cos((base.lat * Math.PI) / 180))) * Math.cos(angle);

  return { lat: base.lat + dLat + jLat, lng: base.lng + dLng + jLng };
}
