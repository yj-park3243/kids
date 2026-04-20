import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  OneToMany,
  Index,
} from 'typeorm';
import { Child } from '../../child/entities/child.entity';
import { Room } from '../../room/entities/room.entity';
import { RoomMember } from '../../room/entities/room-member.entity';
import { JoinRequest } from '../../room/entities/join-request.entity';
import { Notification } from '../../notification/entities/notification.entity';
import { DeviceToken } from '../../notification/entities/device-token.entity';
import { RefreshToken } from '../../auth/entities/refresh-token.entity';

@Entity('user')
@Index(['regionSido', 'regionSigungu', 'regionDong'])
export class User {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'auth_provider', type: 'varchar', length: 20 })
  authProvider: string; // KAKAO, APPLE, GOOGLE, EMAIL

  @Column({ name: 'social_id', type: 'varchar', length: 100, nullable: true, unique: true })
  socialId: string;

  @Column({ type: 'varchar', length: 255, nullable: true, unique: true })
  email: string;

  @Column({ name: 'password_hash', type: 'varchar', length: 255, nullable: true })
  passwordHash: string;

  @Column({ type: 'varchar', length: 20, nullable: true, unique: true })
  nickname: string;

  @Column({ name: 'profile_image_url', type: 'text', nullable: true })
  profileImageUrl: string;

  @Column({ type: 'varchar', length: 200, nullable: true })
  introduction: string;

  @Column({ name: 'region_sido', type: 'varchar', length: 20, nullable: true })
  regionSido: string;

  @Column({ name: 'region_sigungu', type: 'varchar', length: 20, nullable: true })
  regionSigungu: string;

  @Column({ name: 'region_dong', type: 'varchar', length: 20, nullable: true })
  regionDong: string;

  @Column({ name: 'is_profile_complete', type: 'boolean', default: false })
  isProfileComplete: boolean;

  @Column({ name: 'is_phone_verified', type: 'boolean', default: false })
  isPhoneVerified: boolean;

  @Column({ name: 'phone_number', type: 'varchar', length: 20, nullable: true })
  phoneNumber: string;

  @Column({ name: 'is_admin', type: 'boolean', default: false })
  isAdmin: boolean;

  @Column({ type: 'varchar', length: 20, default: 'ACTIVE' })
  status: string; // ACTIVE, WITHDRAWN, BANNED

  @Column({ name: 'withdrawn_at', type: 'timestamp', nullable: true })
  withdrawnAt: Date;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;

  // Relations
  @OneToMany(() => Child, (child) => child.user)
  children: Child[];

  @OneToMany(() => Room, (room) => room.host)
  hostedRooms: Room[];

  @OneToMany(() => RoomMember, (member) => member.user)
  roomMembers: RoomMember[];

  @OneToMany(() => JoinRequest, (request) => request.user)
  joinRequests: JoinRequest[];

  @OneToMany(() => Notification, (notification) => notification.user)
  notifications: Notification[];

  @OneToMany(() => DeviceToken, (token) => token.user)
  deviceTokens: DeviceToken[];

  @OneToMany(() => RefreshToken, (token) => token.user)
  refreshTokens: RefreshToken[];
}
