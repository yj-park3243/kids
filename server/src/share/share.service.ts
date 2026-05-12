import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Room } from '../room/entities/room.entity';

const JOIN_TYPE_LABEL: Record<string, string> = {
  FREE: '자유 참여',
  APPROVAL: '승인제',
};

@Injectable()
export class ShareService {
  constructor(
    @InjectRepository(Room)
    private roomRepository: Repository<Room>,
  ) {}

  async getRoomPreview(roomId: string) {
    const room = await this.roomRepository.findOne({ where: { id: roomId } });

    if (!room) {
      throw new NotFoundException('방을 찾을 수 없습니다.');
    }

    if (room.status === 'CANCELLED') {
      throw new NotFoundException('방을 찾을 수 없습니다.');
    }

    // 미래 30일 이후면 비공개
    const now = new Date();
    const roomDate = new Date(room.date);
    const diffDays = (roomDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24);
    if (diffDays > 30) {
      throw new NotFoundException('방을 찾을 수 없습니다.');
    }

    const joinTypeLabel = JOIN_TYPE_LABEL[room.joinType] ?? room.joinType;

    return {
      title: `${room.title} (${room.ageMonthMin}~${room.ageMonthMax}개월)`,
      description: `${room.date} ${room.startTime} · ${room.regionDong} · ${joinTypeLabel}`,
      imageUrl: 'https://cdn.kids.example.com/room-default.webp',
      deeplink: `kids://room/${roomId}`,
    };
  }
}
