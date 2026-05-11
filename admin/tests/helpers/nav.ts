import type { Page } from '@playwright/test';

/**
 * Antd Sider Menu 에서 항목을 클릭한다.
 * Layout.tsx 의 menuItems 가 `key: '/users'` 같은 path 기반이라
 * 라벨 텍스트로 매칭한 뒤 URL 변경 대기.
 */
export async function clickMenu(
  page: Page,
  label: string,
  expectedUrl: RegExp,
): Promise<void> {
  const sider = page.locator('.ant-layout-sider');
  const item = sider
    .locator('.ant-menu-item')
    .filter({ hasText: new RegExp(`^\\s*${label}\\s*$`) })
    .first();
  await item.click();
  await page.waitForURL(expectedUrl, { timeout: 15_000 });
}
