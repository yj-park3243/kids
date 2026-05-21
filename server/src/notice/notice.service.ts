import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Notice } from './entities/notice.entity';
import { CreateNoticeDto } from './dto/create-notice.dto';
import { UpdateNoticeDto } from './dto/update-notice.dto';

@Injectable()
export class NoticeService {
  constructor(
    @InjectRepository(Notice)
    private noticeRepo: Repository<Notice>,
  ) {}

  /** 사용자 — 게시된 공지 목록 (고정 우선 → 최신순) */
  async findPublished(page = 1, limit = 20) {
    const [items, total] = await this.noticeRepo.findAndCount({
      where: { isPublished: true },
      order: { isPinned: 'DESC', createdAt: 'DESC' },
      skip: (page - 1) * limit,
      take: limit,
    });
    return {
      items,
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    };
  }

  /** 사용자 — 홈 배너용 고정 공지 (최대 5) */
  async findPinned() {
    return this.noticeRepo.find({
      where: { isPinned: true, isPublished: true },
      order: { createdAt: 'DESC' },
      take: 5,
    });
  }

  /** 공지 상세 */
  async findOne(id: string) {
    const notice = await this.noticeRepo.findOne({ where: { id } });
    if (!notice) {
      throw new NotFoundException('공지사항을 찾을 수 없습니다.');
    }
    return notice;
  }

  /** 어드민 — 전체 목록 (미게시 포함) */
  async findAllForAdmin(page = 1, limit = 20) {
    const [items, total] = await this.noticeRepo.findAndCount({
      order: { isPinned: 'DESC', createdAt: 'DESC' },
      skip: (page - 1) * limit,
      take: limit,
    });
    return {
      items,
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    };
  }

  async create(dto: CreateNoticeDto, authorId: string | null) {
    const notice = this.noticeRepo.create({ ...dto, authorId });
    return this.noticeRepo.save(notice);
  }

  async update(id: string, dto: UpdateNoticeDto) {
    const notice = await this.findOne(id);
    Object.assign(notice, dto);
    return this.noticeRepo.save(notice);
  }

  async delete(id: string) {
    const notice = await this.findOne(id);
    await this.noticeRepo.remove(notice);
    return { success: true };
  }
}
