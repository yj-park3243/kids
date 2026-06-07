import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Room } from '../room/entities/room.entity';

/// 홈 탭 "우리 아이 활동 일지" 대시보드용 단일 응답.
///
/// 카운트 기준은 "취소되지 않은 과거 모임(`date <= today` AND `status != 'CANCELLED'`)".
/// 출석 체크가 안 돼 있어도 카운트되도록 — 출석 미체크가 흔하기 때문.
@Injectable()
export class DashboardService {
  constructor(
    @InjectRepository(Room)
    private readonly roomRepository: Repository<Room>,
  ) {}

  async getMyDashboard(userId: string) {
    const [stats, frequentFriends, recentPhotos, monthlyDates] =
      await Promise.all([
        this.getStats(userId),
        this.getFrequentFriends(userId),
        this.getRecentPhotos(userId),
        this.getMonthlyDates(userId),
      ]);
    return { stats, frequentFriends, recentPhotos, monthlyDates };
  }

  private async getStats(userId: string) {
    const rows = await this.roomRepository.query(
      `
      WITH past_member AS (
        SELECT rm.room_id, r.place_address, r.place_name
        FROM room_member rm
        JOIN room r ON r.id = rm.room_id
        WHERE rm.user_id = $1
          AND r.date <= CURRENT_DATE
          AND r.status <> 'CANCELLED'
      )
      SELECT
        (SELECT COUNT(*) FROM past_member) AS total_rooms,
        (
          SELECT COUNT(DISTINCT rm2.user_id)
          FROM room_member rm2
          WHERE rm2.room_id IN (SELECT room_id FROM past_member)
            AND rm2.user_id <> $1
        ) AS unique_friends,
        (
          SELECT COUNT(DISTINCT COALESCE(NULLIF(place_address, ''), NULLIF(place_name, '')))
          FROM past_member
          WHERE COALESCE(NULLIF(place_address, ''), NULLIF(place_name, '')) IS NOT NULL
        ) AS unique_places
      `,
      [userId],
    );
    const row = rows[0] ?? {};
    return {
      totalRooms: Number(row.total_rooms ?? 0),
      uniqueFriends: Number(row.unique_friends ?? 0),
      uniquePlaces: Number(row.unique_places ?? 0),
    };
  }

  private async getFrequentFriends(userId: string) {
    const rows = await this.roomRepository.query(
      `
      SELECT
        u.id AS user_id,
        u.nickname,
        u.profile_image_url,
        COUNT(*)::int AS joint_count,
        (
          SELECT c.photo_url FROM child c
          WHERE c.user_id = u.id AND c.photo_url IS NOT NULL
          ORDER BY c.created_at ASC LIMIT 1
        ) AS child_photo_url
      FROM room_member rm1
      JOIN room_member rm2 ON rm1.room_id = rm2.room_id
      JOIN room r ON r.id = rm1.room_id
      JOIN "user" u ON u.id = rm2.user_id
      WHERE rm1.user_id = $1
        AND rm2.user_id <> $1
        AND r.date <= CURRENT_DATE
        AND r.status <> 'CANCELLED'
      GROUP BY u.id, u.nickname, u.profile_image_url
      ORDER BY joint_count DESC
      LIMIT 5
      `,
      [userId],
    );
    return rows.map(
      (r: {
        user_id: string;
        nickname: string;
        profile_image_url: string | null;
        joint_count: number;
        child_photo_url: string | null;
      }) => ({
        userId: r.user_id,
        nickname: r.nickname,
        profileImageUrl: r.profile_image_url,
        childPhotoUrl: r.child_photo_url,
        jointCount: r.joint_count,
      }),
    );
  }

  private async getRecentPhotos(userId: string) {
    const rows = await this.roomRepository.query(
      `
      SELECT rp.id, rp.url, rp.room_id, rp.created_at
      FROM room_photo rp
      WHERE rp.room_id IN (SELECT room_id FROM room_member WHERE user_id = $1)
      ORDER BY rp.created_at DESC
      LIMIT 20
      `,
      [userId],
    );
    return rows.map(
      (r: { id: string; url: string; room_id: string; created_at: Date }) => ({
        id: r.id,
        url: r.url,
        roomId: r.room_id,
        createdAt: r.created_at,
      }),
    );
  }

  /// 이번 달(현재 월) 내가 참여한 모임 날짜들 — 캘린더에 점 표시.
  /// PG 는 SELECT DISTINCT 일 때 ORDER BY 가 select list 의 표현식이어야 한다.
  /// 그래서 alias `date` 로 정렬한다.
  private async getMonthlyDates(userId: string) {
    const rows = await this.roomRepository.query(
      `
      SELECT DISTINCT r.date::text AS date
      FROM room_member rm
      JOIN room r ON r.id = rm.room_id
      WHERE rm.user_id = $1
        AND r.status <> 'CANCELLED'
        AND date_trunc('month', r.date) = date_trunc('month', CURRENT_DATE)
      ORDER BY date
      `,
      [userId],
    );
    return rows.map((r: { date: string }) => r.date);
  }
}
