import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  ConflictException,
  BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Review } from './entities/review.entity';
import { Room } from '../room/entities/room.entity';
import { RoomMember } from '../room/entities/room-member.entity';
import { User } from '../user/entities/user.entity';
import { MannerScoreService } from '../user/manner-score.service';
import { CreateReviewDto } from './dto/create-review.dto';
import { UpdateReviewDto } from './dto/update-review.dto';

const REVIEW_WINDOW_DAYS = 7;

@Injectable()
export class ReviewService {
  constructor(
    @InjectRepository(Review)
    private reviewRepository: Repository<Review>,
    @InjectRepository(Room)
    private roomRepository: Repository<Room>,
    @InjectRepository(RoomMember)
    private roomMemberRepository: Repository<RoomMember>,
    @InjectRepository(User)
    private userRepository: Repository<User>,
    private mannerScoreService: MannerScoreService,
  ) {}

  async create(roomId: string, authorUserId: string, dto: CreateReviewDto) {
    if (dto.targetUserId === authorUserId) {
      throw new BadRequestException('자기 자신에게 후기를 작성할 수 없습니다.');
    }

    const room = await this.roomRepository.findOne({ where: { id: roomId } });
    if (!room) {
      throw new NotFoundException('방을 찾을 수 없습니다.');
    }
    this.assertReviewable(room);

    await this.assertBothMembers(roomId, authorUserId, dto.targetUserId);

    const existing = await this.reviewRepository.findOne({
      where: {
        roomId,
        authorId: authorUserId,
        targetUserId: dto.targetUserId,
      },
    });
    if (existing) {
      throw new ConflictException({
        code: 'REVIEW_ALREADY_EXISTS',
        message: '이미 후기를 작성했습니다. 수정해주세요.',
      });
    }

    const review = this.reviewRepository.create({
      roomId,
      authorId: authorUserId,
      targetUserId: dto.targetUserId,
      score: dto.score,
      tags: dto.tags ?? [],
      comment: dto.comment ?? null,
    });
    const saved = await this.reviewRepository.save(review);

    await this.mannerScoreService.recalc(dto.targetUserId);

    return this.toResponse(saved);
  }

  async update(reviewId: string, userId: string, dto: UpdateReviewDto) {
    const review = await this.reviewRepository.findOne({
      where: { id: reviewId },
    });
    if (!review) {
      throw new NotFoundException('후기를 찾을 수 없습니다.');
    }
    if (review.authorId !== userId) {
      throw new ForbiddenException('본인 후기만 수정할 수 있습니다.');
    }

    const room = await this.roomRepository.findOne({
      where: { id: review.roomId },
    });
    if (!room) {
      throw new NotFoundException('방을 찾을 수 없습니다.');
    }
    this.assertReviewable(room);

    if (dto.score !== undefined) review.score = dto.score;
    if (dto.tags !== undefined) review.tags = dto.tags;
    if (dto.comment !== undefined) review.comment = dto.comment;

    const saved = await this.reviewRepository.save(review);
    await this.mannerScoreService.recalc(review.targetUserId);

    return this.toResponse(saved);
  }

  async delete(reviewId: string, userId: string) {
    const review = await this.reviewRepository.findOne({
      where: { id: reviewId },
    });
    if (!review) {
      throw new NotFoundException('후기를 찾을 수 없습니다.');
    }
    if (review.authorId !== userId) {
      throw new ForbiddenException('본인 후기만 삭제할 수 있습니다.');
    }

    const room = await this.roomRepository.findOne({
      where: { id: review.roomId },
    });
    if (!room) {
      throw new NotFoundException('방을 찾을 수 없습니다.');
    }
    this.assertReviewable(room);

    const targetUserId = review.targetUserId;
    await this.reviewRepository.delete({ id: reviewId });
    await this.mannerScoreService.recalc(targetUserId);

    return { success: true };
  }

  async getUserReviewsAggregate(userId: string) {
    const user = await this.userRepository.findOne({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('사용자를 찾을 수 없습니다.');
    }

    const reviews = await this.reviewRepository.find({
      where: { targetUserId: userId },
    });

    const scoreDistribution: Record<string, number> = {
      '1': 0,
      '2': 0,
      '3': 0,
      '4': 0,
      '5': 0,
    };
    const tagCount: Record<string, number> = {};
    for (const r of reviews) {
      scoreDistribution[String(r.score)] =
        (scoreDistribution[String(r.score)] ?? 0) + 1;
      for (const t of r.tags ?? []) {
        tagCount[t] = (tagCount[t] ?? 0) + 1;
      }
    }

    const topTags = Object.entries(tagCount)
      .map(([tag, count]) => ({ tag, count }))
      .sort((a, b) => b.count - a.count)
      .slice(0, 3);

    return {
      mannerScore: Number(user.mannerScore),
      reviewCount: reviews.length,
      scoreDistribution,
      topTags,
    };
  }

  private assertReviewable(room: Room) {
    if (room.status !== 'COMPLETED') {
      throw new ForbiddenException({
        code: 'ROOM_NOT_COMPLETED',
        message: '종료된 모임에만 후기를 작성할 수 있습니다.',
      });
    }
    if (!room.completedAt) {
      throw new ForbiddenException({
        code: 'ROOM_NOT_COMPLETED',
        message: '종료 시점이 기록되지 않은 모임입니다.',
      });
    }
    const deadline = new Date(
      room.completedAt.getTime() + REVIEW_WINDOW_DAYS * 24 * 60 * 60 * 1000,
    );
    if (Date.now() >= deadline.getTime()) {
      throw new ForbiddenException({
        code: 'REVIEW_PERIOD_EXPIRED',
        message: '후기 작성 가능 기간(7일)이 지났습니다.',
      });
    }
  }

  private async assertBothMembers(
    roomId: string,
    authorId: string,
    targetUserId: string,
  ) {
    const [authorMember, targetMember] = await Promise.all([
      this.roomMemberRepository.findOne({
        where: { roomId, userId: authorId },
      }),
      this.roomMemberRepository.findOne({
        where: { roomId, userId: targetUserId },
      }),
    ]);
    if (!authorMember || !targetMember) {
      throw new ForbiddenException({
        code: 'NOT_ROOM_MEMBER',
        message: '같은 방의 멤버가 아닙니다.',
      });
    }
  }

  private toResponse(review: Review) {
    return {
      id: review.id,
      roomId: review.roomId,
      targetUserId: review.targetUserId,
      score: review.score,
      tags: review.tags,
      comment: review.comment,
      createdAt: review.createdAt,
    };
  }
}
