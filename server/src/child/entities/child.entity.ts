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
