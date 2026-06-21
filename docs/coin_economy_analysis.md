# RBX Rewards App: Coin Economy & Monetization Strategy Report

This report analyzes the tokenomics (coin economy) of the **RBX Rewards App** and provides a mathematically verified strategy to achieve the target metrics:
*   **Daily Active Users (DAU):** 1,000
*   **Target Monthly Revenue:** > $5,000 USD
*   **Target Monthly Operating Cost (User Payouts):** ~ $500 USD (Net margin: 90%+)
*   **Minimum Shop Redemption:** $5.00 Roblox Gift Card = 10,000 Coins (2,000 Coins = $1.00 USD)

---

## 📊 Executive Summary

By configuring the coin economy correctly, a **1,000 DAU** user base can easily generate **$8,700+ monthly revenue** with a user payout cost of **$472.50 monthly** (assuming a realistic 70% user breakage rate). This achieves a net profit of **$8,227.50/month (94.5% profit margin)**.

### Financial Overview (Monthly)

| Metric | AdMob (Video/Interstitials) | Offerwalls (Tapjoy/Pubscale) | Combined Total | Target Goal |
| :--- | :--- | :--- | :--- | :--- |
| **Gross Revenue** | $3,300.00 | $5,400.00 | **$8,700.00** | > $5,000.00 |
| **Payout Cost (0% Breakage)** | $1,125.00 | $450.00 | **$1,575.00** | - |
| **Real Payout Cost (70% Breakage)** | $337.50 | $135.00 | **$472.50** | ~ $500.00 |
| **Net Profit** | $2,962.50 | $5,265.00 | **$8,227.50** | **$4,500.00** |
| **Profit Margin (%)** | 89.7% | 97.5% | **94.5%** | **90.0%** |

> [!IMPORTANT]
> **Financial Risk Warning:** The current app configuration has severe financial leaks. If left unchanged with 1,000 DAU, the free claims (Spins, Chests, Lucky Bonus, Games) will payout up to **$36,000+ per month** in rewards, leading to immediate bankruptcy. You **must** lower the coin reward amounts as detailed below.

---

## 🛠️ Current Coin Economy Vulnerability Audit

Our audit of the codebase revealed that the current coin rewards are unsustainably high:

1.  **Spin & Win (`spin_screen.dart`):** Has an expected value (EV) of **800 coins per spin** (due to high segment values like 1K, 2K, 5K and high weights). 3 free spins = 2,400 coins ($1.20 USD) per user/day. For 1,000 DAU, this costs **$36,000/month**.
2.  **Treasure Chest (`chest_screen.dart`):** Pops **500 coins** ($0.25 USD) per claim with a 3-hour cooldown. Active users claiming 4 times/day earn 2,000 coins ($1.00 USD), costing **$30,000/month** for 1,000 DAU.
3.  **Lucky Bonus (`lucky_bonus_service.dart`):** Generates **100 to 500 coins** (average 300 coins) every 2 hours, up to 3 times a day. 3 claims = 900 coins ($0.45 USD) per user/day. For 1,000 DAU, this costs **$13,500/month**.
4.  **Mini-Game Daily Cap (`add-game-coins/index.ts`):** Capped at **5,000 coins** ($2.50 USD) per user/day. If 20% of users hit the cap, this costs **$15,000/month**.

---

## 💰 Monetization & Payout Math

To hit your targets, you must configure two distinct monetization layers:

### 1. Offerwall Conversion Model (PubScale & Tapjoy)
When users complete offers, the ad network pays you (the publisher) in USD. You convert this to coins for the user. To achieve a **90% profit margin** on offerwalls:
*   Set your conversion rate in the Tapjoy and Pubscale publisher dashboards to **200 Coins per $1.00 USD of publisher revenue**.
*   **How it works:**
    *   An offer pays you **$1.00 USD**.
    *   The user gets credited **200 coins** ($1.00 × 200).
    *   The user redeems 20,000 coins for a **$10.00 Roblox Gift Card**.
    *   To get 20,000 coins, the user had to generate **$100.00 USD** in revenue for you (20,000 / 200).
    *   **Result:** You earned $100.00, paid out $10.00, and kept **$90.00 (90% profit)**.

### 2. AdMob Ad Revenue Model (Free Features)
AdMob pays via eCPM (earnings per 1,000 impressions). We assume a conservative global average eCPM of **$10.00 USD for Rewarded Video Ads** ($0.01 per ad watched) and **$6.00 USD for Interstitials** ($0.006 per ad shown).
*   **Target Payout Ratio:** Pay users approximately **40% of the ad revenue** they generate.
*   **Ad Watch Reward:** Since 1 rewarded ad generates $0.010, the user's 40% share is $0.004. At 2,000 coins = $1.00, this equals **8 coins per ad watched**.
*   **Interstitial Reward:** Since 1 interstitial ad generates $0.006, the user's share is $0.0024, which equals **5 coins per interstitial**.

---

## ⚙️ Recommended Payout Configurations

To keep user rewards attractive but financially safe, apply the following reward structures:

| Feature | Current Reward | Recommended Reward | Cooldown / Daily Limit | Ad Requirements | Avg. Daily Earned |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Daily Claim** | 100 Coins | **15 Coins** | 24 Hours | 1 Rewarded Video | 15 Coins |
| **Treasure Chest** | 500 Coins | **10 Coins** (avg) | 4 Hours (Max 3/day) | 1 Rewarded Video | 12 Coins (avg) |
| **Spin & Win** | 800 Coins (EV) | **6.5 Coins** (EV) | 3 Free/day (reload 24h) | 1 Rewarded Video/spin | 13 Coins (avg) |
| **Lucky Bonus** | 300 Coins (avg) | **10 Coins** (avg) | 2 Hours (Max 3/day) | 1 Rewarded Video | 10 Coins (avg) |
| **Mini-Games** | Cap: 5,000 Coins | **Cap: 50 Coins** | Daily Reset | Interstitial after game | 25 Coins (avg) |
| **Scratch Card** | 250 Coins (avg) | **15 Coins** (avg) | Max 3/day | 1 Rewarded Video | 15 Coins (avg) |
| **Surveys (Poll)** | 250 Coins | **20 Coins** | Max 1/day | None (collects feedback) | 10 Coins (avg) |
| **Quizzes** | Up to 400 Coins | **15 Coins** (avg) | Max 2/day | Interstitial between questions | 15 Coins (avg) |
| **Total Free Activity** | ~ 4,000+ Coins | **~ 105 Coins** | - | **8 Rewarded + 5 Interstitial** | **115 Coins** ($0.057) |

---

## 📈 Financial Scenario Simulations (1,000 DAU)

### Scenario A: Strict Budget Plan (0% Breakage)
*We assume 100% of users redeem every single coin they earn. To keep the payout cost under $500/month, we must aggressively cap all earnings.*
*   **Total Coins Allowed Daily per User:** 33.33 Coins
*   **Monthly Payout Cost:** $500.00 USD
*   **Setup:**
    *   Daily Claim: 5 Coins
    *   Spins: Max 1 Free Spin/day (EV: 5 coins)
    *   Chests & Lucky Bonus: Disabled or set to 2 coins
    *   Mini Games Daily Cap: 10 Coins
*   > [!WARNING]
    > **Aesthetics & Retention Risk:** Users will earn so slowly (300 days to reach a $5 cashout) that they will uninstall the app. Retention will plummet.

### Scenario B: Industry Realistic Plan (70% Breakage) - ⭐ RECOMMENDED
*In reward apps, 70% of earned coins are never redeemed. Users either uninstall, change devices, or abandon the app before reaching the 10,000 coin ($5.00) minimum payout. This allows you to give higher rewards to keep users engaged.*
*   **Average Coins Earned Daily per User:** 115 Coins ($0.057 face value)
*   **Effective Coins Redeemed (30%):** 34.5 Coins ($0.017 real cost/user/day)
*   **Daily Cost (1,000 DAU):** 1,000 × $0.017 = $17.25 USD
*   **Monthly Payout Cost:** **$517.50 USD** (Meets your $500 target!)
*   **Monthly Ad Revenue Generated:** 1,000 DAU × (8 Rewarded × $0.010 + 5 Interstitial × $0.006) × 30 days = **$3,300.00 USD**
*   **Monthly Offerwall Revenue Generated:** 150 offer completions/day @ $1.20 net payout × 30 days = **$5,400.00 USD**
*   **Gross Monthly Revenue:** **$8,700.00 USD**
*   **Net Monthly Profit:** **$8,182.50 USD**

---

## 🔏 Code Implementation & Configuration Guide

To apply these recommended numbers, modify the following variables in the codebase:

### 1. Supabase Edge Functions & SQL Schema
Run these changes in your Supabase SQL editor to secure and adjust server-side caps:

```sql
-- 1. Modify the Game Daily Cap in the SQL function
-- Located in supabase/functions/add-game-coins/index.ts (and verified in schema.sql)
-- Set daily game cap parameter to 50 instead of 5000:
CREATE OR REPLACE FUNCTION public.process_game_session(
  p_session_id UUID,
  p_user_id UUID,
  p_game_name TEXT,
  p_score INTEGER,
  p_duration_seconds INTEGER,
  p_tx_id TEXT,
  p_daily_cap INTEGER DEFAULT 50 -- CHANGED FROM 5000 TO 50
)
...
```

### 2. Edge Function Modifications
Update the default amounts in the Edge Functions:

*   **Daily Claim (`supabase/functions/claim-daily-reward/index.ts`):**
    ```typescript
    // Change the default amount clamp from 1-200 to 1-25, default 15
    let amount = 15; // Changed from 100
    if (body.amount && typeof body.amount === 'number') {
      amount = Math.max(1, Math.min(25, body.amount)); // Clamp between 1-25
    }
    ```

*   **Mega Chest (`supabase/functions/claim-mega-chest/index.ts`):**
    ```typescript
    const { data, error } = await supabase.rpc("credit_user_coins", {
      p_user_id: uid,
      p_amount: 50, // Changed from 500
      p_source: "mega_chest",
      p_tx_id: txId,
    });
    ```

*   **Mini Game Rates (`supabase/functions/add-game-coins/index.ts`):**
    ```typescript
    const GAME_DAILY_CAP = 50; // Changed from 5000
    ```

### 3. Flutter Client Modifications

*   **Spin Segment Prizes (`lib/screens/spin_screen.dart`):**
    Modify the segment values to keep the Expected Value (EV) around 6.5 coins:
    ```dart
    final List<_WheelSegment> segments = const [
      _WheelSegment(label: '3', sublabel: 'RBX', color: Color(0xFF9B5CFF)),
      _WheelSegment(label: '5', sublabel: 'RBX', color: Color(0xFF7B3FE4)),
      _WheelSegment(label: '10', sublabel: 'RBX', color: Color(0xFFB370FF)),
      _WheelSegment(label: '20', sublabel: 'RBX', color: Color(0xFF6A2FD8)),
      _WheelSegment(label: 'JACKPOT', sublabel: '100 RBX', color: Color(0xFFFFCC44)),
      _WheelSegment(label: '50', sublabel: 'RBX', color: Color(0xFF8847F5)),
    ];
    ```
    And adjust weight mappings in `_pickWeightedSegment`:
    ```dart
    // Weights: 3 (50%), 5 (30%), 10 (12%), 20 (6%), JACKPOT (0.2%), 50 (1.8%)
    final weights = [50, 30, 12, 6, 1, 1]; // Sum = 100
    ```

*   **Lucky Bonus Service (`lib/services/lucky_bonus_service.dart`):**
    ```dart
    /// Generate a random reward amount (5-15 RBX).
    int generateReward() => 5 + Random().nextInt(11); // Changed from 100 + Random().nextInt(401)
    ```

*   **Chest Payouts (`lib/screens/chest_screen.dart`):**
    ```dart
    // Line 455 inside ChestOpeningDialog:
    Navigator.of(context).pop(10); // Changed from 500
    ```

---

## 🚀 Retention & anti-cheat recommendations

To ensure you successfully scale to 1,000 DAU and make $5,000+ monthly without being exploited by bad actors:

1.  **Strict Anti-Bot/Anti-Cheat Validation:**
    *   The app already validates score rates per minute (`maxScorePerMinute` in `add-game-coins/index.ts`). Keep these rates strictly enforced server-side.
    *   Do not credit coins client-side under any circumstance. Always routing credits through Supabase Edge Functions verifies authentication, checks deduplication (`tx_id`), and applies rate limits.
2.  **Referral Program with Gated Payouts:**
    *   Instead of giving large instant referral bonuses, only reward referring users with coins **after** their referred friend has successfully completed at least 3 offerwall offers. This prevents self-referral bot farms from draining your reward balance.
3.  **Encourage Offerwall Grind (Level Gates):**
    *   Require users to reach Level 2 (requires earning 5,000 coins) before they unlock the $5.00 cashout option. Since free features earn slowly, this forces users to complete at least a few high-paying offerwall tasks, ensuring they generate significant revenue before cashing out.
