import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  Index,
} from 'typeorm';

@Entity('room_photo_comment')
export class RoomPhotoComment {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'photo_id', type: 'uuid' })
  @Index()
  photoId: string;

  @Column({ name: 'user_id', type: 'uuid', nullable: true })
  userId: string | null;

  @Column({ name: 'user_nickname', type: 'varchar', length: 40 })
  userNickname: string;

  @Column({ type: 'text' })
  content: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
