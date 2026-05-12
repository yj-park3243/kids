import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  Index,
} from 'typeorm';

@Entity('user_report')
export class UserReport {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'reporter_id', type: 'uuid' })
  reporterId: string;

  @Column({ name: 'target_user_id', type: 'uuid', nullable: true })
  @Index()
  targetUserId: string | null;

  @Column({ name: 'target_room_id', type: 'uuid', nullable: true })
  targetRoomId: string | null;

  @Column({ type: 'varchar', length: 50 })
  reason: string; // SPAM | ABUSE | INAPPROPRIATE | FRAUD | OTHER

  @Column({ type: 'text', nullable: true })
  detail: string | null;

  @Column({ type: 'varchar', length: 20, default: 'OPEN' })
  @Index()
  status: string; // OPEN | REVIEWED | RESOLVED | DISMISSED

  // 관리자 처리 메타 — 신고 처리 시 채움.
  @Column({ name: 'admin_action', type: 'varchar', length: 30, nullable: true })
  adminAction: string | null; // NONE | WARNING | BAN_7D | BAN_PERMANENT

  @Column({ name: 'admin_note', type: 'text', nullable: true })
  adminNote: string | null;

  @Column({ name: 'resolved_at', type: 'timestamp', nullable: true })
  resolvedAt: Date | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamp' })
  createdAt: Date;
}
