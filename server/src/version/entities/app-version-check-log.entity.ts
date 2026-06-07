import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  Index,
} from 'typeorm';

// 앱 시작 시 부트스트랩(/app-version) 호출 로그.
// 누가/어떤 버전/어디서 앱을 켰는지 추적용. 저장 실패해도 응답엔 영향 없음.
@Entity('app_version_check_log')
@Index(['createdAt'])
export class AppVersionCheckLog {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id', type: 'uuid', nullable: true })
  userId: string | null;

  @Column({ type: 'varchar', length: 50, nullable: true })
  nickname: string | null;

  @Column({ type: 'varchar', length: 255, nullable: true })
  email: string | null;

  @Column({ name: 'phone_number', type: 'varchar', length: 30, nullable: true })
  phoneNumber: string | null;

  @Column({ type: 'varchar', length: 10 })
  platform: string; // IOS, ANDROID

  @Column({ name: 'app_version', type: 'varchar', length: 20, nullable: true })
  appVersion: string | null;

  @Column({ type: 'double precision', nullable: true })
  latitude: number | null;

  @Column({ type: 'double precision', nullable: true })
  longitude: number | null;

  @Column({ name: 'ip_address', type: 'varchar', length: 64, nullable: true })
  ipAddress: string | null;

  @Column({ name: 'ip_location', type: 'text', nullable: true })
  ipLocation: string | null;

  @Column({ name: 'user_agent', type: 'text', nullable: true })
  userAgent: string | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
