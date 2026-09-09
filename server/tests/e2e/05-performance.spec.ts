import { test, expect } from '@playwright/test';

test.describe('Test Suite 5: Performance & Redis Edge Caching', () => {
  test.beforeEach(async ({ page, request }) => {
    await request.post('/api/v1/test-reset');
    await page.goto('/admin/');
    await page.fill('[data-testid="login-email"]', 'admin@rbxrewards.com');
    await page.fill('[data-testid="login-password"]', 'admin123!');
    await page.click('[data-testid="login-submit-btn"]');
    await expect(page.locator('[data-testid="auth-gate-modal"]')).toHaveClass(/hidden/);

    // Navigate to Performance tab
    await page.click('[data-testid="nav-performance"]');
    await expect(page.locator('[data-testid="tab-performance-pane"]')).toBeVisible();
  });

  test('PERF-01: Purge Leaderboard Cache issues key invalidation and shows notice', async ({ page }) => {
    await page.click('[data-testid="purge-leaderboard-btn"]');

    const notice = page.locator('[data-testid="purge-result-notice"]');
    await expect(notice).toBeVisible();
    await expect(notice).toContainText('leaderboard');
    await expect(page.locator('#toastContainer')).toContainText('Cache purged');
  });

  test('PERF-02: Purge Economy Cache issues key invalidation', async ({ page }) => {
    await page.click('[data-testid="purge-economy-btn"]');

    const notice = page.locator('[data-testid="purge-result-notice"]');
    await expect(notice).toBeVisible();
    await expect(notice).toContainText('economy');
  });

  test('PERF-03: Leaderboard TTL slider updates and saves duration', async ({ page }) => {
    const slider = page.locator('[data-testid="leaderboard-ttl-slider"]');
    await slider.fill('120');

    await expect(page.locator('[data-testid="ttl-display"]')).toHaveText('120');
    await page.click('[data-testid="save-ttl-btn"]');

    await expect(page.locator('#toastContainer')).toContainText('Cache TTL settings saved');
  });

  test('PERF-04: Telemetry renders healthy edge server status and ping', async ({ page }) => {
    const status = page.locator('[data-testid="telemetry-status"]');
    await expect(status).toHaveText('HEALTHY');

    const ping = page.locator('[data-testid="telemetry-ping"]');
    await expect(ping).toContainText('ms');
  });
});
