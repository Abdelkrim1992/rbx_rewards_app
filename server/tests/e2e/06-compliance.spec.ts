import { test, expect } from '@playwright/test';

test.describe('Test Suite 6: Compliance, Support & Audit Trail', () => {
  test.beforeEach(async ({ page, request }) => {
    await request.post('/api/v1/test-reset');
    await page.goto('/admin/');
    await page.fill('[data-testid="login-email"]', 'admin@rbxrewards.com');
    await page.fill('[data-testid="login-password"]', 'admin123!');
    await page.click('[data-testid="login-submit-btn"]');
    await expect(page.locator('[data-testid="auth-gate-modal"]')).toHaveClass(/hidden/);
  });

  test('COMP-01: 7-Day Google Play deletion queue displays countdown badge', async ({ page }) => {
    await page.click('[data-testid="nav-compliance"]');
    await expect(page.locator('[data-testid="tab-compliance-pane"]')).toBeVisible();

    const table = page.locator('[data-testid="deletion-queue-table"]');
    await expect(table).toContainText('delete_me@example.com');
    await expect(table).toContainText('days left');
  });

  test('COMP-02: Executing "Purge Now" completes erasure per store SLA', async ({ page }) => {
    await page.click('[data-testid="nav-compliance"]');
    const reqId = '01eebc99-9c0b-4ef8-bb6d-6bb9bd380a88';

    await page.click(`[data-testid="purge-btn-${reqId}"]`);

    const statusCell = page.locator(`[data-testid="deletion-status-${reqId}"]`);
    await expect(statusCell).toContainText('COMPLETED');
    await expect(page.locator('#toastContainer')).toContainText('irrevocably purged');
  });

  test('COMP-03: Support tickets list allows 1-click status resolution', async ({ page }) => {
    await page.click('[data-testid="nav-compliance"]');
    const ticketId = '12eebc99-9c0b-4ef8-bb6d-6bb9bd380a00';

    await expect(page.locator('[data-testid="support-tickets-table"]')).toContainText('48 hour SLA');

    // Click Mark Resolved
    await page.click(`[data-testid="resolve-ticket-${ticketId}"]`);

    const statusCell = page.locator(`[data-testid="ticket-status-${ticketId}"]`);
    await expect(statusCell).toContainText('RESOLVED');
  });

  test('COMP-04: Immutable Audit Trail records admin events', async ({ page }) => {
    await page.click('[data-testid="nav-audit"]');
    await expect(page.locator('[data-testid="tab-audit-pane"]')).toBeVisible();

    const auditTable = page.locator('[data-testid="audit-table"]');
    await expect(auditTable).toBeVisible();
    await expect(auditTable).toContainText('admin@rbxrewards.com');
  });
});
