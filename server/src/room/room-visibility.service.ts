import { Injectable } from '@nestjs/common';

const COORD_MASK_RADIUS_METERS = 100; // 정확한 위치에서 정확히 100m 떨어진 원 위의 한 점

@Injectable()
export class RoomVisibilityService {
  // 비참여자에게 노출되는 좌표 마스킹.
  // 정확한 위치를 중심으로 반지름 100m 원 위의 한 점을 deterministic 하게 선택.
  // 방향(0~360°)은 room.id 시드 해시 기반이라 같은 방은 항상 같은 위치.
  maskCoordinatesForList(room: {
    id: string;
    latitude: number | null;
    longitude: number | null;
  }) {
    if (room.latitude == null || room.longitude == null) {
      return { latitude: room.latitude, longitude: room.longitude };
    }
    const lat = Number(room.latitude);
    const lng = Number(room.longitude);
    const seed = this.hash(room.id);
    // 0 ~ 2π 범위로 deterministic angle.
    const angle = ((seed % 36000) / 36000) * 2 * Math.PI;
    // 위도 1° ≈ 111,000m, 경도는 cos(위도) 보정.
    const dLat = (COORD_MASK_RADIUS_METERS / 111000) * Math.sin(angle);
    const dLng =
      (COORD_MASK_RADIUS_METERS /
        (111000 * Math.cos((lat * Math.PI) / 180))) *
      Math.cos(angle);
    return { latitude: lat + dLat, longitude: lng + dLng };
  }

  // 상세 응답에서 비공개 필드를 제거. members[].isSingleParent 노출 규칙은
  // 한부모 전용 방 + 본인이 참여 확정자/방장 인 경우에만 true.
  maskRoomForViewer(
    room: any,
    viewerUserId: string | undefined,
    isMember: boolean,
  ) {
    const isHost = !!viewerUserId && room.hostId === viewerUserId;
    const fullAccess = isMember || isHost;

    if (fullAccess) {
      // 한부모 전용 방이 아니라면 members 의 isSingleParent 는 제거.
      if (!room.singleParentOnly && Array.isArray(room.members)) {
        for (const m of room.members) {
          if (m && 'isSingleParent' in m) delete m.isSingleParent;
        }
      }
      return room;
    }

    // 비참여자: placeName/placeAddress 제거, 좌표는 마스킹.
    delete room.placeName;
    delete room.placeAddress;
    const masked = this.maskCoordinatesForList(room);
    room.latitude = masked.latitude;
    room.longitude = masked.longitude;

    // members[].isSingleParent 는 무조건 제거.
    // members[].parentGender 는 MOM_ONLY/DAD_ONLY 방에서만 유지 (자명하므로).
    const exposeParentGender =
      room.genderFilter === 'MOM_ONLY' || room.genderFilter === 'DAD_ONLY';
    if (Array.isArray(room.members)) {
      for (const m of room.members) {
        if (m) {
          if ('isSingleParent' in m) delete m.isSingleParent;
          if (!exposeParentGender && 'parentGender' in m) delete m.parentGender;
        }
      }
    }
    if (room.host && !exposeParentGender && 'parentGender' in room.host) {
      delete room.host.parentGender;
    }
    if (room.host && 'isSingleParent' in room.host) {
      delete room.host.isSingleParent;
    }
    return room;
  }

  private hash(s: string): number {
    let h = 0;
    for (let i = 0; i < s.length; i++) {
      h = (h * 31 + s.charCodeAt(i)) | 0;
    }
    return Math.abs(h);
  }
}
