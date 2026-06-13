import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  OneToMany,
  Index,
  Check,
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
@Check(`"parent_gender" IS NULL OR "parent_gender" IN ('MOM','DAD')`)
@Check(`"manner_score" >= 0 AND "manner_score" <= 99.9`)
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

  // 동네 기준 대략 좌표 (거리 기반 주변 모임/알림용). 지오코딩 실패 시 시군구/동 폴백.
  @Column({ type: 'double precision', nullable: true })
  latitude: number | null;

  @Column({ type: 'double precision', nullable: true })
  longitude: number | null;

  @Column({ name: 'is_profile_complete', type: 'boolean', default: false })
  isProfileComplete: boolean;

  @Column({ name: 'is_phone_verified', type: 'boolean', default: false })
  isPhoneVerified: boolean;

  @Column({ name: 'phone_number', type: 'varchar', length: 20, nullable: true })
  phoneNumber: string;

  // ─── KCP 본인인증 ───
  @Column({ name: 'ci', type: 'varchar', length: 100, nullable: true, unique: true })
  ci: string;

  @Column({ name: 'di', type: 'varchar', length: 100, nullable: true })
  di: string;

  @Column({ name: 'real_name', type: 'varchar', length: 50, nullable: true })
  realName: string;

  @Column({ name: 'carrier', type: 'varchar', length: 20, nullable: true })
  carrier: string;

  @Column({ name: 'birth_date', type: 'date', nullable: true })
  birthDate: Date;

  @Column({ name: 'gender', type: 'varchar', length: 10, nullable: true })
  gender: string; // MALE | FEMALE

  @Column({ name: 'is_verified', type: 'boolean', default: false })
  isVerified: boolean;

  @Column({ name: 'verified_at', type: 'timestamp', nullable: true })
  verifiedAt: Date;

  @Column({ name: 'apple_refresh_token', type: 'text', nullable: true })
  appleRefreshToken: string;

  @Column({ name: 'is_admin', type: 'boolean', default: false })
  isAdmin: boolean;

  @Column({ name: 'last_seen_at', type: 'timestamp', nullable: true })
  @Index()
  lastSeenAt: Date;

  @Column({ name: 'last_login_at', type: 'timestamp', nullable: true })
  @Index()
  lastLoginAt: Date;

  @Column({ type: 'varchar', length: 20, default: 'ACTIVE' })
  status: string; // ACTIVE, WITHDRAWN, BANNED, SUSPENDED

  @Column({ name: 'appeal_photo_url', type: 'varchar', length: 500, nullable: true })
  appealPhotoUrl: string; // 정지(SUSPENDED) 해제 요청용 증거 사진

  @Column({ name: 'suspend_reason', type: 'varchar', length: 200, nullable: true })
  suspendReason: string; // 정지 사유 (어드민 입력)

  @Column({ name: 'parent_gender', type: 'varchar', length: 10, nullable: true })
  parentGender: string; // MOM, DAD

  @Column({ name: 'is_single_parent', type: 'boolean', default: false })
  isSingleParent: boolean;

  // 푸시 알림 설정. notifyAll 을 끄면 모든 푸시 차단(인앱 알림 목록은 유지),
  // notifyRoom/notifyChat 은 카테고리별 차단. 기본 전부 ON.
  @Column({ name: 'notify_all', type: 'boolean', default: true })
  notifyAll: boolean;

  @Column({ name: 'notify_room', type: 'boolean', default: true })
  notifyRoom: boolean;

  @Column({ name: 'notify_chat', type: 'boolean', default: true })
  notifyChat: boolean;

  // 쑥쑥 등급 점수. 가입 시 떡잎(10~29) 중간값 20 으로 시작. 신고/노쇼로 9 이하 떨어지면 새싹으로 강등.
  @Column({ name: 'manner_score', type: 'numeric', precision: 4, scale: 1, default: 20 })
  mannerScore: number;

  @Column({ name: 'no_show_count', type: 'numeric', precision: 4, scale: 1, default: 0 })
  noShowCount: number;

  @Column({ name: 'can_join_at', type: 'timestamp', nullable: true })
  canJoinAt: Date;

  @Column({ name: 'inviter_id', type: 'uuid', nullable: true })
  inviterId: string;

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
