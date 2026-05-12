import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
  Index,
  Check,
} from 'typeorm';
import { User } from '../../user/entities/user.entity';

@Entity('report')
@Index(['status', 'createdAt'])
@Index(['targetType', 'targetId'])
@Index(['reporterId'])
@Check(`"target_type" IN ('USER','ROOM','CHAT_MESSAGE')`)
@Check(`"status" IN ('PENDING','RESOLVED','DISMISSED')`)
export class Report {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'reporter_id', type: 'uuid' })
  reporterId: string;

  @Column({ name: 'target_type', type: 'varchar', length: 20 })
  targetType: string; // USER | ROOM | CHAT_MESSAGE

  @Column({ name: 'target_id', type: 'uuid' })
  targetId: string;

  @Column({ type: 'varchar', length: 30 })
  reason: string; // SPAM | INAPPROPRIATE | HARASSMENT | FAKE_PROFILE | NO_SHOW | OTHER

  @Column({ type: 'varchar', length: 500, nullable: true })
  description: string | null;

  @Column({ type: 'varchar', length: 20, default: 'PENDING' })
  status: string; // PENDING | RESOLVED | DISMISSED

  @Column({ name: 'admin_action', type: 'varchar', length: 20, nullable: true })
  adminAction: string | null; // NONE | WARNING | BAN_7D | BAN_PERMANENT

  @Column({ name: 'admin_note', type: 'varchar', length: 500, nullable: true })
  adminNote: string | null;

  @Column({ name: 'resolved_by', type: 'uuid', nullable: true })
  resolvedBy: string | null;

  @Column({ name: 'resolved_at', type: 'timestamp', nullable: true })
  resolvedAt: Date | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'reporter_id' })
  reporter: User;

  @ManyToOne(() => User, { nullable: true })
  @JoinColumn({ name: 'resolved_by' })
  resolver: User | null;
}
