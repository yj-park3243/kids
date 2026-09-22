// 서버 프로세스는 UTC 로 돈다(EC2·pm2 모두 TZ 미설정, DB 의 timestamp 컬럼도 UTC 벽시계).
// 반면 room.date / room.startTime 은 사용자가 입력한 한국 시간 벽시계다.
// 이 둘을 섞는 곳(스케줄러·출석 시간대·취소 기한·집계 날짜)은 반드시 여기를 거친다.
// 프로세스 TZ 를 Asia/Seoul 로 바꾸면 timestamp 컬럼 읽기가 9시간 어긋나므로 그 방법은 쓰지 않는다.

const KST_OFFSET_MS = 9 * 60 * 60 * 1000;

/** 'YYYY-MM-DD' + 'HH:mm[:ss]' (KST 벽시계) → 절대 시각 */
export function kstDateTime(date: string, time: string): Date {
  const hms = time.length === 5 ? `${time}:00` : time;
  return new Date(`${date}T${hms}+09:00`);
}

/** 주어진 시각의 KST 날짜 'YYYY-MM-DD' */
export function kstDateString(at: Date = new Date()): string {
  return new Date(at.getTime() + KST_OFFSET_MS).toISOString().slice(0, 10);
}

/** 주어진 시각의 KST 시각 'HH:mm' */
export function kstTimeString(at: Date = new Date()): string {
  return new Date(at.getTime() + KST_OFFSET_MS).toISOString().slice(11, 16);
}
