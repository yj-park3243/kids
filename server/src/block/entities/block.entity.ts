import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
  Unique,
  Index,
  Check,
} from 'typeorm';
import { User } from '../../user/entities/user.entity';

@Entity('block')
@Unique(['blockerId', 'targetUserId'])
@Index(['targetUserId'])
@Check(`"blocker_id" <> "target_user_id"`)
export class Block {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'blocker_id', type: 'uuid' })
  blockerId: string;

  @Column({ name: 'target_user_id', type: 'uuid' })
  targetUserId: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  // Relations
  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'blocker_id' })
  blocker: User;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'target_user_id' })
  targetUser: User;
}
