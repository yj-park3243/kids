import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  OneToMany,
  JoinColumn,
  Index,
} from 'typeorm';
import { User } from '../../user/entities/user.entity';
import { RoomMember } from './room-member.entity';
import { JoinRequest } from './join-request.entity';

@Entity('room')
@Index(['regionSido', 'regionSigungu', 'regionDong'])
@Index(['date'])
@Index(['status'])
@Index(['ageMonthMin', 'ageMonthMax'])
@Index(['latitude', 'longitude'])
@Index(['regionDong', 'date', 'status'])
export class Room {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'host_id', type: 'uuid' })
  hostId: string;

  @Column({ type: 'varchar', length: 60 })
  title: string;

  @Column({ type: 'varchar', length: 1000 })
  description: string;

  @Column({ name: 'region_sido', type: 'varchar', length: 20 })
  regionSido: string;

  @Column({ name: 'region_sigungu', type: 'varchar', length: 20 })
  regionSigungu: string;

  @Column({ name: 'region_dong', type: 'varchar', length: 20 })
  regionDong: string;

  @Column({ type: 'date' })
  date: string;

  @Column({ name: 'start_time', type: 'time' })
  startTime: string;

  @Column({ name: 'end_time', type: 'time', nullable: true })
  endTime: string;

  @Column({ name: 'age_month_min', type: 'int' })
  ageMonthMin: number;

  @Column({ name: 'age_month_max', type: 'int' })
  ageMonthMax: number;

  @Column({ name: 'place_type', type: 'varchar', length: 20 })
  placeType: string; // PLAYGROUND, KIDS_CAFE, PARTY_ROOM, PARK, OTHER

  @Column({ name: 'place_name', type: 'varchar', length: 100, nullable: true })
  placeName: string;

  @Column({ name: 'place_address', type: 'varchar', length: 200, nullable: true })
  placeAddress: string;

  @Column({ type: 'double precision', nullable: true })
  latitude: number;

  @Column({ type: 'double precision', nullable: true })
  longitude: number;

  @Column({ name: 'max_members', type: 'int' })
  maxMembers: number;

  @Column({ name: 'current_members', type: 'int', default: 1 })
  currentMembers: number;

  @Column({ name: 'join_type', type: 'varchar', length: 20 })
  joinType: string; // FREE, APPROVAL

  @Column({ type: 'int', default: 0 })
  cost: number;

  @Column({ name: 'cost_description', type: 'varchar', length: 200, nullable: true })
  costDescription: string;

  @Column({ type: 'text', array: true, nullable: true })
  tags: string[];

  @Column({ type: 'varchar', length: 20, default: 'RECRUITING' })
  status: string; // RECRUITING, CLOSED, IN_PROGRESS, COMPLETED, CANCELLED

  @Column({ name: 'chat_room_id', type: 'uuid', nullable: true })
  chatRoomId: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;

  // Relations
  @ManyToOne(() => User, (user) => user.hostedRooms, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'host_id' })
  host: User;

  @OneToMany(() => RoomMember, (member) => member.room)
  members: RoomMember[];

  @OneToMany(() => JoinRequest, (request) => request.room)
  joinRequests: JoinRequest[];
}
