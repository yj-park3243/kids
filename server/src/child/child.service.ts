import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Child } from './entities/child.entity';
import { CreateChildDto } from './dto/create-child.dto';
import { UpdateChildDto } from './dto/update-child.dto';

@Injectable()
export class ChildService {
  constructor(
    @InjectRepository(Child)
    private childRepository: Repository<Child>,
  ) {}

  async create(userId: string, dto: CreateChildDto) {
    // Check max children count (5)
    const count = await this.childRepository.count({ where: { userId } });
    if (count >= 5) {
      throw new BadRequestException('아이는 최대 5명까지 등록 가능합니다.');
    }

    const child = this.childRepository.create({
      userId,
      ...dto,
    });

    const saved = await this.childRepository.save(child);
    return this.formatChild(saved);
  }

  async findAll(userId: string) {
    const children = await this.childRepository.find({
      where: { userId },
      order: { createdAt: 'ASC' },
    });

    return children.map((child) => this.formatChild(child));
  }

  async update(userId: string, childId: string, dto: UpdateChildDto) {
    const child = await this.childRepository.findOne({
      where: { id: childId },
    });

    if (!child) {
      throw new NotFoundException('아이 정보를 찾을 수 없습니다.');
    }

    if (child.userId !== userId) {
      throw new ForbiddenException('권한이 없습니다.');
    }

    Object.assign(child, dto);
    const saved = await this.childRepository.save(child);
    return this.formatChild(saved);
  }

  async delete(userId: string, childId: string) {
    const child = await this.childRepository.findOne({
      where: { id: childId },
    });

    if (!child) {
      throw new NotFoundException('아이 정보를 찾을 수 없습니다.');
    }

    if (child.userId !== userId) {
      throw new ForbiddenException('권한이 없습니다.');
    }

    // Check minimum children count
    const count = await this.childRepository.count({ where: { userId } });
    if (count <= 1) {
      throw new BadRequestException('최소 1명의 아이 정보는 유지해야 합니다.');
    }

    await this.childRepository.remove(child);
    return { success: true };
  }

  private formatChild(child: Child) {
    const now = new Date();
    const ageMonths =
      (now.getFullYear() - child.birthYear) * 12 +
      (now.getMonth() + 1 - child.birthMonth);

    return {
      id: child.id,
      nickname: child.nickname,
      birthYear: child.birthYear,
      birthMonth: child.birthMonth,
      ageMonths,
      gender: child.gender,
      createdAt: child.createdAt,
    };
  }
}
