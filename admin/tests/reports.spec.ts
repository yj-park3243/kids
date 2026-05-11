import { test, expect } from '@playwright/test';
import { loginAsAdmin } from './helpers/auth';
import { clickMenu } from './helpers/nav';
import { psql, psqlScalar } from './helpers/db';

/**
 * 신고 페이지 e2e.
 *   1) DB 에 시드 유저(reporter, target) 와 user_report 1건 직접 INSERT
 *   2) admin /reports 페이지에서 marker 가 보이는지 확인
 *   3) 끝나면 정리
 *
 * 회원가입 API 를 호출하면 bcrypt 가 필요 없는데, e2e 의 단순함을 위해 SQL 로
 * password_hash 없이 직접 INSERT (UNIQUE 제약 회피용 unique email).
 */
test.describe.configure({ mode: 'serial' });

const MARKER = `e2e_report_${Date.now()}`;

let reporterId = '';
let targetId = '';
let reportId = '';

test.beforeAll(() => {
  // 두 유저 시드 (email 만 unique, password_hash 는 비워둠 — 로그인은 안 함)
  const emailA = `${MARKER}_a@e2e.local`;
  const emailB = `${MARKER}_b@e2e.local`;

  reporterId = psqlScalar(`
    INSERT INTO "user" (email, auth_provider, nickname, is_phone_verified, status)
    VALUES ('${emailA}', 'EMAIL', '${MARKER}_a', true, 'ACTIVE')
    RETURNING id;
  `);
  targetId = psqlScalar(`
    INSERT INTO "user" (email, auth_provider, nickname, is_phone_verified, status)
    VALUES ('${emailB}', 'EMAIL', '${MARKER}_b', true, 'ACTIVE')
    RETURNING id;
  `);
  expect(reporterId).toMatch(/^[0-9a-f-]{36}$/);
  expect(targetId).toMatch(/^[0-9a-f-]{36}$/);

  reportId = psqlScalar(`
    INSERT INTO user_report (reporter_id, target_user_id, reason, detail, status)
    VALUES ('${reporterId}', '${targetId}', 'ABUSE', '${MARKER}', 'OPEN')
    RETURNING id;
  `);
  expect(reportId).toMatch(/^[0-9a-f-]{36}$/);
});

test.afterAll(() => {
  if (reportId) psql(`DELETE FROM user_report WHERE id = '${reportId}';`);
  if (reporterId) psql(`DELETE FROM "user" WHERE id = '${reporterId}';`);
  if (targetId) psql(`DELETE FROM "user" WHERE id = '${targetId}';`);
});

test('admin /reports 페이지에서 신고 row 가 노출된다', async ({ page }) => {
  await loginAsAdmin(page);
  await clickMenu(page, '신고 관리', /\/reports/);

  // 시드 row 의 marker 가 detail 컬럼에 그대로 표시되어야 함 (40자 미만)
  const row = page.locator('tr', { hasText: MARKER });
  await expect(row).toBeVisible({ timeout: 10_000 });

  // 사유 라벨/상태 태그도 확인
  await expect(row.getByText('욕설/괴롭힘')).toBeVisible();
  await expect(row.getByText('접수')).toBeVisible();
});
