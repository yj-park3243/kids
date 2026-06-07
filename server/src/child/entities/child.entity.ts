import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
  Index,
} from 'typeorm';
import { User } from '../../user/entities/user.entity';

@Entity('child')
@Index(['userId'])
export class Child {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id', type: 'uuid' })
  userId: string;

  @Column({ type: 'varchar', length: 20 })
  nickname: string;

  @Column({ name: 'birth_year', type: 'int' })
  birthYear: number;

  @Column({ name: 'birth_month', type: 'int' })
  birthMonth: number;

  @Column({ type: 'varchar', length: 10, nullable: true })
  gender: string; // MALE, FEMALE, null

  @Column({ name: 'photo_url', type: 'varchar', length: 500, nullable: true })
  photoUrl: string; // 프로필 사진 — 공개 노출 (마이페이지/방 등).

  @Column({
    name: 'verification_photo_url',
    type: 'varchar',
    length: 500,
    nullable: true,
  })
  verificationPhotoUrl: string; // 출생증명서/키즈노트 캡쳐 — 어드민 검수 전용, 비공개.

  // 'MORNING' | 'AFTERNOON' | 'LATE_AFTERNOON' | 'EVENING' | 'NONE' | null
  @Column({ name: 'nap_time', type: 'varchar', length: 20, nullable: true })
  napTime: string;

  // 기질 태그 — 최대 5개. 클라이언트 키(영문) 배열로 저장하고 라벨은 앱에서 매핑.
  @Column({ name: 'temperament_tags', type: 'jsonb', nullable: true })
  temperamentTags: string[];

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;

  // Relations
  @ManyToOne(() => User, (user) => user.children, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;

  // Computed property
  get ageMonths(): number {
    const now = new Date();
    return (now.getFullYear() - this.birthYear) * 12 + (now.getMonth() + 1 - this.birthMonth);
  }
}
