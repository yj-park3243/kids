import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
} from 'typeorm';

@Entity('app_version')
export class AppVersion {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'varchar', length: 10 })
  platform: string; // IOS, ANDROID

  @Column({ name: 'min_version', type: 'varchar', length: 20 })
  minVersion: string; // 최소 필수 버전 (예: 1.0.0)

  @Column({ name: 'latest_version', type: 'varchar', length: 20 })
  latestVersion: string;

  @Column({ name: 'latest_build', type: 'int', default: 1 })
  latestBuild: number;

  @Column({ name: 'force_update', type: 'boolean', default: false })
  forceUpdate: boolean;

  @Column({ name: 'update_message', type: 'text', nullable: true })
  updateMessage: string | null;

  @Column({ name: 'store_url', type: 'text', nullable: true })
  storeUrl: string | null;

  // 앱 심사 모드: true 이면 신규 가입 시 KCP 본인인증을 우회하고 더미 데이터로 자동 채움.
  @Column({
    name: 'bypass_phone_verification',
    type: 'boolean',
    default: false,
  })
  bypassPhoneVerification: boolean;

  // 광고 노출 토글. 기존 동작(항상 노출) 유지를 위해 default true — 운영자가 어드민에서 끌 수 있다.
  @Column({ name: 'show_ad', type: 'boolean', default: true })
  showAd: boolean;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;
}
