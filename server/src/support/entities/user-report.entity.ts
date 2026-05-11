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
  status: string;

  @CreateDateColumn({ name: 'created_at', type: 'timestamp' })
  createdAt: Date;
}
