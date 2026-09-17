# Phase 1: Coin Economy Model & Diminishing Yield Curve
## Implementation Specification & Task Breakdown

---

## 🎯 Phase Objective
Transition the app from the broken hard daily cap (1,000 coins lockout) to an **Ad-Pegged Diminishing Yield Curve (Soft Cap)**. 
Ensure grinders can play continuously while mathematically guaranteeing that your ad revenue exceeds reward liability across all player brackets.

---

## 📐 Economic Specification

### 1. The 3-Tier Diminishing Returns Schedule
* **Tier 1 (0 – 1,200 coins earned today):** **1.0x (100% full speed)**
  * Rewarded Ad Bonus: `+25 to +35 coins`
  * Base gameplay: `+3 to +5 coins`
  * Profit margin: ~50%
* **Tier 2 (1,201 – 2,200 coins earned today):** **0.5x (50% normal speed)**
  * Rewarded Ad Bonus: `+12 to +18 coins`
  * Base gameplay: `+2 coins`
  * Profit margin: ~70%
* **Tier 3 (2,201+ coins earned today - Grinders):** **0.15x (15% micro-rewards)**
  * Rewarded Ad Bonus: `+3 to +5 coins`
  * Base gameplay: `+1 coin`
  * Profit margin: **90% - 95%**

---

## 📋 Actionable Tasks

### Task 1.1: Update `DailyCapService` with Dynamic Multiplier
* **File:** `lib/business/daily_cap_service.dart`
* **Sub-tasks:**
  - [x] Add `double getYieldMultiplier()` method computing multiplier based on `_todayFeaturesEarnings`.
  - [x] Remove `isFeaturesCapReached` hard boolean cutoff from blocking gameplay.
  - [x] Update `addCoins(int amount, String source)` to apply `getYieldMultiplier()` before adding coins rather than clamping to 0.
  - [x] Update `getRemainingCap(String source)` to return uncapped or soft-tier remaining values.
  - [x] Verify secure storage persistence of daily earnings and reset at midnight UTC.

### Task 1.2: Update Supabase Backend & Database RPC
* **Files:**
  * `supabase/functions/add-game-coins/index.ts`
  * `supabase/functions/credit-coins/index.ts`
  * `supabase/migrations/029_diminishing_yield_curve.sql` (New Migration)
* **Sub-tasks:**
  - [x] Remove hard rejection (`Daily game cap reached`) from `add-game-coins/index.ts` lines 147–156.
  - [x] Update SQL function `process_game_session` to calculate today's earnings and apply the multiplier:
    - If `v_daily_total < 1200`: award full score.
    - If `v_daily_total BETWEEN 1200 AND 2200`: scale score by 0.5.
    - If `v_daily_total >= 2200`: scale score by 0.15 (minimum 1 coin).
  - [x] Update SQL function `credit_user_coins` to match the diminishing returns curve.
  - [x] Invalidate Redis user profile cache on credit.

### Task 1.3: Update Ad Limits in `AdTrackerService`
* **File:** `lib/business/ad_tracker_service.dart`
* **Sub-tasks:**
  - [x] Increase `maxDailyTotalAds` from `20` to `60`.
  - [x] Increase `maxDailyOptionalAds` from `20` to `55`.
  - [x] Keep `maxDailyForcedAds` at `10` (protects user experience from aggressive interstitials).
  - [x] Test `canShowOptionalAd()` to ensure users can watch ads up to 60 times/day.

### Task 1.4: Unit & Integration Testing for Phase 1
* **File:** `test/dynamic_coin_rewards_test.dart`
* **Sub-tasks:**
  - [x] Test `DailyCapService`: Verify multiplier returns `1.0` below 1,200 coins, `0.5` between 1,200–2,200, and `0.15` above 2,200.
  - [x] Test coin credit when user has earned 1,500 coins today: ensure 30 coins awarded becomes 15 coins.
  - [x] Test coin credit when user has earned 2,500 coins today: ensure 30 coins awarded becomes 5 coins.
  - [x] Verify that balance refresh never drops balance to 0.

---

## 🎯 Phase 1 Definition of Done (DoD)
1. User can play mini-games all day without ever receiving a "Daily limit reached" error or having their balance reset to 0 upon refreshing.
2. Daily earnings smoothly taper down across the 3 tiers.
3. Automated unit tests in `test/dynamic_coin_rewards_test.dart` pass with 100% green status.
