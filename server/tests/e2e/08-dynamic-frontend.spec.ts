import { test, expect } from '@playwright/test';

test.describe('Test Suite 8: Dynamic Frontend Data & Light Mode Theme', () => {
  test.beforeEach(async ({ request }) => {
    // Reset database to deterministic fixtures
    const res = await request.post('/api/v1/test-reset');
    expect(res.status()).toBe(200);
  });

  test('DYN-01: Public API /api/v1/public/app-config returns live economy & stats unauthenticated', async ({
    request,
  }) => {
    const res = await request.get('/api/v1/public/app-config');
    expect(res.status()).toBe(200);
    const body = await res.json();
    expect(body.success).toBe(true);
    expect(body.data.appName).toBe('RBX Rewards');
    expect(body.data.rewards.length).toBe(3);
    expect(body.data.rewards[0].coinPrice).toBe(20000);
    expect(body.data.dailyCaps.tapTap).toBe(150);
    expect(body.data.stats.totalCoinsAwarded).toBeGreaterThan(1000000);
  });

  test('DYN-02: Public portal loads in Light Mode and renders live dynamic stats ticker', async ({
    page,
  }) => {
    await page.goto('/');

    // Verify Light mode is default
    const theme = await page.getAttribute('html', 'data-theme');
    expect(theme).toBe('light');

    // Verify live platform stats counters are rendered and populated
    const coinsEl = page.locator('#statTotalCoins');
    await expect(coinsEl).toBeVisible();
    await expect(coinsEl).toContainText('M+');

    const redemptionsEl = page.locator('#statTotalRedemptions');
    await expect(redemptionsEl).toBeVisible();
    await expect(redemptionsEl).toContainText('+');

    const slaEl = page.locator('#statSlaDelivery');
    await expect(slaEl).toBeVisible();
    await expect(slaEl).toContainText('h');
  });

  test('DYN-03: Rewards policy page dynamically renders live reward cards & stock badges', async ({
    page,
  }) => {
    await page.goto('/rewards-policy.html');

    // Verify dynamic catalog container renders the 3 Roblox cards
    const catalog = page.locator('#dynamicRewardsCatalog');
    await expect(catalog).toBeVisible();

    const cards = page.locator('#dynamicRewardsCatalog .reward-catalog-card');
    await expect(cards).toHaveCount(3);

    // Verify $3, $5, $10 prices rendered with live coin thresholds
    await expect(cards.nth(0)).toContainText('$3 Roblox Gift Card');
    await expect(cards.nth(0)).toContainText('20,000 RBX Coins');
    await expect(cards.nth(0)).toContainText('In Stock');

    await expect(cards.nth(1)).toContainText('$5 Roblox Gift Card');
    await expect(cards.nth(1)).toContainText('40,000 RBX Coins');

    await expect(cards.nth(2)).toContainText('$10 Roblox Gift Card');
    await expect(cards.nth(2)).toContainText('70,000 RBX Coins');

    // Verify dynamic mini-game daily caps table
    const tapCap = page.locator('[data-cap="tapTap"]');
    await expect(tapCap).toContainText('150 RBX');
  });

  test('DYN-04: Dynamic Contact form submits real support ticket and displays confirmation ID', async ({
    page,
  }) => {
    await page.goto('/contact.html');

    await page.fill('#ticketName', 'Alex Tester');
    await page.fill('#ticketEmail', 'alex.tester@example.com');
    await page.selectOption('#ticketTopic', 'Reward Redemption Status');
    await page.fill(
      '#ticketMessage',
      'I have a question about my $5 Roblox card redemption status and delivery SLA.'
    );

    await page.click('button[type="submit"]');

    // Success callout should appear dynamically
    const successBox = page.locator('#contactSuccessBox');
    await expect(successBox).toBeVisible({ timeout: 5000 });
    await expect(successBox).toContainText('Support Ticket Registered');
  });

  test('DYN-05: Dynamic Data Deletion form schedules 7-day store compliance purge', async ({
    page,
  }) => {
    await page.goto('/data-deletion.html');

    await page.fill('#deleteUserEmail', 'purge_candidate@example.com');
    await page.fill('#deleteUserId', 'user_playwright_test_001');
    await page.selectOption('#deleteReason', 'Privacy preferences');
    await page.check('#deleteConfirmCheck');

    await page.click('button[type="submit"]');

    // Success box should appear with confirmation
    const successBox = page.locator('#deletionSuccessBox');
    await expect(successBox).toBeVisible({ timeout: 5000 });
    await expect(successBox).toContainText('Deletion Request Scheduled');
    await expect(successBox).toContainText('7-Day Store Grace Period');
  });

  test('DYN-06: Admin Dashboard loads in Light Mode and supports theme toggle', async ({ page }) => {
    await page.goto('/admin/');

    // Admin HTML has data-theme="light"
    const theme = await page.getAttribute('html', 'data-theme');
    expect(theme).toBe('light');

    // Sign in to access header controls
    await page.fill('#loginEmail', 'admin@rbxrewards.com');
    await page.fill('#loginPassword', 'admin123!');
    await page.click('[data-testid="login-submit-btn"]');
    await expect(page.locator('#authGateModal')).toHaveClass(/hidden/);

    // Toggle to dark mode
    const toggleBtn = page.locator('[data-testid="admin-theme-toggle"]');
    await expect(toggleBtn).toBeVisible();
    await toggleBtn.click();

    const darkTheme = await page.getAttribute('html', 'data-theme');
    expect(darkTheme).toBe('dark');

    // Toggle back to light mode
    await toggleBtn.click();
    const lightThemeAgain = await page.getAttribute('html', 'data-theme');
    expect(lightThemeAgain).toBe('light');
  });
});
