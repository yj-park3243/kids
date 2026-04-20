import { test, expect, type Page } from '@playwright/test';

const mockLoginSuccess = async (page: Page) => {
  await page.route('**/v1/admin/login', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        success: true,
        data: {
          accessToken: 'test-token-abc',
          user: {
            id: 'admin-1',
            email: 'admin@test.com',
            nickname: '관리자',
            isAdmin: true,
          },
        },
      }),
    });
  });
};

const mockDashboard = async (page: Page) => {
  await page.route('**/v1/admin/dashboard', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        success: true,
        data: {
          totalUsers: 0,
          totalRooms: 0,
          activeRooms: 0,
          newUsersToday: 0,
          usersByDay: [],
          roomsByStatus: [],
        },
      }),
    });
  });
};

test.describe('Admin smoke', () => {
  test.beforeEach(async ({ page }) => {
    await page.context().clearCookies();
    await page.addInitScript(() => window.localStorage.clear());
  });

  test('로그인 페이지가 렌더링된다', async ({ page }) => {
    await page.goto('/login');
    await expect(page.getByRole('heading', { name: '같이크자' })).toBeVisible();
    await expect(page.getByText('관리자 대시보드')).toBeVisible();
    await expect(page.getByPlaceholder('아이디')).toBeVisible();
    await expect(page.getByPlaceholder('비밀번호')).toBeVisible();
    await expect(page.getByRole('button', { name: '로그인' })).toBeVisible();
  });

  test('빈 폼 제출 시 유효성 에러가 표시된다', async ({ page }) => {
    await page.goto('/login');
    await page.getByRole('button', { name: '로그인' }).click();
    await expect(page.getByText('아이디를 입력해주세요')).toBeVisible();
    await expect(page.getByText('비밀번호를 입력해주세요')).toBeVisible();
  });

  test('보호된 경로 접근 시 /login 으로 리다이렉트된다', async ({ page }) => {
    await page.goto('/dashboard');
    await expect(page).toHaveURL(/\/login$/);
  });

  test('알 수 없는 경로는 /dashboard 로 리다이렉트 → 미로그인이면 /login', async ({ page }) => {
    await page.goto('/no-such-path');
    await expect(page).toHaveURL(/\/login$/);
  });

  test('로그인 성공 시 /dashboard 로 이동한다', async ({ page }) => {
    await mockLoginSuccess(page);
    await mockDashboard(page);

    await page.goto('/login');
    await page.getByPlaceholder('아이디').fill('admin@test.com');
    await page.getByPlaceholder('비밀번호').fill('password123');
    await page.getByRole('button', { name: '로그인' }).click();

    await expect(page).toHaveURL(/\/dashboard$/);

    const token = await page.evaluate(() => localStorage.getItem('admin_token'));
    expect(token).toBe('test-token-abc');
  });

  test('로그인 실패 시 /login 에 머문다', async ({ page }) => {
    await page.route('**/v1/admin/login', async (route) => {
      await route.fulfill({
        status: 401,
        contentType: 'application/json',
        body: JSON.stringify({
          success: false,
          error: { code: 'INVALID_CREDENTIALS', message: '잘못된 자격 증명' },
        }),
      });
    });

    await page.goto('/login');
    await page.getByPlaceholder('아이디').fill('wrong@test.com');
    await page.getByPlaceholder('비밀번호').fill('wrong');
    await page.getByRole('button', { name: '로그인' }).click();

    await expect(page).toHaveURL(/\/login$/);
  });
});
