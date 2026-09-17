# Phase 2: Catalog Restructuring & Starter Reward
## Implementation Specification & Task Breakdown

---

## 🎯 Phase Objective
Introduce the **$0.50 Starter Reward (4,500 coins / 40 Robux)** to create an immediate "quick win" (reachable in 2.5–3 days), destroy user skepticism, and build 100% trust. Re-scale the higher reward tiers ($3.00, $5.00, $10.00) to ensure high retention and guaranteed profit margins.

---

## 📐 Catalog Specification

| Reward Denomination | Real Cash Value | Robux Equivalent | Coin Cost | Pacing / Ads to Fund | Net Margin |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Tier 1: Starter Robux Voucher** | **$0.50** | 40 R$ | **4,500 coins** | **2.5 – 3 days** (~90 ads) | **51%** (1-time limit) |
| **Tier 2: Popular Roblox Card** | **$3.00** | 240 R$ | **24,000 coins** | **11 – 14 days** (~750 ads) | **52%** |
| **Tier 3: Pro Roblox Card** | **$5.00** | 400 R$ | **38,000 coins** | **18 – 22 days** (~1,250 ads) | **52%** |
| **Tier 4: Mega Roblox Card** | **$10.00** | 800 R$ | **72,000 coins** | **35 – 40 days** (~2,200 ads) | **54%** |

---

## 📋 Actionable Tasks

### Task 2.1: Update `RewardItem` Catalog Data
* **File:** `lib/models/reward_item.dart`
* **Sub-tasks:**
  - [x] Add `bool isOneTimeStarter` property to `RewardDenomination` (defaults to `false`).
  - [x] Add `starter_rbx_50c` denomination ($0.50 / 40 Robux / 4,500 coins, `isOneTimeStarter: true`).
  - [x] Update `$3 Roblox Gift Card` (`rbx_card_3`) from 20,000 coins to `24,000 coins`.
  - [x] Update `$5 Roblox Gift Card` (`rbx_card_5`) from 40,000 coins to `38,000 coins`.
  - [x] Update `$10 Roblox Gift Card` (`rbx_card_10`) from 70,000 coins to `72,000 coins`.
  - [x] Remove or deprecate temporary 1,000-coin test cards (`rbx_card_1k_test`, `test_voucher_1000`).

### Task 2.2: Add Starter Reward Badge & UI Distinction
* **Files:**
  * `lib/presentation/screens/rewards_screen.dart`
  * `lib/presentation/screens/rewards/widgets/`
* **Sub-tasks:**
  - [x] Highlight the $0.50 starter tier with a *"🔥 Starter Quick Reward (1-Time Only)"* visual badge.
  - [x] If user has already claimed the starter reward, disable it in the UI and show *"Claimed"*.
  - [x] Update confirmation dialog to clearly show the 40 Robux delivery instructions.

### Task 2.3: Endowed Progress & Home Screen Goal Widget
* **Files:**
  * `lib/presentation/screens/home_screen.dart`
  * `lib/presentation/screens/home/widgets/`
* **Sub-tasks:**
  - [x] By default, set the active user goal to `starter_rbx_50c` for brand-new users.
  - [x] Give new users **500 coins** Welcome Bonus on signup (so they immediately see **11% progress** on their goal bar!).
  - [x] Add an animated progress ring/bar on the Home screen displaying:
    `"🎯 Only X coins left to claim your 40 Robux!"`

### Task 2.4: Update Reward Catalog Unit Tests
* **File:** `test/reward_catalog_test.dart`
* **Sub-tasks:**
  - [x] Validate `RewardItem.defaultCatalog` contains `starter_rbx_50c` with cost 4,500 coins.
  - [x] Validate minimum cost is 4,500 coins (no active 1,000 coin test vouchers).
  - [x] Ensure goal calculations correctly compute progress towards 4,500 coins.

---

## 🎯 Phase 2 Definition of Done (DoD)
1. Shop catalog displays the new tiers ($0.50 for 4,500 coins, $3 for 24K, $5 for 38K).
2. New users start with 500 welcome coins and see an active progress bar toward the 4,500 starter voucher.
3. Automated unit tests verify catalog integrity and denomination pricing.
