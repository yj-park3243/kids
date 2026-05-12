import {
  Entity,
  PrimaryColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  Check,
} from 'typeorm';

@Entity('growth_guide')
@Check(`"age_month" BETWEEN 0 AND 72`)
export class GrowthGuide {
  @PrimaryColumn({ name: 'age_month', type: 'smallint' })
  ageMonth: number;

  @Column({ type: 'varchar', length: 100 })
  title: string;

  @Column({ type: 'varchar', length: 300 })
  summary: string;

  @Column({ name: 'body_markdown', type: 'text' })
  bodyMarkdown: string;

  @Column({ name: 'cover_image_url', type: 'text', nullable: true })
  coverImageUrl: string | null;

  @Column({ type: 'text', array: true, default: () => "'{}'" })
  tags: string[];

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
