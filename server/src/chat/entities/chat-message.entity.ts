import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
  Index,
} from 'typeorm';
import { Room } from '../../room/entities/room.entity';
import { User } from '../../user/entities/user.entity';

export type ChatMessageType = 'TEXT' | 'SYSTEM' | 'IMAGE';

@Entity('chat_message')
@Index(['roomId', 'createdAt'])
export class ChatMessage {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'room_id', type: 'uuid' })
  roomId: string;

  @Column({ name: 'sender_id', type: 'uuid', nullable: true })
  senderId: string | null;

  @Column({ name: 'sender_nickname', type: 'varchar', length: 40 })
  senderNickname: string;

  @Column({ type: 'text' })
  content: string;

  @Column({ type: 'varchar', length: 10, default: 'TEXT' })
  type: ChatMessageType;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @ManyToOne(() => Room, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'room_id' })
  room: Room;

  @ManyToOne(() => User, { onDelete: 'SET NULL', nullable: true })
  @JoinColumn({ name: 'sender_id' })
  sender: User | null;
}
