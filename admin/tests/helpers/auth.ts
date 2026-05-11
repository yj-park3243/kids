import type { Page } from '@playwright/test';

const ADMIN_USERNAME = process.env.ADMIN_USERNAME ?? 'dydwn3243@gmail.com';
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD ?? '';

/**
 * Kids admin 로그인. LoginPage 의 placeholder("아이디", "비밀번호") 와
 * 로그인 버튼을 사용. 성공 시 /dashboard 로 이동할 때까지 대기.
 */
export async function loginAsAdmin(page: Page): Promise<void> {
  if (!ADMIN_PASSWORD) {
    throw new Error(
      'ADMIN_PASSWORD 환경변수가 비어 있다. 예) ADMIN_PASSWORD=xxx npx playwright test',
    );
  }

  await page.goto('/login');
  await page.waitForLoadState('networkidle');

  const idInput = page.locator('input[placeholder*="아이디"]').first();
  const pwInput = page.locator('input[type="password"]').first();
  await idInput.fill(ADMIN_USERNAME);
  await pwInput.fill(ADMIN_PASSWORD);

  await page.getByRole('button', { name: /로그인/ }).first().click();
  await page.waitForURL(/\/dashboard/, { timeout: 20_000 });
}
