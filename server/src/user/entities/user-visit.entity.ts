import { Entity, PrimaryColumn, Column, Index } from 'typeorm';

@Entity('user_visit')
@Index(['visitDate'])
export class UserVisit {
  @PrimaryColumn({ name: 'user_id', type: 'uuid' })
  userId: string;

  @PrimaryColumn({ name: 'visit_date', type: 'date' })
  visitDate: string;
}
