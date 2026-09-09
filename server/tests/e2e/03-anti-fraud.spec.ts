import { test, expect } from '@playwright/test';

test.describe('Test Suite 3: Anti-Fraud, Bot Defense & Account Freezing', () => {
  test.beforeEach(async ({ page, request }) => {
    await request.post('/api/v1/test-reset');
    await page.goto('/admin/');
    await page.fill('[data-testid="login-email"]', 'admin@rbxrewards.com');
    await page.fill('[data-testid="login-password"]', 'admin123!');
    await page.click('[data-testid="login-submit-btn"]');
    await expect(page.locator('[data-testid="auth-gate-modal"]')).toHaveClass(/hidden/);

    // Go to Anti-Fraud tab
    await page.click('[data-testid="nav-anti-fraud"]');
    await expect(page.locator('[data-testid="tab-anti-fraud-pane"]')).toBeVisible();
  });

  test('FRAUD-01: Flagged table displays emulator signature badge', async ({ page }) => {
    const table = page.locator('[data-testid="flagged-users-table"]');
    await expect(table).toContainText('SpeedFarmerX');
    await expect(table).toContainText('vbox86p_bluestacks_device');
    await expect(table).toContainText('Emulator');
  });

  test('FRAUD-02: 1-Click Ban freezes user account and updates UI', async ({ page }) => {
    const targetUserId = 'b1eebc99-9c0b-4ef8-bb6d-6bb9bd380a22';
    await page.click(`[data-testid="ban-btn-${targetUserId}"]`);

    const modal = page.locator('[data-testid="ban-modal"]');
    await expect(modal).toBeVisible();

    await page.fill('[data-testid="ban-reason-input"]', 'BlueStacks 5 botting and memory modification');
    await page.click('[data-testid="confirm-ban-btn"]');

    await expect(modal).toHaveClass(/hidden/);

    // Status cell should now say Banned
    const statusCell = page.locator(`[data-testid="user-status-${targetUserId}"]`);
    await expect(statusCell).toContainText('Banned');

    // Button should now toggle to Unban
    await expect(page.locator(`[data-testid="unban-btn-${targetUserId}"]`)).toBeVisible();
  });

  test('FRAUD-03: 1-Click Unban restores account access', async ({ page }) => {
    const targetUserId = 'b1eebc99-9c0b-4ef8-bb6d-6bb9bd380a22';

    // First ban user to produce the unban button
    await page.click(`[data-testid="ban-btn-${targetUserId}"]`);
    await page.fill('[data-testid="ban-reason-input"]', 'Ban for unban verification');
    await page.click('[data-testid="confirm-ban-btn"]');
    await expect(page.locator(`[data-testid="unban-btn-${targetUserId}"]`)).toBeVisible();

    // Now click Unban
    await page.click(`[data-testid="unban-btn-${targetUserId}"]`);

    // Status cell should now say Flagged Active
    const statusCell = page.locator(`[data-testid="user-status-${targetUserId}"]`);
    await expect(statusCell).toContainText('Flagged Active');

    // Freeze / Ban button should be back
    await expect(page.locator(`[data-testid="ban-btn-${targetUserId}"]`)).toBeVisible();
  });

  test('FRAUD-04: Multi-Account farm clusters render grouped hardware identifiers', async ({ page }) => {
    const clusters = page.locator('#clustersContainer');
    await expect(clusters).toContainText('Farm Cluster');
    await expect(clusters).toContainText('Accounts Connected');
  });
});
