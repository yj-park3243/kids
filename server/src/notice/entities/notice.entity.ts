import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  Index,
} from 'typeorm';

@Entity('notice')
@Index(['isPublished', 'isPinned'])
export class Notice {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'varchar', length: 200 })
  title: string;

  @Column({ type: 'text' })
  content: string;

  // 홈 화면 상단 배너 노출 여부
  @Column({ name: 'is_pinned', type: 'boolean', default: false })
  isPinned: boolean;

  // 게시 여부 (false 면 사용자에게 안 보임)
  @Column({ name: 'is_published', type: 'boolean', default: true })
  isPublished: boolean;

  @Column({ name: 'author_id', type: 'uuid', nullable: true })
  authorId: string | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
