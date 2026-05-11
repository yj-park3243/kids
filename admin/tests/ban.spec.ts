import { test, expect } from '@playwright/test';
import { loginAsAdmin } from './helpers/auth';
import { psql, psqlScalar } from './helpers/db';

/**
 * 회원 차단 e2e.
 *   1) DB 에 시드 유저(status=ACTIVE) 1명 INSERT
 *   2) admin /users/:id 로 이동 → "정지" 버튼 클릭 → Popconfirm "확인"
 *   3) DB 에서 status='BANNED' 로 바뀐 것을 검증
 *   4) 끝나면 시드 유저 DELETE
 */
test.describe.configure({ mode: 'serial' });

const MARKER = `e2e_ban_${Date.now()}`;
let userId = '';

test.beforeAll(() => {
  const email = `${MARKER}@e2e.local`;
  userId = psqlScalar(`
    INSERT INTO "user" (email, auth_provider, nickname, is_phone_verified, status)
    VALUES ('${email}', 'EMAIL', '${MARKER}', true, 'ACTIVE')
    RETURNING id;
  `);
  expect(userId).toMatch(/^[0-9a-f-]{36}$/);
});

test.afterAll(() => {
  if (userId) psql(`DELETE FROM "user" WHERE id = '${userId}';`);
});

test('UserDetailPage 에서 정지 버튼을 누르면 DB 의 status 가 BANNED 로 변경된다', async ({ page }) => {
  await loginAsAdmin(page);
  await page.goto(`/users/${userId}`);
  await page.waitForURL(new RegExp(`/users/${userId}`));

  // 페이지 로드 대기 — 닉네임이 보여야 데이터 fetch 완료
  await expect(page.getByText(MARKER).first()).toBeVisible({ timeout: 10_000 });

  // "정지" 버튼 클릭 → Popconfirm 의 "확인" 클릭
  await page.getByRole('button', { name: /^정지$/ }).click();
  await page.getByRole('button', { name: /^확인$/ }).click();

  // 성공 메시지 (antd message) — DOM 에 잠시 떴다가 사라짐
  await expect(page.getByText('유저가 정지되었습니다.')).toBeVisible({ timeout: 10_000 });

  // DB 검증
  const status = psqlScalar(`SELECT status FROM "user" WHERE id = '${userId}';`);
  expect(status).toBe('BANNED');
});
