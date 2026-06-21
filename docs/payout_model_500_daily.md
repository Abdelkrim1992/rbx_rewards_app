# RBX Rewards App: Financial & Tokenomics Simulation (500 Coins Daily Model)

This report presents a detailed financial simulation based on your proposed coin reward structure, updated to reflect the app's **two-tier reward system**:
*   **Quick Reward Option (Normal Coins):** Requires watching a **Rewarded Interstitial Ad** (lower eCPM, pays base coins).
*   **Premium Reward Option (Double Coins):** Requires watching a **Rewarded Video Ad** (higher eCPM, pays 2x double coins).
*   **Offerwalls:** Do not show ads (earnings are identical in both paths).
*   **User Exchange Rate:** 1,500 Coins = $1.00 USD (Redemption threshold: 3,000 Coins = $2.00 USD).
*   **Developer Earning Target Ratio:** 10:1 (Developer makes $10.00 gross revenue for every $1.00 paid to the user on offerwall activities).

---

## 📈 Executive Summary: 1,000 DAU Simulation

Our analysis shows that the two-tier reward system is **mathematically self-balancing**. Whether users choose the fast **Quick Option** (saving you reward costs but generating less ad revenue) or the **Premium Option** (costing more rewards but generating high video ad revenue), your net monthly profits remain virtually identical.

### Monthly Financial Comparison (1,000 DAU)

| Metric | Quick Path (300 Coins Daily) | Premium Path (500 Coins Daily) | Realistic Mix (50/50 Split) |
| :--- | :---: | :---: | :---: |
| **Gross Revenue** | $24,570.00 USD | $26,130.00 USD | **$25,350.00 USD** |
| **Payout Cost (0% Breakage)** | $6,000.00 USD | $10,000.00 USD | **$8,010.00 USD** |
| **Real Payout Cost (45% Breakage)** | $3,300.00 USD | $5,500.00 USD | **$4,405.50 USD** |
| **Net Monthly Profit** | **$21,270.00 USD** | **$20,630.00 USD** | **$20,944.50 USD** |
| **Profit Margin (%)** | 86.6% | 78.9% | **82.6%** |

---

## 📊 Scaled Simulation: 100 Daily Active Users (100 DAU)

At your request, we scaled down all figures to show the exact **Daily** and **Monthly** earnings and costs if you launch with **100 daily active users**:

### 1. Daily Financial Breakdown (100 DAU)

| Metric | Quick Path (300 Coins Daily) | Premium Path (500 Coins Daily) | Realistic Mix (50/50 Split) |
| :--- | :---: | :---: | :---: |
| **Daily Gross Revenue** | **$81.90 USD** | **$87.10 USD** | **$84.50 USD** |
| **Daily Payout Cost (0% Breakage)** | $20.00 USD | $33.33 USD | $26.70 USD |
| **Daily Payout Cost (45% Breakage)** | **$11.00 USD** | **$18.33 USD** | **$14.685 USD** |
| **Daily Net Profit (45% Breakage)** | **$70.90 USD** | **$68.77 USD** | **$69.815 USD** |

---

### 2. Monthly Financial Breakdown (100 DAU)

| Metric | Quick Path (300 Coins Daily) | Premium Path (500 Coins Daily) | Realistic Mix (50/50 Split) |
| :--- | :---: | :---: | :---: |
| **Monthly Gross Revenue** | **$2,457.00 USD** | **$2,613.00 USD** | **$2,535.00 USD** |
| **Monthly Payout Cost (0% Breakage)** | $600.00 USD | $1,000.00 USD | $801.00 USD |
| **Monthly Payout Cost (45% Breakage)** | **$330.00 USD** | **$550.00 USD** | **$440.55 USD** |
| **Monthly Net Profit (45% Breakage)** | **$2,127.00 USD** | **$2,063.00 USD** | **$2,094.45 USD** |
| **Profit Margin (%)** | 86.6% | 78.9% | **82.6%** |

> [!TIP]
> **Why 100 Users is a Great Start:** Even with just 100 DAUs, the app remains highly profitable, earning you **~$2,094.00 net monthly profit** while keeping reward expenses at a very manageable **$330.00 to $550.00 USD monthly**.

---

## 🎮 Earning & Ad Configuration Scenario (Daily Per User)

The daily earning potential is split across the app's features below, showing both the **Quick (Normal)** and **Premium (Double)** paths:

| Feature | Quick Option (Normal Coins) | Premium Option (Double Coins) | Cooldown / Limit | Quick Ad Type | Premium Ad Type |
| :--- | :---: | :---: | :--- | :--- | :--- |
| **Daily Claim** | 15 Coins | **30 Coins** | 24 Hours | Rewarded Interstitial | Rewarded Video |
| **Treasure Chest** | 30 Coins (avg) | **60 Coins** (avg) | 4 Hours (Max 3/day) | Rewarded Interstitial | Rewarded Video |
| **Spin & Win** | 40 Coins (avg) | **80 Coins** (avg) | 3 Free/day + 2 Ad-Extra | Rewarded Interstitial | Rewarded Video |
| **Lucky Bonus** | 20 Coins (avg) | **40 Coins** (avg) | 2 Hours (Max 2/day) | Rewarded Interstitial | Rewarded Video |
| **Mini-Games** | 45 Coins (avg) | **90 Coins** (avg) | Daily Cap: 100/50 Coins | Interstitial after game | Interstitial after game |
| **Scratch Cards** | 15 Coins (avg) | **30 Coins** (avg) | Max 2/day | Rewarded Interstitial | Rewarded Video |
| **Surveys & Quizzes** | 35 Coins (avg) | **70 Coins** (avg) | Max 1 survey + 2 quizzes | Interstitial (quizzes) | Interstitial (quizzes) |
| **Offerwalls** (No Ads) | 100 Coins | **100 Coins** | Varies | None | None |
| **Total Daily Coins** | **300 Coins** | **500 Coins** | - | **13 Rewarded Interst.** | **13 Rewarded Video** |
| **Total Interstitials** | **8 Ads** | **8 Ads** | - | **8 Interstitials** | **8 Interstitials** |

---

## 🧮 Detailed Revenue Math (Daily Per User)

### eCPM Industry Standards (Global Averages)
*   **Rewarded Video Ads (Premium):** **$12.00 USD eCPM** ($0.012 per view)
*   **Rewarded Interstitials (Quick):** **$8.00 USD eCPM** ($0.008 per view)
*   **Standard Interstitial Ads:** **$6.00 USD eCPM** ($0.006 per view)
*   **Offerwalls:** Conversion is set to **150 Coins per $1.00 USD publisher revenue** in the dashboard.

---

### ARPDAU & Profitability Breakdown

#### 1. Quick Option Path (User claims 300 Coins daily)
*   **Ad Revenue:**
    *   13 Rewarded Interstitials × $0.008 = **$0.104 USD**
    *   8 standard Interstitials × $0.006 = **$0.048 USD**
    *   *Total Ad Revenue = $0.152 USD*
*   **Offerwall Revenue:**
    *   100 Coins earned = **$0.667 USD** (100 / 150)
*   **Total ARPDAU (Quick Path):** **$0.819 USD**
*   **Face Value Payout Cost:** 300 Coins / 1,500 = **$0.200 USD**
*   **Profit margin (0% Breakage):** **75.6%**

#### 2. Premium Option Path (User claims 500 Coins daily)
*   **Ad Revenue:**
    *   13 Rewarded Videos × $0.012 = **$0.156 USD**
    *   8 standard Interstitials × $0.006 = **$0.048 USD**
    *   *Total Ad Revenue = $0.204 USD*
*   **Offerwall Revenue:**
    *   100 Coins earned = **$0.667 USD**
*   **Total ARPDAU (Premium Path):** **$0.871 USD**
*   **Face Value Payout Cost:** 500 Coins / 1,500 = **$0.333 USD**
*   **Profit margin (0% Breakage):** **61.8%**
