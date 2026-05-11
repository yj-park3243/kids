import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';

import { RoomMember } from '../room/entities/room-member.entity';
import { User } from '../user/entities/user.entity';
import { UploadService } from '../upload/upload.service';
import { RoomPhoto } from './entities/room-photo.entity';
import { RoomPhotoChildTag } from './entities/room-photo-child-tag.entity';
import { RoomPhotoComment } from './entities/room-photo-comment.entity';
import {
  CreatePhotoCommentDto,
  PhotoQueryDto,
  UpdatePhotoTagsDto,
} from './dto/room-photo.dto';

@Injectable()
export class RoomPhotoService {
  constructor(
    @InjectRepository(RoomPhoto)
    private readonly photoRepo: Repository<RoomPhoto>,
    @InjectRepository(RoomPhotoChildTag)
    private readonly tagRepo: Repository<RoomPhotoChildTag>,
    @InjectRepository(RoomPhotoComment)
    private readonly commentRepo: Repository<RoomPhotoComment>,
    @InjectRepository(RoomMember)
    private readonly memberRepo: Repository<RoomMember>,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    private readonly uploadService: UploadService,
  ) {}

  // 권한: 방 멤버여야 함.
  private async assertMember(roomId: string, userId: string): Promise<void> {
    const m = await this.memberRepo.findOne({ where: { roomId, userId } });
    if (!m) throw new ForbiddenException('방 멤버만 접근할 수 있습니다.');
  }

  // ─── 사진 ────────────────────────────────────────────────────────

  async upload(roomId: string, userId: string, file: Express.Multer.File) {
    await this.assertMember(roomId, userId);
    const user = await this.userRepo.findOne({ where: { id: userId } });
    const { url } = await this.uploadService.uploadImage(file);
    const saved = await this.photoRepo.save(
      this.photoRepo.create({
        roomId,
        uploaderId: userId,
        uploaderNickname: user?.nickname ?? '-',
        url,
      }),
    );
    return this._serialize(saved, [], 0);
  }

  async list(roomId: string, userId: string, query: PhotoQueryDto) {
    await this.assertMember(roomId, userId);
    const page = query.page || 1;
    const limit = query.limit || 30;
    const skip = (page - 1) * limit;

    const qb = this.photoRepo
      .createQueryBuilder('p')
      .where('p.roomId = :roomId', { roomId })
      .orderBy('p.createdAt', 'DESC')
      .skip(skip)
      .take(limit);

    if (query.childId) {
      qb.andWhere(
        `EXISTS (SELECT 1 FROM room_photo_child_tag t WHERE t.photo_id = p.id AND t.child_id = :childId)`,
        { childId: query.childId },
      );
    }

    const [photos, total] = await qb.getManyAndCount();

    const photoIds = photos.map((p) => p.id);
    const tags = photoIds.length
      ? await this.tagRepo.find({ where: { photoId: In(photoIds) } })
      : [];
    const tagsByPhoto = new Map<string, string[]>();
    for (const t of tags) {
      const arr = tagsByPhoto.get(t.photoId) ?? [];
      arr.push(t.childId);
      tagsByPhoto.set(t.photoId, arr);
    }

    const commentCounts = photoIds.length
      ? await this.commentRepo
          .createQueryBuilder('c')
          .select('c.photo_id', 'photoId')
          .addSelect('COUNT(*)::int', 'cnt')
          .where('c.photo_id IN (:...ids)', { ids: photoIds })
          .groupBy('c.photo_id')
          .getRawMany<{ photoId: string; cnt: number }>()
      : [];
    const cntByPhoto = new Map(
      commentCounts.map((r) => [r.photoId, Number(r.cnt)]),
    );

    return {
      items: photos.map((p) =>
        this._serialize(
          p,
          tagsByPhoto.get(p.id) ?? [],
          cntByPhoto.get(p.id) ?? 0,
        ),
      ),
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    };
  }

  async getOne(photoId: string, userId: string) {
    const photo = await this.photoRepo.findOne({ where: { id: photoId } });
    if (!photo) throw new NotFoundException('사진을 찾을 수 없습니다.');
    await this.assertMember(photo.roomId, userId);
    const tags = await this.tagRepo.find({ where: { photoId } });
    const cnt = await this.commentRepo.count({ where: { photoId } });
    return this._serialize(
      photo,
      tags.map((t) => t.childId),
      cnt,
    );
  }

  async delete(photoId: string, userId: string) {
    const photo = await this.photoRepo.findOne({ where: { id: photoId } });
    if (!photo) throw new NotFoundException('사진을 찾을 수 없습니다.');
    if (photo.uploaderId !== userId) {
      throw new ForbiddenException('업로드한 사람만 삭제할 수 있습니다.');
    }
    await this.tagRepo.delete({ photoId });
    await this.commentRepo.delete({ photoId });
    await this.photoRepo.delete({ id: photoId });
    return { success: true };
  }

  // ─── 태그 ────────────────────────────────────────────────────────

  async updateTags(photoId: string, userId: string, dto: UpdatePhotoTagsDto) {
    const photo = await this.photoRepo.findOne({ where: { id: photoId } });
    if (!photo) throw new NotFoundException('사진을 찾을 수 없습니다.');
    await this.assertMember(photo.roomId, userId);

    // 기존 태그 삭제 후 전부 새로 (UI 가 전체 리스트를 보내는 단순한 contract)
    await this.tagRepo.delete({ photoId });
    if (dto.childIds.length > 0) {
      // 중복 제거
      const unique = Array.from(new Set(dto.childIds));
      await this.tagRepo.save(
        unique.map((childId) => this.tagRepo.create({ photoId, childId })),
      );
    }
    return { success: true, childIds: dto.childIds };
  }

  // ─── 댓글 ────────────────────────────────────────────────────────

  async listComments(photoId: string, userId: string) {
    const photo = await this.photoRepo.findOne({ where: { id: photoId } });
    if (!photo) throw new NotFoundException('사진을 찾을 수 없습니다.');
    await this.assertMember(photo.roomId, userId);

    const comments = await this.commentRepo.find({
      where: { photoId },
      order: { createdAt: 'ASC' },
    });
    return {
      items: comments.map((c) => ({
        id: c.id,
        userId: c.userId,
        userNickname: c.userNickname,
        content: c.content,
        createdAt: c.createdAt,
      })),
    };
  }

  async addComment(photoId: string, userId: string, dto: CreatePhotoCommentDto) {
    const photo = await this.photoRepo.findOne({ where: { id: photoId } });
    if (!photo) throw new NotFoundException('사진을 찾을 수 없습니다.');
    await this.assertMember(photo.roomId, userId);

    const user = await this.userRepo.findOne({ where: { id: userId } });
    const saved = await this.commentRepo.save(
      this.commentRepo.create({
        photoId,
        userId,
        userNickname: user?.nickname ?? '-',
        content: dto.content,
      }),
    );
    return {
      id: saved.id,
      userId: saved.userId,
      userNickname: saved.userNickname,
      content: saved.content,
      createdAt: saved.createdAt,
    };
  }

  // ─── helpers ─────────────────────────────────────────────────────

  private _serialize(p: RoomPhoto, childIds: string[], commentCount: number) {
    return {
      id: p.id,
      roomId: p.roomId,
      uploaderId: p.uploaderId,
      uploaderNickname: p.uploaderNickname,
      url: p.url,
      childIds,
      commentCount,
      createdAt: p.createdAt,
    };
  }
}
