import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  Inject,
  forwardRef,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Room } from './entities/room.entity';
import { RoomMember } from './entities/room-member.entity';
import { User } from '../user/entities/user.entity';
import { NoShowService } from '../user/no-show.service';
import { MannerScoreService } from '../user/manner-score.service';
import { kstDateTime } from '../common/utils/kst';

interface AttendanceRecord {
  userId: string;
  attended: boolean;
}

@Injectable()
export class RoomAttendanceService {
  constructor(
    @InjectRepository(Room)
    private roomRepository: Repository<Room>,
    @InjectRepository(RoomMember)
    private roomMemberRepository: Repository<RoomMember>,
    @InjectRepository(User)
    private userRepository: Repository<User>,
    @Inject(forwardRef(() => NoShowService))
    private noShowService: NoShowService,
    @Inject(forwardRef(() => MannerScoreService))
    private mannerScoreService: MannerScoreService,
  ) {}

  async submitAttendance(
    hostUserId: string,
    roomId: string,
    records: AttendanceRecord[],
  ) {
    const room = await this.roomRepository.findOne({ where: { id: roomId } });
    if (!room) throw new NotFoundException('방을 찾을 수 없습니다.');
    if (room.hostId !== hostUserId) {
      throw new ForbiddenException({ code: 'NOT_HOST', message: '방장만 출석 체크할 수 있습니다.' });
    }

    // 허용 시간대: 시작 +30분 ~ 종료(또는 시작+3h) +24h
    const startDt = kstDateTime(room.date, room.startTime);
    const endDt = room.endTime
      ? kstDateTime(room.date, room.endTime)
      : new Date(startDt.getTime() + 3 * 60 * 60 * 1000);
    const opens = startDt.getTime() + 30 * 60 * 1000;
    const closes = endDt.getTime() + 24 * 60 * 60 * 1000;
    const now = Date.now();
    if (now < opens || now > closes) {
      throw new BadRequestException({
        code: 'ATTENDANCE_WINDOW_CLOSED',
        message: '출석 체크 가능 시간대가 아닙니다.',
      });
    }

    const members = await this.roomMemberRepository.find({ where: { roomId } });
    const memberMap = new Map(members.map((m) => [m.userId, m]));

    const noShowApplied: Array<{ userId: string; noShowCount: number; restrictedUntil: Date | null }> = [];
    let updated = 0;

    for (const r of records) {
      const m = memberMap.get(r.userId);
      if (!m || m.isHost) continue;
      // 재제출 멱등성 — 이전 기록과 비교해 상태가 바뀔 때만 노쇼를 가감한다.
      // (같은 불참을 두 번 저장해도 벌점이 중복되지 않고, 불참→출석 정정은 벌점을 되돌린다)
      const prev = m.attended;
      m.attended = r.attended;
      m.attendanceRecordedAt = new Date();
      await this.roomMemberRepository.save(m);
      updated += 1;

      if (r.attended === true && prev === false) {
        await this.noShowService.revertAbsence(r.userId);
        continue;
      }
      if (r.attended === false && prev !== false) {
        await this.noShowService.incrementForAbsence(r.userId);
        await this.mannerScoreService.recalc(r.userId);
        const fresh = await this.userRepository.findOne({ where: { id: r.userId } });
        noShowApplied.push({
          userId: r.userId,
          noShowCount: fresh ? Number(fresh.noShowCount) : 0,
          restrictedUntil: fresh?.canJoinAt ?? null,
        });
      }
    }

    return { updated, noShowApplied };
  }
}
