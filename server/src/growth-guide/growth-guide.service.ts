import {
  Injectable,
  Logger,
  NotFoundException,
  OnModuleInit,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { LessThanOrEqual, Repository } from 'typeorm';
import { GrowthGuide } from './entities/growth-guide.entity';
import { Room } from '../room/entities/room.entity';
import { Child } from '../child/entities/child.entity';
import { CreateGuideDto } from './dto/create-guide.dto';
import { UpdateGuideDto } from './dto/update-guide.dto';
import { GROWTH_GUIDE_SEEDS } from './growth-guide.seed';

export interface GuideView {
  ageMonth: number;
  title: string;
  summary: string;
  bodyMarkdown: string;
  coverImage: string | null;
  tags: string[];
}

@Injectable()
export class GrowthGuideService implements OnModuleInit {
  private readonly logger = new Logger(GrowthGuideService.name);

  constructor(
    @InjectRepository(GrowthGuide)
    private guideRepository: Repository<GrowthGuide>,
    @InjectRepository(Room)
    private roomRepository: Repository<Room>,
    @InjectRepository(Child)
    private childRepository: Repository<Child>,
  ) {}

  /**
   * 부팅 시 시드 데이터가 비어있으면 자동 적재. 이미 존재하는 ageMonth는 건드리지 않는다.
   * 테이블이 아직 마이그레이션 안 된 환경에서도 부팅이 막히지 않도록 에러는 삼킨다.
   */
  async onModuleInit() {
    try {
      const count = await this.guideRepository.count();
      if (count >= GROWTH_GUIDE_SEEDS.length) return;

      const existing = await this.guideRepository.find({ select: ['ageMonth'] });
      const existingMonths = new Set(existing.map((g) => g.ageMonth));
      const toInsert = GROWTH_GUIDE_SEEDS.filter(
        (s) => !existingMonths.has(s.ageMonth),
      );
      if (toInsert.length === 0) return;

      await this.guideRepository.save(
        toInsert.map((s) =>
          this.guideRepository.create({
            ageMonth: s.ageMonth,
            title: s.title,
            summary: s.summary,
            bodyMarkdown: s.bodyMarkdown,
            tags: s.tags,
            coverImageUrl: null,
          }),
        ),
      );
      this.logger.log(`Seeded ${toInsert.length} growth guides`);
    } catch (e) {
      this.logger.warn(
        `growth_guide seed skipped: ${(e as Error).message}`,
      );
    }
  }

  private toView(guide: GrowthGuide): GuideView {
    return {
      ageMonth: guide.ageMonth,
      title: guide.title,
      summary: guide.summary,
      bodyMarkdown: guide.bodyMarkdown,
      coverImage: guide.coverImageUrl,
      tags: guide.tags ?? [],
    };
  }

  async findAll(): Promise<GuideView[]> {
    const guides = await this.guideRepository.find({
      order: { ageMonth: 'ASC' },
    });
    return guides.map((g) => this.toView(g));
  }

  /**
   * 정확한 월령 가이드가 없으면 같거나 작은 가장 큰 마일스톤으로 폴백한다.
   * (예: 7개월 요청 → 6개월 가이드 반환)
   */
  async findByAgeMonth(ageMonth: number, _userId?: string) {
    let guide = await this.guideRepository.findOne({ where: { ageMonth } });
    if (!guide) {
      guide = await this.guideRepository.findOne({
        where: { ageMonth: LessThanOrEqual(ageMonth) },
        order: { ageMonth: 'DESC' },
      });
    }
    if (!guide) {
      guide = await this.guideRepository.findOne({
        order: { ageMonth: 'ASC' },
      });
    }
    if (!guide) {
      throw new NotFoundException('가이드를 찾을 수 없습니다.');
    }

    const today = new Date().toISOString().split('T')[0];
    const qb = this.roomRepository
      .createQueryBuilder('room')
      .where('room.date >= :today', { today })
      .andWhere('room.status = :status', { status: 'RECRUITING' })
      .andWhere(':ageMonth BETWEEN room.ageMonthMin AND room.ageMonthMax', {
        ageMonth,
      });

    if (guide.tags && guide.tags.length > 0) {
      qb.andWhere('room.tags && ARRAY[:...tags]::text[]', { tags: guide.tags });
    }

    const recommendedRooms = await qb
      .orderBy('room.date', 'ASC')
      .limit(5)
      .getMany();

    return { ...this.toView(guide), recommendedRooms };
  }

  async create(dto: CreateGuideDto) {
    const guide = this.guideRepository.create({
      ageMonth: dto.ageMonth,
      title: dto.title,
      summary: dto.summary,
      bodyMarkdown: dto.bodyMarkdown,
      coverImageUrl: dto.coverImage ?? null,
      tags: dto.tags ?? [],
    });
    const saved = await this.guideRepository.save(guide);
    return this.toView(saved);
  }

  async update(ageMonth: number, dto: UpdateGuideDto) {
    const guide = await this.guideRepository.findOne({ where: { ageMonth } });
    if (!guide) {
      throw new NotFoundException('가이드를 찾을 수 없습니다.');
    }

    if (dto.title !== undefined) guide.title = dto.title;
    if (dto.summary !== undefined) guide.summary = dto.summary;
    if (dto.bodyMarkdown !== undefined) guide.bodyMarkdown = dto.bodyMarkdown;
    if (dto.coverImage !== undefined) guide.coverImageUrl = dto.coverImage;
    if (dto.tags !== undefined) guide.tags = dto.tags;

    const saved = await this.guideRepository.save(guide);
    return this.toView(saved);
  }

  async delete(ageMonth: number) {
    const result = await this.guideRepository.delete({ ageMonth });
    if (result.affected === 0) {
      throw new NotFoundException('가이드를 찾을 수 없습니다.');
    }
    return { success: true };
  }
}
