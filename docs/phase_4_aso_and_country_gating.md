# Phase 4: App Store ASO & Country-Gating
## Implementation Specification & Task Breakdown

---

## 🎯 Phase Objective
Configure the **Apple App Store (iOS)** listing metadata to maximize organic impressions from verified single-word searches (`RBX`, `Rewards`, `Blox`, `Mini`, `Games`, `Play`, `Claim`, `Point`), double the keyword footprint via **Spanish (Mexico) cross-localization**, and country-gate the app to high-paying Tier 1 and GCC regions.

---

## 📐 Store Metadata Specification

### 1. English (U.S.) Primary Listing
* **App Title (29 / 30 chars):**
  > `RBX Rewards: Blox Mini Games`
* **Subtitle (29 / 30 chars):**
  > `Play Fast Quiz & Claim Point`
  *(Note: Uses singular `Point` which has 13.5K reach vs 1.2K plural `points`)*
* **Keywords Field (98 / 100 chars, comma-separated, no spaces):**
  > `roblox,robux,digital,unlock,tap,password,daily,spin,scratch,card,free,win,gems,safe,codes,cash,earn`

### 2. Spanish (Mexico) Secondary Listing (Cross-Indexes in US App Store)
* **Title (30 / 30 chars):**
  > `RBX Rewards: Fast Coin Counter`
* **Subtitle (30 / 30 chars):**
  > `Win Gift Cards & Daily Bonus`
* **Keywords Field (98 / 100 chars):**
  > `calc,calculator,chest,loot,wheel,pass,generator,skin,avatar,real,secret,tips,juegos,premios,gratis`

### 3. App Store Categories
* **Primary Category:** `Apps / Entertainment` (or `Apps / Lifestyle`)
* **Secondary Category:** `Games / Casual` (or `Games / Trivia`)

---

## 📋 Actionable Tasks

### Task 4.1: Country Availability Configuration (App Store Connect)
* **Location:** App Store Connect $\rightarrow$ App $\rightarrow$ Pricing and Availability $\rightarrow$ App Availability
* **Sub-tasks:**
  - [ ] **UNCHECK / REMOVE:** India, Pakistan, Kazakhstan, Nigeria, Bangladesh, Uzbekistan, Russia, Belarus.
  - [ ] **CHECK / ENABLE HIGH-VALUE REGIONS:**
    - **Tier 1 West:** United States, United Kingdom, Canada, Australia, Germany, France, Sweden, Norway.
    - **High-eCPM GCC (The Roblox Goldmine):** Saudi Arabia, United Arab Emirates, Kuwait, Qatar, Bahrain, Oman.

### Task 4.2: App Store Metadata Setup
* **Location:** App Store Connect $\rightarrow$ Version Information
* **Sub-tasks:**
  - [ ] Set English (U.S.) Title to `RBX Rewards: Blox Mini Games`.
  - [ ] Set English (U.S.) Subtitle to `Play Fast Quiz & Claim Point`.
  - [ ] Paste the 98-character English keyword list.
  - [ ] Add Language: **Spanish (Mexico)**.
  - [ ] Set Spanish (Mexico) Title, Subtitle, and Keywords.
  - [ ] Set Primary Category to `Entertainment` and Secondary to `Casual Games`.

### Task 4.3: App Store Description & Compliance Disclaimer
* **Location:** App Store Connect $\rightarrow$ Description Field
* **Sub-tasks:**
  - [ ] Add the bullet point highlighting: *"🛡️ Safe & Secure: No password or account login required!"* (Captures conversion on the 116K `password` search volume).
  - [ ] Add the mandatory legal disclaimer at the bottom of the description:
    ```text
    Disclaimer:
    Roblox and Robux are registered trademarks of Roblox Corporation. 
    This application is an independent fan rewards utility and is not affiliated with, 
    sponsored, or endorsed by Roblox Corporation. All digital codes and vouchers are 
    sourced and purchased from official authorized retailers.
    ```

### Task 4.4: In-App Review Prompt Timing (ASO Rating Booster)
* **Files:**
  * `lib/presentation/screens/chest_screen.dart`
  * `lib/presentation/screens/spin_screen.dart`
* **Sub-tasks:**
  - [ ] Hook into the native in-app review dialog (`in_app_review` package).
  - [ ] Trigger review prompt **only** after a high-dopamine event (e.g., user hits a 2x jackpot on the Wheel or opens a Mystery Chest for the first time).
  - [ ] Target: collect 25–40 five-star ratings during the first 14 days to boost App Power.

---

## 🎯 Phase 4 Definition of Done (DoD)
1. App Store Connect listing has English (US) and Spanish (Mexico) configured with exact 200-character keyword coverage.
2. Low-eCPM countries (India, Pakistan, Kazakhstan) are disabled in App Availability.
3. Description includes the safety notice and mandatory Roblox trademark disclaimer.
4. In-app review trigger is implemented at high-dopamine game events.
