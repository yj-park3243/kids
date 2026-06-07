import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  Index,
} from 'typeorm';

/**
 * FCM 푸시 전송 시도/결과 로그 — 운영 디버깅용.
 * 한 push 시도(한 유저에게 보낸 multicast)마다 한 행이 남는다.
 * 7일이 지나면 PushLogCleanupScheduler 가 일괄 삭제.
 */
@Entity('push_log')
@Index(['createdAt'])
@Index(['userId', 'createdAt'])
export class PushLog {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id', type: 'uuid' })
  userId: string;

  @Column({ type: 'varchar', length: 30 })
  type: string;

  @Column({ type: 'varchar', length: 200 })
  title: string;

  @Column({ type: 'varchar', length: 500 })
  body: string;

  // 발송 대상 토큰 수 — 0이면 토큰 없음 / skipReason 같이 채워짐.
  @Column({ name: 'token_count', type: 'int', default: 0 })
  tokenCount: number;

  @Column({ name: 'success_count', type: 'int', default: 0 })
  successCount: number;

  @Column({ name: 'failure_count', type: 'int', default: 0 })
  failureCount: number;

  // FCM 응답을 아예 못 받은 경우(messaging null / 토큰 0 / 예외)의 사유.
  @Column({
    name: 'skip_reason',
    type: 'varchar',
    length: 100,
    nullable: true,
  })
  skipReason: string | null;

  // 송신 자체 실패 — 예외 메시지(앞 500자).
  @Column({
    name: 'error_message',
    type: 'varchar',
    length: 500,
    nullable: true,
  })
  errorMessage: string | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
