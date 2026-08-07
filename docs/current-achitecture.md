# RBX Rewards App — Architecture

> **Platform**: Flutter (iOS & Android)  
> **Backend**: Supabase (PostgreSQL + Edge Functions + Realtime)  
> **State Management**: Provider (`ChangeNotifier`)  
> **Version**: 1.0.0+1

---

## Table of Contents

1. [High-Level Overview](#1-high-level-overview)
2. [Project Structure](#2-project-structure)
3. [Flutter Client Architecture](#3-flutter-client-architecture)
   - 3.1 [Entry Point & Bootstrapping](#31-entry-point--bootstrapping)
   - 3.2 [Navigation](#32-navigation)
   - 3.3 [State Management](#33-state-management)
   - 3.4 [Screens](#34-screens)
   - 3.5 [Services Layer](#35-services-layer)
   - 3.6 [Models](#36-models)
   - 3.7 [Widgets](#37-widgets)
   - 3.8 [Theme & Utils](#38-theme--utils)
4. [Backend Architecture (Supabase)](#4-backend-architecture-supabase)
   - 4.1 [Database Schema](#41-database-schema)
   - 4.2 [RPC Functions](#42-rpc-functions)
   - 4.3 [Edge Functions](#43-edge-functions)
   - 4.4 [Row Level Security](#44-row-level-security)
   - 4.5 [Realtime Subscriptions](#45-realtime-subscriptions)
5. [Reward Economy](#5-reward-economy)
6. [Offline & Resilience Strategy](#6-offline--resilience-strategy)
7. [Third-Party Integrations](#7-third-party-integrations)
8. [Security Model](#8-security-model)
9. [Data Flow Diagrams](#9-data-flow-diagrams)
10. [Database Migrations History](#10-database-migrations-history)

---

## 1. High-Level Overview

RBX Rewards is a **mobile rewards app** where users earn in-app coins (RBX) by:
- Completing mini-games (Flappy Jump, Tap Tap, Flip Cards, Math Quiz)
- Watching ads (Google Mobile Ads rewarded units)
- Spinning a daily lucky wheel
- Completing offerwall tasks (Tapjoy / PubScale)
- Claiming a daily reward
- Opening chests

Earned coins can be redeemed for real-world rewards (Robux gift cards, etc.).

```
┌─────────────────────────────────────┐
│         Flutter Mobile App          │
│  ┌─────────┐  ┌─────────────────┐   │
│  │Provider │  │  Screen / UI    │   │
│  │AppState │◄─│  (16 screens)   │   │
│  │AdState  │  └────────┬────────┘   │
│  └────┬────┘           │            │
│       │      ┌─────────▼────────┐   │
│       │      │  Services Layer  │   │
│       │      │ (14 services)    │   │
│       └──────►                  │   │
│              └────────┬─────────┘   │
└───────────────────────┼─────────────┘
                        │  HTTPS / Realtime WS
          ┌─────────────▼──────────────┐
          │       Supabase Backend      │
          │  ┌───────────────────────┐  │
          │  │  PostgreSQL Database  │  │
          │  │  + RLS + RPC funcs    │  │
          │  └───────────────────────┘  │
          │  ┌───────────────────────┐  │
          │  │  Deno Edge Functions  │  │
          │  │  (12 endpoints)       │  │
          │  └───────────────────────┘  │
          │  ┌───────────────────────┐  │
          │  │  Supabase Realtime    │  │
          │  │  (balance streaming)  │  │
          │  └───────────────────────┘  │
          └─────────────────────────────┘
```

---

## 2. Project Structure

```
rbx_rewards/
├── lib/
│   ├── main.dart                 # App entry, DI wiring, bootstrap
│   ├── models/                   # Pure data models
│   │   ├── ad_models.dart
│   │   ├── badge_model.dart
│   │   └── reward_config.dart
│   ├── state/                    # ChangeNotifier providers
│   │   ├── app_state.dart        # Core business state
│   │   └── ad_state.dart         # Ad lifecycle state
│   ├── services/                 # Infrastructure / API layer
│   │   ├── auth_service.dart
│   │   ├── coin_service.dart
│   │   ├── reward_service.dart
│   │   ├── game_service.dart
│   │   ├── ad_service.dart
│   │   ├── ad_tracker_service.dart
│   │   ├── analytics_service.dart
│   │   ├── badge_service.dart
│   │   ├── connectivity_service.dart
│   │   ├── daily_cap_service.dart
│   │   ├── lucky_bonus_service.dart
│   │   ├── pending_transaction_service.dart
│   │   ├── pubscale_service.dart
│   │   └── tapjoy_service.dart
│   ├── screens/                  # Full-page UI screens (16)
│   ├── widgets/                  # Reusable UI components (15)
│   ├── theme/
│   │   └── app_theme.dart        # Design tokens & Material theme
│   └── utils/
│       └── reward_helper.dart    # Reward calculation utilities
├── supabase/
│   ├── schema.sql                # Canonical DB schema
│   ├── migrations/               # Incremental migrations (009 applied)
│   └── functions/                # Deno Edge Functions (12)
├── assets/
│   ├── icons/
│   └── images/
└── pubspec.yaml
```

---

## 3. Flutter Client Architecture

### 3.1 Entry Point & Bootstrapping

**`lib/main.dart`** runs the following startup sequence:

1. Lock orientation to portrait.
2. Read `SUPABASE_URL` and `SUPABASE_ANON_KEY` from `--dart-define-from-file=.env`.
3. Initialize Supabase (gracefully degrades to offline mode if missing).
4. Instantiate services: `AuthService`, `CoinService`, `RewardService`, `AdService`, `AdTrackerService`, `ConnectivityService`, `LuckyBonusService`, `TapjoyService`.
5. Wrap the widget tree in a `MultiProvider` exposing three providers:
   - `AppState` — core user & game state.
   - `AdState` — ad loading & reward lifecycle.
   - `ConnectivityService` — network status.
6. Constrain the app to a max width of **500 px** (phone-optimised web layout).

### 3.2 Navigation

Navigation is handled imperatively by `AppNavigator` (a `StatefulWidget`), **not** by named routes. State drives the visible screen:

```
AppNavigator
 ├─ LoadingScreen          (while !appState.isLoaded)
 ├─ OnboardingScreen       (first launch)
 ├─ SpinScreen             (_showSpin == true, overlay on tab nav)
 └─ Tab-based shell        (bottom nav, 5 tabs)
     ├─ [0] HomeScreen
     ├─ [1] GamesScreen
     ├─ [2] OffersScreen
     ├─ [3] RewardsScreen
     └─ [4] ProfileScreen
```

Screen transitions use `AnimatedSwitcher` with a 500 ms fade. Back-press on Android is intercepted by `PopScope` to show a quit confirmation dialog.

### 3.3 State Management

The app uses **Provider** (`ChangeNotifier`) — a lightweight, reactive state solution.

#### `AppState` (`lib/state/app_state.dart`)

The central store. Responsibilities:

| Concern | Details |
|---|---|
| **User profile** | `coins`, `totalCoinsEarned`, `level`, `displayName`, `profilePhotoUrl` |
| **Streaks** | `consecutiveDays`, `gamesPlayed`, `offersCompleted` |
| **Daily reward** | Cooldown timer, claim logic (server or local fallback) |
| **Spin wheel** | Free spins counter, 24-hour cooldown timer |
| **Coin ops** | `addCoins()`, `spendCoins()` with optimistic updates |
| **Offline queue** | Enqueues failed transactions, flushes on reconnect |
| **iOS Keychain fix** | Clears stale Keychain on fresh install |

Key design patterns:
- **Optimistic updates** — UI updates immediately; server confirms asynchronously.
- **`_pendingCoinOps` guard** — prevents Realtime stream from overwriting optimistic balance while a mutation is in-flight.
- **`ValueNotifier` for timers** — `dailyRewardRemainingNotifier` and `spinCooldownRemainingNotifier` allow fine-grained widget rebuilds without re-rendering the entire tree.

#### `AdState` (`lib/state/ad_state.dart`)

Manages Google Mobile Ads lifecycle:
- Loads rewarded ads on demand.
- Tracks ad-watch session state (loading, showing, completed).
- Integrates with `AdTrackerService` to enforce daily ad caps.

#### `ConnectivityService` (`lib/services/connectivity_service.dart`)

A standalone `ChangeNotifier` that streams network status via `connectivity_plus`. Consumed directly via `Provider`.

### 3.4 Screens

| Screen | Description |
|---|---|
| `loading_screen.dart` | Splash while app boots |
| `onboarding_screen.dart` | First-launch feature intro |
| `home_screen.dart` | Dashboard — daily reward, quick actions, stats |
| `spin_screen.dart` | Lucky wheel with coin prizes |
| `games_screen.dart` | Game catalogue & entry points |
| `tap_tap_game_screen.dart` | Tap speed mini-game (Flame engine) |
| `flappy_jump_game_screen.dart` | Flappy-style platformer (Flame engine) |
| `flip_card_game_screen.dart` | Memory flip-card game |
| `math_quiz_screen.dart` | Arithmetic quiz game |
| `quizzes_screen.dart` | Quiz hub screen |
| `chest_screen.dart` | Chest opening / loot mechanic |
| `earn_more_screen.dart` | Ad-watch & bonus earning hub |
| `offers_screen.dart` | Tapjoy / PubScale offerwall host |
| `rewards_screen.dart` | Coin redemption store |
| `leaderboard_screen.dart` | Per-game & global rankings |
| `profile_screen.dart` | User profile, stats, history |

### 3.5 Services Layer

Services are plain Dart classes (no `ChangeNotifier`) that encapsulate all I/O. They are instantiated in `main.dart` and injected into state providers.

| Service | Responsibility |
|---|---|
| `AuthService` | Supabase anonymous sign-in / sign-out |
| `CoinService` | Coin credit/spend RPCs, user data stream, spin state, leaderboard |
| `RewardService` | Daily reward claim, cooldown query |
| `GameService` | Submit game sessions (`process_game_session` RPC), offline queuing |
| `AdService` | Google Mobile Ads — load & show rewarded ads |
| `AdTrackerService` | Tracks daily ad views to enforce caps |
| `AnalyticsService` | App event tracking |
| `BadgeService` | Achievement badge logic |
| `ConnectivityService` | Real-time network status |
| `DailyCapService` | Client-side daily earning cap enforcement |
| `LuckyBonusService` | Persistent "lucky bonus" multiplier state |
| `PendingTransactionService` | Offline queue (serialized to `SharedPreferences`) |
| `PubscaleService` | PubScale offerwall SDK integration |
| `TapjoyService` | Tapjoy offerwall SDK integration |

### 3.6 Models

| Model | Purpose |
|---|---|
| `ad_models.dart` | `AdReward`, `AdConfig`, ad event types |
| `badge_model.dart` | `Badge` data class (id, name, icon, condition) |
| `reward_config.dart` | Static reward catalogue (cost, title, description) |

### 3.7 Widgets

Reusable UI components extracted from screens:

| Widget | Purpose |
|---|---|
| `app_header.dart` | Top bar with coin balance & avatar |
| `bottom_nav.dart` | 5-tab bottom navigation bar |
| `coin_burst.dart` | Particle animation on coin earn |
| `chest_painter.dart` | Custom `CustomPainter` for chest graphics |
| `ad_loading_dialog.dart` | Full-screen ad loading indicator |
| `ad_progress_widget.dart` | Countdown / progress bar during ad |
| `ad_reward_dialog.dart` | Coin reward reveal after ad |
| `ad_reward_success_dialog.dart` | Success confirmation |
| `two_tier_reward_dialog.dart` | Base + bonus coin reveal UI |
| `lucky_bonus_dialog.dart` | Lucky multiplier announcement |
| `congratulations_dialog.dart` | Generic win celebration |
| `offline_banner.dart` | Snackbar-style offline indicator |
| `quit_confirmation_dialog.dart` | Android back-press exit dialog |
| `refreshable_scroll.dart` | Pull-to-refresh scroll wrapper |
| `game_prefs.dart` | Local storage helpers (`SharedPreferences`) |

### 3.8 Theme & Utils

- **`app_theme.dart`** — Material 3 `ThemeData`, seed color `#664DFF` (purple), Inter font, custom color extensions.
- **`reward_helper.dart`** — Pure functions for calculating coin amounts, bonus multipliers, and reward eligibility.

---

## 4. Backend Architecture (Supabase)

### 4.1 Database Schema

Five core tables in the `public` schema:

```
┌──────────────────┐       ┌─────────────────────┐
│     auth.users   │       │    public.users      │
│  (Supabase Auth) │──────►│  id (UUID, PK/FK)   │
└──────────────────┘  1:1  │  balance             │
                           │  total_earned        │
                           │  total_spent         │
                           │  games_played        │
                           │  offers_completed    │
                           │  consecutive_days    │
                           │  level               │
                           │  spin_free_spins     │
                           │  spin_cooldown_end   │
                           │  daily_reward_claimed_at │
                           │  display_name        │
                           │  profile_photo_url   │
                           └──────────┬───────────┘
                                      │ 1:N
              ┌───────────────────────┼──────────────────────┐
              │                       │                      │
  ┌───────────▼────────┐  ┌───────────▼────────┐  ┌─────────▼──────────┐
  │   transactions     │  │   game_sessions    │  │  redeemed_rewards  │
  │  id (UUID, PK)     │  │  id (UUID, PK)     │  │  id (UUID, PK)     │
  │  user_id (FK)      │  │  user_id (FK)      │  │  user_id (FK)      │
  │  amount            │  │  game_name         │  │  reward_title      │
  │  source            │  │  score             │  │  cost              │
  │  tx_id (UNIQUE)    │  │  duration_seconds  │  │  status            │
  │  reward_title      │  │  validated         │  │  tx_id (FK)        │
  │  processed_at      │  │  tx_id (FK, defer) │  └────────────────────┘
  └────────────────────┘  └────────────────────┘

  ┌──────────────────────┐
  │     game_stats       │
  │  user_id + game_name │ ← UNIQUE composite
  │  high_score          │
  │  total_plays         │
  └──────────────────────┘
```

**Key design decisions:**
- `tx_id` (idempotency key) on `transactions` has a `UNIQUE` constraint — prevents double-crediting if the client retries.
- `game_sessions.tx_id` FK is **DEFERRABLE INITIALLY DEFERRED** — allows the session and transaction to be written in the same atomic operation.
- `level` is a derived field stored denormalized for query performance: `level = (total_earned / 5000) + 1`.

### 4.2 RPC Functions

All mutations go through PostgreSQL `SECURITY DEFINER` functions. Direct table writes are blocked for `anon` and `authenticated` roles.

| Function | Caller | Description |
|---|---|---|
| `credit_user_coins(user_id, amount, source, tx_id)` | Edge Functions | Deduplicates by `tx_id`, credits balance atomically |
| `spend_user_coins(user_id, amount, reward_title)` | Edge Functions | Checks balance, deducts, records transaction |
| `claim_daily_reward(user_id)` | Edge Function | Enforces 24h cooldown, increments consecutive days |
| `process_game_session(...)` | Edge Function | Anti-cheat: daily cap check, duplicate check, credit |
| `redeem_reward(user_id, amount, reward_title)` | Edge Function | Deducts coins, creates `redeemed_rewards` record |
| `use_spin(user_id)` | Flutter client | Decrements free spins, sets 24h cooldown |
| `get_spin_state(user_id)` | Flutter client | Returns remaining spins & cooldown |
| `get_leaderboard(game_name, limit)` | Flutter client | Per-game high-score leaderboard |
| `get_weekly_leaderboard(limit)` | Flutter client | Global top earners |
| `upsert_game_stats(user_id, game_name, score)` | Edge Function | Updates high score & play count |
| `increment_user_stat(user_id, stat)` | Flutter client | Increments `games_played` or `offers_completed` |
| `get_daily_game_total(user_id, date)` | Edge Function | Queries today's validated game earnings |

### 4.3 Edge Functions

Deno-based serverless functions deployed to Supabase Edge:

| Function | Trigger | Description |
|---|---|---|
| `add-game-coins` | POST | Validates and processes a completed game session |
| `claim-chest` | POST | Handles regular chest opening & random coin reward |
| `claim-mega-chest` | POST | Handles mega chest (higher reward tier) |
| `claim-daily-reward` | POST | Delegates to `claim_daily_reward` RPC |
| `credit-coins` | POST | Generic coin crediting (ads, bonuses) |
| `spend-coins` | POST | Coin redemption flow |
| `use-spin` | POST | Delegates to `use_spin` RPC |
| `get-spin-state` | GET | Delegates to `get_spin_state` RPC |
| `get-user-stats` | GET | Returns full user profile snapshot |
| `get-offers` | GET | Returns available offerwall offers |
| `offerwall-webhook` | POST | Receives Tapjoy/PubScale completion callbacks |
| `_shared/` | — | Shared utilities (JWT verification, CORS headers) |

### 4.4 Row Level Security

All five tables have RLS enabled. The policy model:

- **Users** — `SELECT` and `UPDATE` only on own row (`auth.uid() = id`).
- **Transactions** — `SELECT` only on own transactions.
- **Game Sessions** — `SELECT` only on own sessions.
- **Game Stats** — `SELECT` on own stats + public `SELECT` for leaderboard reads.
- **Redeemed Rewards** — `SELECT` only on own records.

No client-side `INSERT` or `DELETE` is permitted — all writes go through `SECURITY DEFINER` RPCs called by Edge Functions.

### 4.5 Realtime Subscriptions

`CoinService` subscribes to the `public.users` Postgres channel via Supabase Realtime WebSocket. On each row change:
- The new `balance`, `total_earned`, `games_played`, etc. are streamed to `AppState`.
- `AppState` applies the update **only if** `_pendingCoinOps == 0` and the server balance is higher than local (prevents race conditions with optimistic updates).

---

## 5. Reward Economy

| Source | Base Amount | Daily Cap | Cooldown |
|---|---|---|---|
| Daily Reward | 100 coins | 1× per day | 24 hours |
| Game (Tap Tap, Flappy, etc.) | Score-based | 5,000 coins/day | Per session |
| Rewarded Ad | 10–50 coins | Configurable | None |
| Spin Wheel | Random (50–500) | 3 spins/day | 24h after last spin |
| Regular Chest | Random | — | None |
| Mega Chest | Higher random | — | None |
| Offerwall (Tapjoy/PubScale) | Varies per offer | — | Per offer |

**Level progression:** `level = floor(total_earned / 5000) + 1`

**First redemption milestone:** tracked client-side and persisted to Keychain when `total_earned >= 2,500`.

---

## 6. Offline & Resilience Strategy

The app is designed to work **fully offline** with eventual consistency:

```
Coin Operation (addCoins / spendCoins)
         │
         ▼
  Optimistic local update (UI responds immediately)
         │
    Online? ──No──► Enqueue to PendingTransactionService
         │                      │
        Yes                     │
         │           On reconnect: flush queue
         ▼                      │
  Call Supabase RPC ◄───────────┘
         │
    Success? ──No──► Enqueue + show error
         │
        Yes
         ▼
  Sync server balance → update UI
```

**PendingTransactionService** serializes failed operations as JSON to `SharedPreferences`. Queue types: `credit`, `spend`, `game_result`. Duplicate/idempotency errors from the server are silently discarded (no retry).

**iOS Keychain fix:** On iOS, Keychain survives app deletion but `SharedPreferences` does not. A sentinel key `app_install_id` in `SharedPreferences` detects fresh installs and clears the Keychain to prevent stale session tokens from being reused.

---

## 7. Third-Party Integrations

| SDK | Purpose | Package |
|---|---|---|
| **Supabase Flutter** | Auth, DB, Realtime, Edge Functions | `supabase_flutter ^2.12.4` |
| **Google Mobile Ads** | Rewarded ad units | `google_mobile_ads ^5.2.0` |
| **Tapjoy** | Offerwall tasks | `tapjoy_offerwall ^14.6.0` |
| **PubScale** | Secondary offerwall | `pubscale_offerwall_plugin ^0.0.4` |
| **Flame** | 2D game engine (Flappy, Tap Tap) | `flame ^1.37.0` |
| **App Tracking Transparency** | iOS ATT prompt | `app_tracking_transparency ^2.0.6` |
| **Scratcher** | Scratch-card widget | `scratcher ^2.5.0` |
| **Flutter Secure Storage** | Keychain / Keystore | `flutter_secure_storage ^10.3.0` |
| **Shared Preferences** | Lightweight local prefs | `shared_preferences ^2.5.5` |
| **Connectivity Plus** | Network detection | `connectivity_plus ^7.1.1` |
| **Google Fonts** | Typography (Inter) | `google_fonts ^6.2.1` |

---

## 8. Security Model

| Layer | Mechanism |
|---|---|
| **Authentication** | Supabase anonymous JWT — each device gets a unique UUID identity |
| **Authorization** | Row Level Security on all tables; client cannot write directly |
| **Coin mutations** | All go through `SECURITY DEFINER` RPCs — clients cannot craft arbitrary SQL |
| **Anti-cheat** | `process_game_session` validates daily cap server-side; `tx_id` deduplication prevents replay |
| **Offerwall** | Tapjoy/PubScale callbacks received by `offerwall-webhook` Edge Function (server-to-server) |
| **Secrets** | `SUPABASE_URL`, `SUPABASE_ANON_KEY` injected at build time via `--dart-define-from-file=.env` |
| **iOS Keychain** | Fresh-install detection prevents stale sessions from carrying over a previous user's balance |

---

## 9. Data Flow Diagrams

### Earning Coins via a Game

```
User plays game
      │
      ▼
GameScreen (Flame / custom)
      │  score
      ▼
GameService.submitGameResult()
      │  POST add-game-coins edge function
      ▼
Supabase Edge Function (add-game-coins)
      │  calls process_game_session() RPC
      ▼
PostgreSQL
  ├─ Daily cap check (game_sessions)
  ├─ Duplicate check (tx_id)
  ├─ INSERT game_sessions
  └─ credit_user_coins() → UPDATE users
      │  returns new balance
      ▼
AppState.syncBalanceFromServer()
      │
      ▼
UI updates (coin counter animates)
```

### Daily Reward Claim

```
User taps "Claim Daily Reward"
      │
      ▼
AppState.claimDailyReward()
      │
  Online & authenticated?
  ├─ Yes ─► RewardService.claimDailyReward()
  │              │  calls claim-daily-reward edge function
  │              ▼
  │         claim_daily_reward() RPC
  │              │  24h cooldown check
  │              │  consecutive_days update
  │              └─ UPDATE users.balance
  │              │  returns {success, amount, balance, consecutive_days}
  │              ▼
  │         AppState updates coins + streak
  │
  └─ No ──► Local fallback
                 │  writes timestamp to Keychain
                 └─ adds coins to local balance
```

### Offerwall Reward

```
User completes offer in Tapjoy/PubScale WebView
      │
      ▼ (server-to-server callback)
offerwall-webhook Edge Function
      │  validates signature
      ▼
credit_user_coins() RPC
      │
Supabase Realtime → AppState._balanceSub
      │
UI coin balance updates
```

---

## 10. Database Migrations History

| Migration | Description |
|---|---|
| `001_initial_schema.sql` | Core tables: users, transactions, game_sessions, game_stats |
| `002_security_hardening.sql` | RLS policies, REVOKE/GRANT hardening |
| `003_add_display_name.sql` | Added `display_name` column to users |
| `003_redeem_rewards.sql` | `redeemed_rewards` table + `redeem_reward` RPC |
| `004_bug_fixes.sql` | Index additions, constraint corrections |
| `004_weekly_leaderboard_and_stats.sql` | `get_weekly_leaderboard` & `get_user_stats` functions |
| `005_add_profile_photo_url.sql` | `profile_photo_url` column |
| `006_leaderboard_from_user_table.sql` | Leaderboard queries against `users.total_earned` |
| `007_fix_game_sessions_fk.sql` | Fixed deferred FK on `game_sessions.tx_id` |
| `008_add_level.sql` | `level` column, level computation logic |
| `009_adjust_reward_caps.sql` | Tuned daily game cap, spin cooldown parameters |
