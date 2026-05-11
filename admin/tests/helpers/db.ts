import { execSync } from 'node:child_process';

/**
 * Kids EC2 에 SSH 로 접속해 psql 을 실행한다.
 *
 * 사용 환경변수:
 *   KIDS_SSH_KEY   기본 ~/WebProject2/kids/kids-key.pem
 *   KIDS_SSH_HOST  기본 ubuntu@43.201.221.240
 *
 * 서버 EC2 의 ~/kids-server/.env 에서 DB_HOST/USER/PASSWORD/NAME 을 source 해서
 * postgresql:// URL 로 psql 호출. ON_ERROR_STOP 으로 SQL 오류는 throw.
 */
const SSH_KEY =
  process.env.KIDS_SSH_KEY ??
  `${process.env.HOME}/WebProject2/kids/kids-key.pem`;
const SSH_HOST = process.env.KIDS_SSH_HOST ?? 'ubuntu@43.201.221.240';

function runSsh(cmd: string): string {
  const full = `ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=no ${SSH_HOST} ${JSON.stringify(cmd)}`;
  return execSync(full, { stdio: ['ignore', 'pipe', 'pipe'] }).toString();
}

/**
 * SQL 한 줄 실행. 결과는 tab 구분 한 줄(들) 문자열로 반환.
 * 비어 있으면 ''. 결과 1행만 필요할 때 가장 편함.
 */
export function psql(sql: string): string {
  const remote = [
    'cd ~/kids-server',
    'set -a && source .env && set +a',
    'DBURL="postgresql://$DB_USER:$DB_PASSWORD@$DB_HOST:${DB_PORT:-5432}/$DB_NAME"',
    `psql "$DBURL" -v ON_ERROR_STOP=1 -t -A -F $'\\t' <<'__E2E_SQL__'\n${sql}\n__E2E_SQL__`,
  ].join(' && ');
  return runSsh(remote).trim();
}

/** 단일 셀 결과 — '1' 또는 '' 같은 짧은 값 조회 시. */
export function psqlScalar(sql: string): string {
  return psql(sql).split('\n')[0]?.trim() ?? '';
}
