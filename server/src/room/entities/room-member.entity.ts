import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
  Unique,
  Index,
} from 'typeorm';
import { User } from '../../user/entities/user.entity';
import { Room } from './room.entity';

@Entity('room_member')
@Unique(['roomId', 'userId'])
@Index(['userId'])
export class RoomMember {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'room_id', type: 'uuid' })
  roomId: string;

  @Column({ name: 'user_id', type: 'uuid' })
  userId: string;

  @Column({ name: 'is_host', type: 'boolean', default: false })
  isHost: boolean;

  @Column({ type: 'boolean', nullable: true })
  attended: boolean; // NULL=미체크, TRUE=출석, FALSE=노쇼

  @Column({ name: 'attendance_recorded_at', type: 'timestamp', nullable: true })
  attendanceRecordedAt: Date;

  @Column({ name: 'child_ids', type: 'uuid', array: true, default: () => "'{}'" })
  childIds: string[];

  @Column({ name: 'last_read_at', type: 'timestamp', nullable: true })
  lastReadAt: Date | null;

  @CreateDateColumn({ name: 'joined_at' })
  joinedAt: Date;

  // Relations
  @ManyToOne(() => Room, (room) => room.members, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'room_id' })
  room: Room;

  @ManyToOne(() => User, (user) => user.roomMembers, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;
}
