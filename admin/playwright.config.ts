import { defineConfig, devices } from '@playwright/test';

const ADMIN_BASE_URL = process.env.ADMIN_BASE_URL ?? 'http://localhost:5174';
const isLocal = /^https?:\/\/(localhost|127\.0\.0\.1)/.test(ADMIN_BASE_URL);

export default defineConfig({
  testDir: './tests',
  fullyParallel: false,
  forbidOnly: !!process.env.CI,
  retries: 0,
  workers: 1,
  timeout: 180_000,
  expect: { timeout: 10_000 },
  reporter: [['list'], ['html', { open: 'never' }]],
  use: {
    baseURL: ADMIN_BASE_URL,
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    locale: 'ko-KR',
    timezoneId: 'Asia/Seoul',
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
  // baseURL 이 로컬일 때만 dev 서버를 자동 부팅. 운영 admin 으로 돌릴 때는 생략.
  ...(isLocal
    ? {
        webServer: {
          command: 'npm run dev',
          url: ADMIN_BASE_URL,
          reuseExistingServer: !process.env.CI,
          timeout: 60_000,
        },
      }
    : {}),
});
