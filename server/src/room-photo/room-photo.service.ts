import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, MoreThan, Not, Repository } from 'typeorm';

import { Child } from '../child/entities/child.entity';
import { NotificationService } from '../notification/notification.service';
import { Room } from '../room/entities/room.entity';
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
    @InjectRepository(Room)
    private readonly roomRepo: Repository<Room>,
    @InjectRepository(Child)
    private readonly childRepo: Repository<Child>,
    private readonly uploadService: UploadService,
    private readonly notificationService: NotificationService,
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
    // 푸시 — 업로더 제외 방 멤버에게. 실패해도 업로드 흐름은 막지 않는다.
    void this.pushNewPhoto(saved);
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

    // 새로 추가된 태그만 알림 대상 — 교체 전 기존 태그를 기억해 둔다.
    const oldTags = await this.tagRepo.find({ where: { photoId } });
    const oldIds = new Set(oldTags.map((t) => t.childId));

    // 기존 태그 삭제 후 전부 새로 (UI 가 전체 리스트를 보내는 단순한 contract)
    await this.tagRepo.delete({ photoId });
    if (dto.childIds.length > 0) {
      // 중복 제거
      const unique = Array.from(new Set(dto.childIds));
      await this.tagRepo.save(
        unique.map((childId) => this.tagRepo.create({ photoId, childId })),
      );
      const added = unique.filter((id) => !oldIds.has(id));
      if (added.length > 0) void this.pushPhotoTagged(photo, userId, added);
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
    // 사진 업로더에게 댓글 알림 (본인 댓글 제외).
    this.pushPhotoComment(photo, userId, saved.userNickname, saved.content);
    return {
      id: saved.id,
      userId: saved.userId,
      userNickname: saved.userNickname,
      content: saved.content,
      createdAt: saved.createdAt,
    };
  }

  // ─── 푸시 ────────────────────────────────────────────────────────

  /**
   * 새 사진 알림 — 업로더 제외 방 멤버 전원.
   * 여러 장 연속 업로드 스팸 방지: 같은 업로더가 10분 내 올린 직전 사진이
   * 있으면 이번 건은 생략 (배치의 첫 장만 알림).
   */
  private async pushNewPhoto(photo: RoomPhoto): Promise<void> {
    if (!photo.uploaderId) return; // 업로더 탈퇴 등 — 알림 기준점 없음
    try {
      const cutoff = new Date(Date.now() - 10 * 60 * 1000);
      const recent = await this.photoRepo.findOne({
        where: {
          roomId: photo.roomId,
          uploaderId: photo.uploaderId,
          id: Not(photo.id),
          createdAt: MoreThan(cutoff),
        },
      });
      if (recent) return;

      const room = await this.roomRepo.findOne({
        where: { id: photo.roomId },
      });
      const members = await this.memberRepo.find({
        where: { roomId: photo.roomId },
      });
      for (const m of members) {
        if (m.userId === photo.uploaderId) continue;
        void this.notificationService
          .create({
            userId: m.userId,
            type: 'NEW_PHOTO',
            title: room?.title ?? '모임 사진',
            body: `${photo.uploaderNickname}님이 사진을 올렸어요.`,
            data: { roomId: photo.roomId, photoId: photo.id },
          })
          .catch(() => undefined);
      }
    } catch {
      // 푸시 실패는 업로드 흐름을 막지 않는다.
    }
  }

  /** 댓글 알림 — 사진 업로더에게 (본인 댓글이면 생략). */
  private pushPhotoComment(
    photo: RoomPhoto,
    commenterId: string,
    commenterNickname: string,
    content: string,
  ): void {
    if (!photo.uploaderId || photo.uploaderId === commenterId) return;
    void this.notificationService
      .create({
        userId: photo.uploaderId,
        type: 'PHOTO_COMMENT',
        title: '사진 댓글',
        body: `${commenterNickname}: ${content.slice(0, 80)}`,
        data: { roomId: photo.roomId, photoId: photo.id },
      })
      .catch(() => undefined);
  }

  /** 태그 알림 — 새로 태그된 아이의 부모에게 (태그한 본인 아이는 생략). */
  private async pushPhotoTagged(
    photo: RoomPhoto,
    taggerId: string,
    childIds: string[],
  ): Promise<void> {
    try {
      const children = await this.childRepo.find({
        where: { id: In(childIds) },
      });
      for (const child of children) {
        if (child.userId === taggerId) continue;
        void this.notificationService
          .create({
            userId: child.userId,
            type: 'PHOTO_TAG',
            title: '사진 태그',
            body: `${child.nickname}(이)가 모임 사진에 태그됐어요.`,
            data: { roomId: photo.roomId, photoId: photo.id },
          })
          .catch(() => undefined);
      }
    } catch {
      // 푸시 실패는 태그 저장 흐름을 막지 않는다.
    }
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
