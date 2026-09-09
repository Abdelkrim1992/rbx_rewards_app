import { test, expect } from '@playwright/test';

test.describe('Test Suite 1: Authentication & Access Control', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/admin/');
  });

  test('AUTH-01: Unauthenticated request displays the Admin Login Gate', async ({ page }) => {
    await page.goto('/admin/');
    const authModal = page.locator('[data-testid="auth-gate-modal"]');
    await expect(authModal).toBeVisible();
    await expect(page.locator('[data-testid="login-email"]')).toBeVisible();
    await expect(page.locator('[data-testid="login-password"]')).toBeVisible();
  });

  test('AUTH-02: Invalid credentials show error alert and deny entry', async ({ page }) => {
    await page.goto('/admin/');
    await page.fill('[data-testid="login-email"]', 'wrong@admin.com');
    await page.fill('[data-testid="login-password"]', 'WrongPassword123!');
    await page.click('[data-testid="login-submit-btn"]');

    const errorBanner = page.locator('[data-testid="login-error-banner"]');
    await expect(errorBanner).toBeVisible();
    await expect(errorBanner).toContainText('Invalid email or password');

    // Modal should remain visible
    await expect(page.locator('[data-testid="auth-gate-modal"]')).toBeVisible();
  });

  test('AUTH-03: Empty inputs trigger HTML5 validation', async ({ page }) => {
    await page.goto('/admin/');
    await page.click('[data-testid="login-submit-btn"]');

    // Should remain on modal
    await expect(page.locator('[data-testid="auth-gate-modal"]')).toBeVisible();
  });

  test('AUTH-04: Valid Admin credentials authenticate and reveal Dashboard', async ({ page }) => {
    await page.goto('/admin/');
    await page.fill('[data-testid="login-email"]', 'admin@rbxrewards.com');
    await page.fill('[data-testid="login-password"]', 'admin123!');
    await page.click('[data-testid="login-submit-btn"]');

    // Login modal should disappear
    const authModal = page.locator('[data-testid="auth-gate-modal"]');
    await expect(authModal).toHaveClass(/hidden/);

    // Overview pane should be visible
    await expect(page.locator('[data-testid="tab-overview-pane"]')).toBeVisible();
    await expect(page.locator('#headerAdminEmail')).toContainText('admin@rbxrewards.com');
  });

  test('AUTH-05: Session persistence maintains state after page reload', async ({ page }) => {
    await page.goto('/admin/');
    await page.fill('[data-testid="login-email"]', 'admin@rbxrewards.com');
    await page.fill('[data-testid="login-password"]', 'admin123!');
    await page.click('[data-testid="login-submit-btn"]');

    await expect(page.locator('[data-testid="auth-gate-modal"]')).toHaveClass(/hidden/);

    // Reload page
    await page.reload();
    await expect(page.locator('[data-testid="auth-gate-modal"]')).toHaveClass(/hidden/);
    await expect(page.locator('[data-testid="tab-overview-pane"]')).toBeVisible();
  });

  test('AUTH-06: Sign Out button clears session and returns to login gate', async ({ page }) => {
    await page.goto('/admin/');
    await page.fill('[data-testid="login-email"]', 'admin@rbxrewards.com');
    await page.fill('[data-testid="login-password"]', 'admin123!');
    await page.click('[data-testid="login-submit-btn"]');
    await expect(page.locator('[data-testid="auth-gate-modal"]')).toHaveClass(/hidden/);

    // Click logout
    await page.click('[data-testid="logout-btn"]');

    // Auth gate should reappear
    await expect(page.locator('[data-testid="auth-gate-modal"]')).toBeVisible();
  });

  test('AUTH-07: Direct unauthenticated REST API call returns 401 Unauthorized', async ({ request }) => {
    const response = await request.get('/api/v1/redemptions');
    expect(response.status()).toBe(401);
    const body = await response.json();
    expect(body.success).toBe(false);
    expect(body.error.message).toContain('Authorization');
  });
});
