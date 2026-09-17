# Phase 6: Feature Coin Distribution (No Hard Limit) & Modern Reward Claim Architecture

## Executive Summary
This document establishes the production overhaul for:
1. **Feature Coin Distribution & Rewarded Ads**: Eliminating the broken "blind 2x multiplier" (`doubleAmount = widget.baseReward * 2`) and hard daily lockouts. Replacing it with a **Harmonized Flat Bonus Model (+25 to 35 coins)** dynamically governed by the **3-Tier Diminishing Yield Curve (Unlimited Earnings)**.
2. **New Reward Claim Architecture**: Transitioning from a naive "coin-only balance check" to a **Dual-Gated Claim Engine** requiring both **Coins** and **Minimum Lifetime Verified Ads** (with hardware device-lock enforcement, automated 24–48h review buffers, and an interactive "Requirements Modal" on the new `onLockedTap` hook).

---

## 1. The Flaws of the Legacy "2x Video Ad Multiplier"

In the legacy codebase (`lib/widgets/reward_claim_dialog.dart` and `lib/core/utils/reward_helper.dart`), mini-games and features relied on:
```dart
// Legacy flawed code:
final doubleAmount = widget.baseReward * 2;
```

### Why this breaks game economics and user engagement:
| Feature | Base Reward | Legacy 2X Ad Reward | User Experience / Unit Economics Impact |
| :--- | :---: | :---: | :--- |
| **Math Quiz / Tap Tap / Flappy** | 5 – 6 coins | **10 – 12 coins** (+5 coins gain) | **Terrible User Feeling:** Watching a 30-second unskippable ad for an extra 5 coins (~$0.0005 worth) causes immediate ad fatigue and high drop-off. |
| **Mega Chest** | 1,000 coins | **2,000 coins** (+1,000 coins gain) | **Bankruptcy Risk:** Paying out 2,000 coins ($0.22 wholesale Robux cost) for a single $0.020 ad impression creates a **-1,000% negative profit margin**. |
| **Hard Daily Cap Lockout** | Any | `"Daily video limit reached"` | **Kills Lifetime Value:** When users hit the old 1,000 cap or 20 ad limit, the dialog locked down completely, preventing users from playing or generating further ad revenue. |

---

## 2. The New Harmonized Distribution Model (No Hard Limit)

### Core Principles
1. **Decoupled Quick Play vs. Rewarded Bonus**:
   - Quick Play (No Ad) gives **5 – 8 coins** immediately for game completion.
   - Watching a Rewarded Video grants a **High-Yield Fixed Bonus (+25 coins)**, giving **~30 – 33 coins total**.
2. **Dynamic Scaling via Yield Curve (Infinite Earnings)**:
   - Earnings are never cut off. As a user earns more coins in a single day, the bonus automatically scales across tiers:
     - **Tier 1 (0 – 1,200 coins):** 100% payout (Base 6 + Ad Bonus 25 = **31 coins**).
     - **Tier 2 (1,201 – 2,000 coins):** 50% payout (Base 3 + Ad Bonus 12 = **15 coins**).
     - **Tier 3 (2,001+ coins / Grinder Tier):** 15% payout (Base 1 + Ad Bonus 4 = **5 coins**).
3. **Developer Profitability Guarantee**:
   - In Tier 3, a user watching a rewarded ad earns 5 coins (Robux cost: ~$0.00055). At a US/GCC eCPM of $20.00 ($0.020 per ad), your net profit is **+$0.0194 per ad (97% profit margin)**. A user can watch 100 ads a day and you remain highly profitable.

---

## 3. Comprehensive Feature-by-Feature Economy Table

| Feature Name | Cooldown / Pacing | Quick Claim (No Ad) | Rewarded Ad Boost (Tier 1) | Total Tier 1 Payout | Total Tier 2 Payout (50%) | Total Tier 3 Payout (15%) |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **Math Quiz** | None (Skill) | 6 coins | **+25 coins** | **31 coins** | 15 coins | 5 coins |
| **Tap Tap Reflex** | None (Arcade) | 5 coins | **+25 coins** | **30 coins** | 15 coins | 5 coins |
| **Flappy Jump** | None (Arcade) | 6 – 8 coins | **+25 coins** | **31 – 33 coins** | 16 coins | 5 coins |
| **Flip Card Memory**| None (Skill) | 6 coins | **+25 coins** | **31 coins** | 15 coins | 5 coins |
| **Lucky Spin Wheel** | 3 Free Spins / Day (Ad to recharge) | Slice Value (10 – 100) | **+25 coins** (or 2x on lower slices) | **35 – 75 coins** (avg ~45) | 22 coins | 7 coins |
| **Scratch & Win** | 15 min cooldown | Card Value (15 – 35) | **+20 coins bonus** | **35 – 55 coins** (avg ~40) | 20 coins | 6 coins |
| **Mystery Chest** | 3 hours cooldown | Locked behind Ad | Direct Ad Unlock | **45 – 65 coins** | 25 coins | 8 coins |
| **Mega Chest** | 24 hours cooldown | Locked behind Ad | Direct Ad Unlock | **250 coins** *(Rebalanced from 1,000)* | 125 coins | 38 coins |
| **Daily Streak** | 1x Daily (Days 1–7) | 50 – 300 coins | **+50% Streak Bonus** | **75 – 450 coins** | Unscaled | Unscaled |
| **Watch Video (Task)**| None | N/A | Direct Rewarded Ad | **25 coins** | 12 coins | 4 coins |

---

## 4. Upgrading the Reward Dialog UX (`RewardClaimDialog`)

Replace the old `DOUBLE TO +$doubleReward RBX` CTA with the modern high-incentive layout:

### Updated Dialog Architecture:
```dart
// lib/widgets/reward_claim_dialog.dart

// 1. Calculate yield-aware bonus (e.g. +25 coins instead of base * 2)
final yieldMultiplier = ref.read(dailyCapServiceProvider).getYieldMultiplier();
final bonusCoins = (25 * yieldMultiplier).round().clamp(4, 25);
final totalAdReward = widget.baseReward + bonusCoins;

// 2. Updated Primary Action Button:
DecoratedBox(
  decoration: BoxDecoration(
    gradient: AppColors.primaryGradient,
    borderRadius: BorderRadius.circular(16),
  ),
  child: ElevatedButton(
    onPressed: _handleBonusClaim,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 20),
        const SizedBox(width: 8),
        Text(
          'CLAIM +$totalAdReward RBX',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
      ],
    ),
  ),
);

// 3. Updated Secondary Quick-Claim Action:
TextButton(
  onPressed: _handleRegularClaim,
  child: Text(
    'Quick Claim (+${widget.baseReward} RBX)',
    style: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
  ),
);
```

---

## 5. The New Rewards Claim Architecture

### A. Dual-Gated Requirements Engine
To protect your ad arbitrage margins from autoclickers, script exploits, or low-ad grinders, redemption requires **both** coin balance and a **minimum lifetime verified ad threshold**:

| Denomination | Retail Value | Robux Yield | Coin Cost | Min. Lifetime Verified Ads | Your Ad Revenue (US/GCC) | Wholesale Cost | Net Profit Margin |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **$0.50 Starter** *(1x Per Device)* | $0.50 | 40 R$ | **4,500** | **$\ge 70$ ads** | ~$1.40 | $0.36 | **+74% profit** |
| **$3.00 Gift Card** | $3.00 | 240 R$ | **24,000** | **$\ge 500$ ads** | ~$10.00 | $3.00 | **+70% profit** |
| **$5.00 Gift Card** | $5.00 | 400 R$ | **38,000** | **$\ge 850$ ads** | ~$17.00 | $5.00 | **+70% profit** |
| **$10.00 Gift Card** | $10.00 | 800 R$ | **72,000** | **$\ge 1,600$ ads** | ~$32.00 | $10.00 | **+68% profit** |

### B. Hardware Device-Lock Enforcement
* **Problem:** Without device locking, malicious users create multiple accounts to churn the $0.50 Starter Reward (4,500 coins) over and over.
* **Solution:**
  1. Generate a hardware-anchored device identifier (`IDFV` on iOS, `Android_ID` / hardware UUID on Android).
  2. Maintain a `claimed_starter_devices` table in Supabase.
  3. When attempting to redeem `starter_rbx_50c`, the backend RPC `redeem_reward_v2` executes:
     ```sql
     IF is_starter AND EXISTS (SELECT 1 FROM claimed_starter_devices WHERE device_id = p_device_id) THEN
         RAISE EXCEPTION 'This device has already claimed the 1-time Starter Reward.';
     END IF;
     ```

---

## 6. Interactive Locked Reward UX Flow (`onLockedTap`)

When the user taps **"Locked"** on any card in `rewards_screen.dart`, instead of doing nothing or showing a plain snackbar, present a dedicated **"Unlock Progress Sheet"** (`_showLockedRequirementsSheet`):

### UI Components of the Locked Sheet:
1. **Header**: Reward Title, Gift Card Icon, and Robux Amount (e.g. `40 Robux Starter Pack`).
2. **Dual Progress Indicators**:
   - **Coin Requirement:** `[████████░░░░] 2,450 / 4,500 Coins (54%)`
   - **Ad Verification Requirement:** `[██████████░░] 48 / 70 Ads Watched (68%)`
3. **Remaining Deficit Summary**:
   - *"You need **2,050 more coins** and **22 more ad views** to unlock this cashout."*
4. **Direct Quick Action CTA**:
   - Primary: **"Play Games & Earn Coins"** (Navigates to Games tab).
   - Secondary: **"Watch Video (+25 Coins)"** (Launches rewarded ad directly).
5. **Authenticity Guarantee Badge**:
   - *"Official Roblox Digital Code • Delivered to Locker in 24–48h"*.

---

## 7. Redemption Security & Fulfillment Pipeline

```mermaid
flowchart TD
    A[User taps Redeem] --> B{Check Device Lock & Coins}
    B -->|Already Claimed Starter| C[Reject: Device Claimed]
    B -->|Insufficient Coins| D[Reject: Insufficient Balance]
    B -->|Eligible| E{Check Lifetime Ads}
    E -->|Ads < Min Threshold| F[Prompt: Watch remaining ads]
    E -->|Ads >= Min Threshold| G[Prompt for Roblox Username & Delivery Email]
    G --> H[Submit to Backend RPC: spend_and_order]
    H --> I[Atomic Coin Deduction & Order Insert]
    I --> J[Order Status: PENDING (24-48h Review)]
    J --> K{Automated Fraud Score}
    K -->|Suspicious Bot Activity| L[Flag for Manual Review / Reject]
    K -->|Clean Human Pattern| M[Status: FULFILLED]
    M --> N[Digital PIN Populated in Claimed Codes Locker]
    N --> O[Push Notification: 'Your Roblox Code is Ready!']
```

---

## 8. Actionable Checklist for Implementation

- [ ] **Step 1: Update Reward Claim Dialog** (`lib/widgets/reward_claim_dialog.dart`):
  - Change default ad award from `base * 2` to `base + bonusCoins` (+25 coins scaled by yield multiplier).
  - Update button text to dynamic `CLAIM +$totalAdReward RBX`.
- [ ] **Step 2: Update Mini-Game Call Sites**:
  - Verify all mini-games pass base values of 5–8 coins to `showRewardChoice`.
- [ ] **Step 3: Rebalance Mega Chest** (`lib/presentation/screens/chest_screen.dart`):
  - Set Mega Chest reward to fixed 250 coins (down from 1,000).
- [ ] **Step 4: Implement Locked Requirements Modal** (`lib/presentation/screens/rewards_screen.dart`):
  - Bind `onLockedTap` on `_RewardGridCard` to display dual progress (Coins + Ads Watched).
- [ ] **Step 5: Add Supabase Dual-Gate RPC**:
  - Deploy `supabase/migrations/031_dual_gated_redemption.sql` enforcing `lifetime_ads >= min_required_ads` and `device_id` uniqueness.
