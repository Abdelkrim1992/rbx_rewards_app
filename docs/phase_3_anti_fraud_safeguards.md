# Phase 3: Anti-Fraud & Redemption Safeguards
## Implementation Specification & Task Breakdown

---

## 🎯 Phase Objective
Implement rigorous anti-fraud barriers to protect the business against auto-clickers, bot farms, multi-account starter reward farmers, and invalid traffic before any digital gift card or Robux code is purchased and delivered.

---

## 📐 Anti-Fraud Rules Specification

1. **Hardware Device Lock (Anti-Farming):**
   * The $0.50 Starter Reward (4,500 coins) can only be redeemed **ONCE per physical device ID**, regardless of how many new emails or accounts the user creates.
2. **Minimum Lifetime Ad Requirement (Proof of Engagement):**
   * Every redemption requires a minimum number of lifetime authenticated ads watched:
     * `$0.50 Starter Voucher:` $\ge 70$ lifetime ads.
     * `$3.00 Roblox Card:` $\ge 500$ lifetime ads.
     * `$5.00 Roblox Card:` $\ge 900$ lifetime ads.
     * `$10.00 Roblox Card:` $\ge 1,600$ lifetime ads.
3. **24–48 Hour Review Buffer:**
   * Redemptions are placed in `pending_review` status. 
   * Protects cashflow while Google AdMob reconciles invalid traffic deductions.
4. **Country-Tier Economy Multipliers:**
   * Users in Tier 3 low-eCPM regions require an economy multiplier (e.g. $3 card costs 45,000 coins instead of 24,000) or are gated out entirely.

---

## 📋 Actionable Tasks

### Task 3.1: Hardware Device Fingerprint Capture
* **Files:**
  * `lib/core/utils/device_fingerprint.dart`
  * `lib/presentation/screens/rewards_screen.dart`
* **Sub-tasks:**
  - [x] Use `device_info_plus` to generate a stable, hashed hardware device ID (`androidId` on Android, `identifierForVendor` on iOS).
  - [x] Pass `deviceId` along with the redemption payload in `_handleRedeem()`.

### Task 3.2: Update Supabase `spend-coins` Edge Function
* **File:** `supabase/functions/spend-coins/index.ts`
* **Sub-tasks:**
  - [x] Query `user_ad_stats` table for `lifetime_forced_ads + lifetime_optional_ads`.
  - [x] Verify `lifetime_ads >= min_required_ads` for the requested denomination:
    - Reject with: `"Please complete more game sessions before claiming this reward"`.
  - [x] Check if `denomId === 'starter_rbx_50c'` has already been redeemed by this `user_id` OR `device_id`.
  - [x] Record the `device_id` in the `claimed_rewards` / `transactions` table.
  - [x] Set redemption status to `pending_review` with an estimated delivery timestamp (24–48h).

### Task 3.3: Fix Client-Side Optimistic Credit on Game Screens
* **Files:**
  * `lib/presentation/screens/tap_tap_game_screen.dart`
  * `lib/presentation/screens/math_quiz_screen.dart`
  * `lib/presentation/screens/flip_card_game_screen.dart`
  * `lib/presentation/screens/flappy_jump_game_screen.dart`
* **Sub-tasks:**
  - [x] Locate `_submitAndRecordReward` and `_autoCreditCoinsOnPlayAgain`.
  - [x] Remove `ref.read(coinProvider.notifier).updateBalance(balance + earned)` when `result.success == false`.
  - [x] Only credit coins to `coinProvider` if the backend server explicitly returns `result.success == true`.
  - [x] If `result.error` contains a cap notice, show a gentle banner: `"You're playing in bonus mode!"` instead of pretending full coins were credited.

### Task 3.4: Security & Redemption Unit Tests
* **File:** `test/redemption_security_test.dart` (New Test File)
* **Sub-tasks:**
  - [x] Test that starter card fails if lifetime ads < 70.
  - [x] Test that starter card fails on a second attempt with the same `deviceId`.
  - [x] Test that $3.00 card fails if lifetime ads < 500.
  - [x] Test that legitimate user with 520 lifetime ads passes and receives `pending_review` status.

---

## 🎯 Phase 3 Definition of Done (DoD)
1. Edge Function `spend-coins` blocks any claim that lacks sufficient lifetime ad views.
2. The $0.50 starter card cannot be claimed more than once per physical device ID.
3. Mini-game screens never show fake balance increases if the server rejected the credit.
