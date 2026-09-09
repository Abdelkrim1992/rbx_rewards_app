import { test, expect } from '@playwright/test';

test.describe('Test Suite 4: Dynamic Economy & Daily Cap Controls', () => {
  test.beforeEach(async ({ page, request }) => {
    await request.post('/api/v1/test-reset');
    await page.goto('/admin/');
    await page.fill('[data-testid="login-email"]', 'admin@rbxrewards.com');
    await page.fill('[data-testid="login-password"]', 'admin123!');
    await page.click('[data-testid="login-submit-btn"]');
    await expect(page.locator('[data-testid="auth-gate-modal"]')).toHaveClass(/hidden/);

    // Navigate to Economy tab
    await page.click('[data-testid="nav-economy"]');
    await expect(page.locator('[data-testid="tab-economy-pane"]')).toBeVisible();
  });

  test('ECON-01: Mini-game daily caps form loads configured values', async ({ page }) => {
    await expect(page.locator('[data-testid="cap-tap-tap"]')).toHaveValue('150');
    await expect(page.locator('[data-testid="cap-math-quiz"]')).toHaveValue('120');
    await expect(page.locator('[data-testid="cap-flappy-jump"]')).toHaveValue('150');
    await expect(page.locator('[data-testid="cap-flip-cards"]')).toHaveValue('60');
    await expect(page.locator('[data-testid="cap-scratch-card"]')).toHaveValue('100');
  });

  test('ECON-02: Modifying mini-game caps persists new limits', async ({ page }) => {
    // Increase Tap Tap cap to 200
    await page.fill('[data-testid="cap-tap-tap"]', '200');
    await page.click('[data-testid="save-caps-btn"]');

    // Toast notification should confirm save
    await expect(page.locator('#toastContainer')).toContainText('Daily mini-game caps saved');

    // Reload and check persistence
    await page.reload();
    await page.click('[data-testid="nav-economy"]');
    await expect(page.locator('[data-testid="cap-tap-tap"]')).toHaveValue('200');
  });

  test('ECON-03: Toggling reward card stock updates between In Stock and Sold Out', async ({ page }) => {
    const cardToggle = page.locator('[data-testid="toggle-stock-card_3"]');
    await expect(cardToggle).toContainText('In Stock');

    // Click to toggle sold out
    await cardToggle.click();
    await expect(cardToggle).toContainText('Sold Out');

    // Click again to toggle back to in stock
    await cardToggle.click();
    await expect(cardToggle).toContainText('In Stock');
  });

  test('ECON-04: Card inventory displays configured coin thresholds', async ({ page }) => {
    const list = page.locator('[data-testid="reward-cards-list"]');
    await expect(list).toContainText('20,000 Coins Required');
    await expect(list).toContainText('40,000 Coins Required');
    await expect(list).toContainText('70,000 Coins Required');
  });
});
