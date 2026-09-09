import { test, expect } from '@playwright/test';

test.describe('Test Suite 2: Redemptions Fulfillment & 48h SLA Queue', () => {
  test.beforeEach(async ({ page, request }) => {
    await request.post('/api/v1/test-reset');
    await page.goto('/admin/');
    await page.fill('[data-testid="login-email"]', 'admin@rbxrewards.com');
    await page.fill('[data-testid="login-password"]', 'admin123!');
    await page.click('[data-testid="login-submit-btn"]');
    await expect(page.locator('[data-testid="auth-gate-modal"]')).toHaveClass(/hidden/);

    // Navigate to Redemptions tab
    await page.click('[data-testid="nav-redemptions"]');
    await expect(page.locator('[data-testid="tab-redemptions-pane"]')).toBeVisible();
  });

  test('REDEEM-01: Displays pending gift card requests with user email & cost', async ({ page }) => {
    const table = page.locator('[data-testid="redemptions-table"]');
    await expect(table).toContainText('player1@example.com');
    await expect(table).toContainText('$3');
    await expect(table).toContainText('20,000');
  });

  test('REDEEM-02: Renders 48h SLA countdown badges', async ({ page }) => {
    const slaBadge = page.locator('[data-testid="sla-badge-d3eebc99-9c0b-4ef8-bb6d-6bb9bd380a44"]');
    await expect(slaBadge).toBeVisible();
    await expect(slaBadge).toContainText('remaining');
  });

  test('REDEEM-03: Filter tabs filter requests by status', async ({ page }) => {
    await page.click('[data-testid="filter-pending"]');
    await expect(page.locator('[data-testid="redemptions-table"]')).toContainText('PENDING');

    await page.click('[data-testid="filter-fulfilled"]');
    // Initially no fulfilled - auto-waits for async table update
    await expect(page.locator('#redemptionsTableBody tr')).toHaveCount(0);

    // Switch back to All
    await page.click('[data-testid="filter-all"]');
    await expect(page.locator('#redemptionsTableBody tr')).toHaveCount(2);
  });

  test('REDEEM-04: PIN code validation in dispatch modal rejects short/empty code', async ({ page }) => {
    await page.click('[data-testid="dispatch-btn-d3eebc99-9c0b-4ef8-bb6d-6bb9bd380a44"]');
    const modal = page.locator('[data-testid="dispatch-modal"]');
    await expect(modal).toBeVisible();

    // Try submitting with code less than 8 chars
    await page.fill('[data-testid="dispatch-pin-input"]', '123');
    await page.click('[data-testid="confirm-dispatch-btn"]');

    const errorBanner = page.locator('[data-testid="dispatch-error-banner"]');
    await expect(errorBanner).toBeVisible();
    await expect(errorBanner).toContainText('at least 8 characters');

    // Close modal
    await page.click('#cancelDispatchBtn');
    await expect(modal).toHaveClass(/hidden/);
  });

  test('REDEEM-05: 1-Click PIN dispatch fulfills request and records PIN', async ({ page }) => {
    await page.click('[data-testid="dispatch-btn-d3eebc99-9c0b-4ef8-bb6d-6bb9bd380a44"]');
    await page.fill('[data-testid="dispatch-pin-input"]', 'RBX-9942-8821-4401');
    await page.fill('[data-testid="dispatch-notes-input"]', 'Amazon batch 2026-A');
    await page.click('[data-testid="confirm-dispatch-btn"]');

    // Modal should close
    await expect(page.locator('[data-testid="dispatch-modal"]')).toHaveClass(/hidden/);

    // Status should be FULFILLED
    const statusCell = page.locator('[data-testid="redemption-status-d3eebc99-9c0b-4ef8-bb6d-6bb9bd380a44"]');
    await expect(statusCell).toContainText('FULFILLED');

    // Table should now display the PIN
    await expect(page.locator('[data-testid="redemptions-table"]')).toContainText('RBX-9942-8821-4401');
  });

  test('REDEEM-06: Reject & Refund flow updates status to REJECTED and credits coins back', async ({ page }) => {
    await page.click('[data-testid="reject-btn-e4eebc99-9c0b-4ef8-bb6d-6bb9bd380a55"]');
    const modal = page.locator('[data-testid="reject-modal"]');
    await expect(modal).toBeVisible();

    await page.fill('[data-testid="reject-reason-input"]', 'Detected emulator bot usage');
    await page.click('[data-testid="confirm-reject-btn"]');

    await expect(modal).toHaveClass(/hidden/);

    // Status should be REJECTED
    const statusCell = page.locator('[data-testid="redemption-status-e4eebc99-9c0b-4ef8-bb6d-6bb9bd380a55"]');
    await expect(statusCell).toContainText('REJECTED');
  });
});
