import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  Index,
} from 'typeorm';

@Entity('room_photo')
export class RoomPhoto {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'room_id', type: 'uuid' })
  @Index()
  roomId: string;

  @Column({ name: 'uploader_id', type: 'uuid', nullable: true })
  uploaderId: string | null;

  @Column({ name: 'uploader_nickname', type: 'varchar', length: 40 })
  uploaderNickname: string;

  @Column({ type: 'text' })
  url: string;

  @CreateDateColumn({ name: 'created_at' })
  @Index()
  createdAt: Date;
}
