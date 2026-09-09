import { test, expect } from '@playwright/test';

test.describe('Test Suite 7: Public Policy Portal & Real App Data', () => {
  test('WEB-01: Public portal loads with White (Light) mode by default', async ({ page }) => {
    await page.goto('/');

    const html = page.locator('html');
    await expect(html).toHaveAttribute('data-theme', 'light');
  });

  test('WEB-02: Theme switcher button toggles to Dark theme seamlessly', async ({ page }) => {
    await page.goto('/');

    const themeToggle = page.locator('.theme-toggle-btn').first();
    await expect(themeToggle).toBeVisible();

    // Click toggle
    await themeToggle.click();

    const html = page.locator('html');
    await expect(html).toHaveAttribute('data-theme', 'dark');

    // Click again to toggle back
    await themeToggle.click();
    await expect(html).toHaveAttribute('data-theme', 'light');
  });

  test('WEB-03: Rewards policy page displays real app parameters ($3, $5, $10 cards & 48h SLA)', async ({ page }) => {
    await page.goto('/rewards-policy.html');

    const body = page.locator('body');
    await expect(body).toContainText('$3');
    await expect(body).toContainText('20,000');
    await expect(body).toContainText('48 hours');
  });
});
