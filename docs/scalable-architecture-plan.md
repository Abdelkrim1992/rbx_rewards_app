# RBX Rewards — Scalable Architecture Plan
### Optimised for 10,000+ Daily Active Users

> **Combines:** Current production architecture (ARCHITECTURE.md) + Clean Architecture target (clean-architecture.md)  
> **Goal:** A single unified plan that tells you exactly what to build, in what order, and why — so the app handles 10K+ DAU without redesign.

---

## Table of Contents

1. [The Combined Architecture Vision](#1-the-combined-architecture-vision)
2. [What to Keep vs. What to Change](#2-what-to-keep-vs-what-to-change)
3. [Final Folder Structure](#3-final-folder-structure)
4. [Layer-by-Layer Design](#4-layer-by-layer-design)
   - 4.1 [Presentation Layer — Riverpod + Optimistic UI](#41-presentation-layer--riverpod--optimistic-ui)
   - 4.2 [Application Layer — Use Cases](#42-application-layer--use-cases)
   - 4.3 [Repository Layer](#43-repository-layer)
   - 4.4 [Data Sources — Supabase, Redis, Local Cache](#44-data-sources--supabase-redis-local-cache)
5. [Backend Design for Scale](#5-backend-design-for-scale)
   - 5.1 [Cloudflare — DDoS & Rate Limiting Gateway](#51-cloudflare--ddos--rate-limiting-gateway)
   - 5.2 [Supabase Edge Functions — Unified API](#52-supabase-edge-functions--unified-api)
   - 5.3 [Upstash Redis — Hot Data Store](#53-upstash-redis--hot-data-store)
   - 5.4 [Postgres — Source of Truth](#54-postgres--source-of-truth)
   - 5.5 [Read Replica — Analytics & Leaderboards](#55-read-replica--analytics--leaderboards)
   - 5.6 [Supabase Storage — Profile Photos](#56-supabase-storage--profile-photos)
6. [Offline & Resilience Strategy](#6-offline--resilience-strategy)
7. [Security Model](#7-security-model)
8. [Scaling Thresholds & Infrastructure Tiers](#8-scaling-thresholds--infrastructure-tiers)
9. [Implementation Phases & Checklist](#9-implementation-phases--checklist)
10. [Data Flow Diagrams](#10-data-flow-diagrams)
11. [Decision Log](#11-decision-log)

---

## 1. The Combined Architecture Vision

```
┌─────────────────────────────────────────────────────────────┐
│  Flutter App  (iOS / Android)                               │
│                                                             │
│  Presentation Layer                                         │
│  ─────────────────────────────────                          │
│  Screens · Widgets · Riverpod Providers                     │
│                    ↓                                        │
│  Application Layer                                          │
│  ─────────────────────────────────                          │
│  Use Cases (pure Dart, no Flutter/Supabase imports)         │
│  ClaimDailyReward · OpenChest · SubmitGameScore             │
│  RedeemReward · UseSpin · CreditCoins                       │
│                    ↓                                        │
│  Repository Layer                                           │
│  ─────────────────────────────────                          │
│  UserRepository · RewardRepository                          │
│  GameRepository · OfferwallRepository · StorageRepository   │
│                    ↓                                        │
│  Data Sources                                               │
│  ─────────────────────────────────                          │
│  SupabaseDataSource · RedisDataSource · LocalCacheDataSource│
│  Offline Queue (Hive) · SecureStorage                       │
│                                                             │
└────────────────────────┬────────────────────────────────────┘
                         │  HTTPS only (no persistent WS)
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  Cloudflare                                                 │
│  DDoS Protection · Rate Limiting · Bot Shield · API Routing │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│  Supabase Edge Functions  (Deno, auto-scaled)               │
│                                                             │
│  claimDailyReward()    submitGameScore()                    │
│  openChest()           redeemReward()                       │
│  spinWheel()           offerwallWebhook()                   │
│  creditCoins()         getLeaderboard()                     │
└──────────────┬────────────────────────┬─────────────────────┘
               │                        │
               ▼                        ▼
┌──────────────────────┐   ┌────────────────────────────────┐
│  Upstash Redis       │   │  Supabase Postgres             │
│                      │   │  (Source of Truth)             │
│  Rate Limits         │   │                                │
│  Cooldowns (TTL)     │   │  transactions  (coin_ledger)   │
│  Leaderboard Sorted  │   │  users                         │
│  Sets                │   │  game_sessions                 │
│  Session Locks       │   │  redeemed_rewards              │
│  Temporary Cache     │   │  game_stats                    │
└──────────────────────┘   └──────────┬─────────────────────┘
                                      │  logical replication
                                      ▼
                           ┌────────────────────────────────┐
                           │  Postgres Read Replica          │
                           │  (Supabase Pro read replicas)  │
                           │  Leaderboards · Analytics       │
                           │  Stats · Reporting              │
                           └────────────────────────────────┘

                    Supabase Storage
                    ─────────────────
                    profiles/  (avatars)
```

---

## 2. What to Keep vs. What to Change

### ✅ Keep As-Is (proven, working)

| Component | Why keep |
|---|---|
| `tx_id` idempotency key on `transactions` | Prevents double-crediting under any retry scenario |
| `SECURITY DEFINER` RPCs for all writes | Clients can never craft arbitrary SQL |
| Supabase Edge Functions as mutation gateway | Already correct pattern; just add more |
| RLS on all tables | Correct, non-negotiable |
| `process_game_session` anti-cheat logic | Daily cap + duplicate check is solid |
| Deferred FK on `game_sessions.tx_id` | Allows atomic session + transaction writes |
| Offline queue (`PendingTransactionService`) | Critical for coin integrity, keep the logic |
| iOS Keychain sentinel detection | Prevents stale session reuse after reinstall |
| Flame engine for mini-games | No change needed |
| Optimistic UI pattern in `AppState` | Keep the pattern, migrate to Riverpod |

### ❌ Remove / Replace

| Component | Problem | Replacement |
|---|---|---|
| `Provider` + `ChangeNotifier` (`AppState`, `AdState`) | Monolithic — hard to test, hard to scale features | **Riverpod** `AsyncNotifier` / `Notifier` |
| Flat `services/` layer | Business logic mixed with I/O; services duplicated JWT retry | **Use Cases** + **Repositories** + **DataSources** |
| Supabase Realtime WebSocket (always-on) | N concurrent WS connections = hard scaling ceiling | **Event-driven polling** after mutations |
| Direct RPC calls from client (`use_spin`, `get_leaderboard`, `increment_user_stat`) | Bypasses Edge Function gateway; harder to rate-limit | **All mutations via Edge Functions only** |
| Postgres for cooldowns & leaderboards | Locks rows under concurrent load; full scans for rankings | **Upstash Redis** TTL keys + Sorted Sets |
| `SharedPreferences` for offline queue | Not crash-safe for binary/complex data | **Hive** (typed, crash-safe box) |
| No CDN / DDoS protection | Open to bots, offerwall abuse, replay attacks | **Cloudflare** proxy in front of Edge Functions |

---

## 3. Final Folder Structure

```
lib/
├── core/
│   ├── constants/
│   │   └── app_constants.dart          # coin caps, cooldowns, level formula, ad limits
│   ├── errors/
│   │   ├── failure.dart                # sealed class: NetworkFailure | AuthFailure | ServerFailure | CacheFailure
│   │   └── exceptions.dart
│   └── utils/
│       ├── uuid_generator.dart         # extracted from AppState._generateUuidV4()
│       └── jwt_retry.dart              # extracted from CoinService + GameService (was duplicated)
│
├── domain/                             ← PURE DART — zero Flutter/Supabase imports
│   ├── entities/
│   │   ├── user_profile.dart
│   │   ├── coin_transaction.dart
│   │   ├── game_session.dart
│   │   ├── spin_state.dart
│   │   ├── leaderboard_entry.dart
│   │   ├── chest_result.dart
│   │   └── badge.dart
│   ├── repositories/                   # abstract interfaces only
│   │   ├── i_auth_repository.dart
│   │   ├── i_user_repository.dart
│   │   ├── i_coin_repository.dart
│   │   ├── i_game_repository.dart
│   │   ├── i_reward_repository.dart
│   │   ├── i_offerwall_repository.dart
│   │   └── i_storage_repository.dart
│   └── use_cases/
│       ├── auth/
│       │   └── sign_in_anonymously.dart
│       ├── coins/
│       │   ├── credit_coins.dart
│       │   ├── spend_coins.dart
│       │   └── get_balance.dart
│       ├── rewards/
│       │   ├── claim_daily_reward.dart
│       │   ├── open_chest.dart
│       │   ├── open_mega_chest.dart
│       │   └── redeem_reward.dart
│       ├── spin/
│       │   ├── use_spin.dart
│       │   └── get_spin_state.dart
│       ├── games/
│       │   ├── submit_game_result.dart
│       │   └── get_leaderboard.dart
│       └── profile/
│           ├── update_display_name.dart
│           └── update_profile_photo.dart
│
├── data/                               ← replaces lib/services/
│   ├── datasources/
│   │   ├── supabase_datasource.dart    # all Edge Function calls
│   │   ├── redis_datasource.dart       # cooldown reads (optional fast-path)
│   │   └── local_datasource.dart       # Hive offline queue + SecureStorage + prefs
│   └── repositories/
│       ├── auth_repository_impl.dart
│       ├── user_repository_impl.dart
│       ├── coin_repository_impl.dart
│       ├── game_repository_impl.dart
│       ├── reward_repository_impl.dart
│       ├── offerwall_repository_impl.dart
│       └── storage_repository_impl.dart
│
├── presentation/                       ← replaces lib/state/
│   ├── providers/
│   │   ├── auth_provider.dart          # authProvider (FutureProvider)
│   │   ├── user_provider.dart          # userProfileProvider (FutureProvider, refreshed after mutations)
│   │   ├── coin_provider.dart          # coinBalanceProvider, derived from userProfileProvider
│   │   ├── spin_provider.dart          # spinStateProvider (FutureProvider)
│   │   ├── ad_provider.dart            # adNotifierProvider (AsyncNotifier)
│   │   └── connectivity_provider.dart  # connectivityProvider (StreamProvider)
│   └── screens/                        # same 16 screens — consume ref.watch() only
│
├── widgets/                            # unchanged (15 widgets)
├── theme/                              # unchanged (app_theme.dart)
└── main.dart                           # ProviderScope root; no MultiProvider

supabase/
├── schema.sql
├── migrations/
│   ├── 001–009 (existing)
│   ├── 010_performance_indexes.sql     # NEW: idx_users_total_earned
│   ├── 011_revoke_client_rpcs.sql      # NEW: remove direct client RPC grants
│   └── 012_storage_bucket_rls.sql      # NEW: profile photo bucket policies
└── functions/
    ├── _shared/                        # JWT verify, CORS, Redis client, rate-limit helper
    ├── add-game-coins/                 # + Redis daily cap check
    ├── claim-chest/
    ├── claim-mega-chest/
    ├── claim-daily-reward/             # + Redis cooldown via TTL key
    ├── credit-coins/                   # + Redis rate limit
    ├── spend-coins/
    ├── use-spin/                       # + Redis cooldown via TTL key
    ├── get-spin-state/                 # reads Redis first, falls back to Postgres
    ├── get-user-stats/
    ├── get-leaderboard/                # NEW: reads Redis Sorted Set
    ├── get-offers/
    └── offerwall-webhook/              # + Redis signature dedup
```

---

## 4. Layer-by-Layer Design

### 4.1 Presentation Layer — Riverpod + Optimistic UI

**State management:** `flutter_riverpod ^2.6.1`

Replace the monolithic `AppState` with focused, composable providers:

```dart
// User profile — refreshed after every mutation (no persistent WS)
final userProfileProvider = FutureProvider.autoDispose<UserProfile>((ref) async {
  final repo = ref.watch(userRepositoryProvider);
  return repo.fetchProfile();
});

// Derived providers — zero extra network calls
final coinBalanceProvider = Provider<int>((ref) =>
  ref.watch(userProfileProvider).value?.coins ?? 0);

final userLevelProvider = Provider<int>((ref) =>
  ref.watch(userProfileProvider).value?.level ?? 1);

// Spin state — separate lifecycle from user profile
final spinStateProvider = FutureProvider<SpinState>((ref) async {
  final repo = ref.watch(spinRepositoryProvider);
  return repo.getSpinState();
});
```

**Optimistic updates — keep the pattern, move the implementation:**

```dart
// In a use case, the Riverpod notifier does optimistic update:
Future<void> creditCoins(int amount, String source) async {
  // 1. Update local state immediately (optimistic)
  state = AsyncData(state.value!.copyWith(coins: state.value!.coins + amount));

  // 2. Call use case (goes to Edge Function)
  final result = await _creditCoinsUseCase(amount: amount, source: source);

  // 3. Reconcile with server response
  state = AsyncData(state.value!.copyWith(coins: result.newBalance));
}
```

**Navigation:** Keep the existing `AppNavigator` imperative model — it works and adds no overhead.

---

### 4.2 Application Layer — Use Cases

Each use case is a single-responsibility callable class with **zero Flutter or Supabase imports**. This makes every use case fully unit-testable without mocks.

```dart
// domain/use_cases/rewards/claim_daily_reward.dart
class ClaimDailyReward {
  final IRewardRepository _rewards;
  final ICoinRepository _coins;
  const ClaimDailyReward(this._rewards, this._coins);

  Future<ClaimResult> call() async {
    // 1. Guard: is cooldown active? (reads from Redis via repo)
    final cooldown = await _rewards.getDailyRewardCooldown();
    if (cooldown > Duration.zero) {
      return ClaimResult.onCooldown(remaining: cooldown);
    }
    // 2. Call backend
    final result = await _rewards.claimDailyReward();
    return result;
  }
}
```

**Full use case inventory:**

| Use Case | Replaces (current code) |
|---|---|
| `SignInAnonymously` | `AuthService.signInAnonymously()` |
| `CreditCoins` | `AppState.addCoins()` + `CoinService.creditCoins()` |
| `SpendCoins` | `AppState.spendCoins()` + `CoinService.spendCoins()` |
| `ClaimDailyReward` | `AppState.claimDailyReward()` + `RewardService.claimDailyReward()` |
| `UseSpin` | `AppState.useSpin()` + `CoinService.useSpin()` |
| `GetSpinState` | `AppState._refreshSpinState()` + `CoinService.getSpinState()` |
| `OpenChest` | chest logic scattered in `chest_screen.dart` |
| `OpenMegaChest` | mega chest logic in `chest_screen.dart` |
| `SubmitGameResult` | `GameService.submitGameResult()` |
| `GetLeaderboard` | `GameService.getLeaderboard()` → now reads Redis |
| `RedeemReward` | `AppState.spendCoins()` with reward context |
| `UpdateDisplayName` | `AppState.updateDisplayName()` + `CoinService.updateDisplayName()` |
| `UpdateProfilePhoto` | `AppState.updateProfilePhoto()` → now uploads to Supabase Storage |
| `FlushPendingQueue` | `AppState._flushPendingTransactions()` |

---

### 4.3 Repository Layer

Abstractions that decouple use cases from infrastructure. Each has an interface in `domain/` and an implementation in `data/`.

```dart
// domain/repositories/i_coin_repository.dart
abstract interface class ICoinRepository {
  Future<int>  creditCoins(int amount, {required String source, required String txId});
  Future<int>  spendCoins(int amount, {required String rewardTitle, required String txId});
  Future<int>  getBalance();
  Future<void> enqueuePending(Map<String, dynamic> tx);   // offline queue
  Future<void> flushPendingQueue();
}

// domain/repositories/i_reward_repository.dart
abstract interface class IRewardRepository {
  Future<Duration>     getDailyRewardCooldown();
  Future<ClaimResult>  claimDailyReward();
  Future<ChestResult>  openChest();
  Future<ChestResult>  openMegaChest();
  Future<bool>         redeemReward(int cost, String title, String txId);
  Future<List<RedeemedReward>> getRedemptionHistory();
}
```

The implementation chooses **which data source to call** and handles the offline fallback:

```dart
// data/repositories/coin_repository_impl.dart
class CoinRepositoryImpl implements ICoinRepository {
  final SupabaseDataSource _remote;
  final LocalDataSource _local;

  @override
  Future<int> creditCoins(int amount, {required String source, required String txId}) async {
    if (!await _local.isOnline()) {
      await _local.enqueuePending({'type': 'credit', 'amount': amount, 'source': source, 'txId': txId});
      return _local.getCachedBalance() + amount;   // optimistic local
    }
    try {
      final balance = await _remote.creditCoinsViaEdge(amount, source, txId);
      await _local.saveBalance(balance);
      return balance;
    } catch (e) {
      await _local.enqueuePending({'type': 'credit', 'amount': amount, 'source': source, 'txId': txId});
      rethrow;
    }
  }
}
```

---

### 4.4 Data Sources — Supabase, Redis, Local Cache

#### `SupabaseDataSource` — Edge Function calls only

All calls go to Edge Functions. No direct Postgres queries or RPC calls from the client.

```dart
class SupabaseDataSource {
  final SupabaseClient _client;

  Future<int> creditCoinsViaEdge(int amount, String source, String txId) async {
    return _retryOnJwtFuture(() async {
      final resp = await _client.functions.invoke('credit-coins',
        body: {'amount': amount, 'source': source, 'txId': txId});
      if (resp.status != 200) throw ServerException(resp.data['error']);
      return resp.data['balance'] as int;
    });
  }

  Future<List<Map<String,dynamic>>> getLeaderboard(String gameName) async {
    final resp = await _client.functions.invoke('get-leaderboard',
      body: {'gameName': gameName, 'limit': 50});
    return List<Map<String,dynamic>>.from(resp.data['entries']);
  }
  // ... all other edge function wrappers
}
```

**JWT retry** lives once in `core/utils/jwt_retry.dart` — injected into `SupabaseDataSource` (removes the current duplication between `CoinService` and `GameService`).

#### `LocalDataSource` — Hive offline queue + SecureStorage

Replace `SharedPreferences` JSON queue with **Hive** for crash-safe typed storage:

```dart
class LocalDataSource {
  late Box<Map> _pendingBox;

  Future<void> init() async {
    await Hive.initFlutter();
    _pendingBox = await Hive.openBox<Map>('pending_txs');
  }

  Future<void> enqueuePending(Map<String,dynamic> tx) async {
    await _pendingBox.add(tx);
  }

  Future<List<Map<String,dynamic>>> getPendingQueue() async {
    return _pendingBox.values.cast<Map<String,dynamic>>().toList();
  }

  // SecureStorage: balance, install sentinel, spin cooldown
  Future<int>  getCachedBalance()      => _secureStorage.readInt('balance');
  Future<void> saveBalance(int v)      => _secureStorage.writeInt('balance', v);
  Future<bool> isOnline()              => Connectivity().checkConnectivity()
      .then((r) => r.any((c) => c != ConnectivityResult.none));
}
```

---

## 5. Backend Design for Scale

### 5.1 Cloudflare — DDoS & Rate Limiting Gateway

Place Cloudflare in front of Supabase Edge Functions to handle:

| Cloudflare Feature | What it protects |
|---|---|
| **DDoS protection** | Absorbs traffic spikes before they hit Edge Functions |
| **Rate limiting rules** | e.g. max 10 requests/minute per IP to `credit-coins` |
| **Bot Fight Mode** | Blocks automated reward farming bots |
| **API routing** | Route `offerwall-webhook` to a dedicated worker for signature validation before forwarding |
| **Cache** | Cache `get-leaderboard` responses for 30 seconds at the CDN edge |

**Setup:** Point your Supabase Edge Function domain through a Cloudflare proxy (orange-cloud). Add a Page Rule or Rate Limiting rule per endpoint.

> The Flutter app continues to call the same `SUPABASE_URL` — Cloudflare is transparent to the client.

---

### 5.2 Supabase Edge Functions — Unified API

**Rule: every mutation from the Flutter client must go through an Edge Function.**  
No direct Postgres RPC or table writes from the client. This gives you a single chokepoint for rate limiting, validation, and Redis writes.

#### Edge Function inventory (final state)

| Function | Method | Redis op | Postgres op |
|---|---|---|---|
| `claim-daily-reward` | POST | Check + SET `cooldown:daily:{uid}` (24h TTL) | `claim_daily_reward()` RPC |
| `open-chest` | POST | — | `credit_user_coins()` RPC |
| `open-mega-chest` | POST | — | `credit_user_coins()` RPC |
| `spin-wheel` | POST | Check + SET `cooldown:spin:{uid}` (24h TTL) | `use_spin()` RPC |
| `get-spin-state` | GET | GET `cooldown:spin:{uid}` TTL | Fallback to `get_spin_state()` RPC |
| `add-game-coins` | POST | INCR `cap:game:{uid}:{date}` (check ≤ 5000) | `process_game_session()` RPC |
| `credit-coins` | POST | INCR `ratelimit:credit:{uid}` (60/hour) | `credit_user_coins()` RPC |
| `spend-coins` | POST | — | `redeem_reward()` RPC |
| `get-user-stats` | GET | — | `SELECT * FROM users WHERE id = uid` |
| `get-leaderboard` | GET | ZREVRANGE `leaderboard:{game}` (cached) | Fallback if Redis miss |
| `get-offers` | GET | — | Static config / Tapjoy API |
| `offerwall-webhook` | POST | SET `webhook:dedup:{txId}` (NX, 24h TTL) | `credit_user_coins()` RPC |

#### Shared utilities in `_shared/`

```typescript
// _shared/redis.ts
export const redis = new Redis({
  url: Deno.env.get('UPSTASH_REDIS_REST_URL')!,
  token: Deno.env.get('UPSTASH_REDIS_REST_TOKEN')!,
});

// _shared/rate_limit.ts
export async function checkRateLimit(key: string, max: number, windowSec: number) {
  const count = await redis.incr(key);
  if (count === 1) await redis.expire(key, windowSec);
  if (count > max) throw new Error('Rate limit exceeded');
}

// _shared/auth.ts — JWT verification (already exists, keep)
// _shared/cors.ts — CORS headers (already exists, keep)
```

---

### 5.3 Upstash Redis — Hot Data Store

**Why Redis for these specific jobs:**

| Job | Redis Structure | vs. Postgres |
|---|---|---|
| Daily reward cooldown | `SET cooldown:daily:{uid} 1 EX 86400` | No row lock needed; TTL is native |
| Spin cooldown | `SET cooldown:spin:{uid} 1 EX 86400` | Same — atomic, O(1) |
| Game daily cap | `INCR cap:game:{uid}:{date}` + `EXPIRE` | No `SUM()` query on transactions |
| Leaderboard top 50 | `ZADD leaderboard:weekly {score} {uid}` / `ZREVRANGE` | O(log N) vs full table scan |
| Ad rate limit | `INCR ratelimit:ad:{uid}` windowed | No Postgres row needed |
| Offerwall dedup | `SET webhook:dedup:{txId} 1 NX EX 86400` | Atomic check-and-set |
| Session lock | `SET session:lock:{sessionId} 1 NX EX 30` | Prevents double-submit |

**Leaderboard update flow:**
```typescript
// Inside credit-coins edge function, after crediting Postgres:
const newTotal = user.total_earned + amount;
await redis.zadd('leaderboard:weekly', { score: newTotal, member: userId });

// Inside get-leaderboard edge function:
const entries = await redis.zrevrangeWithScores('leaderboard:weekly', 0, 49);
```

**Upstash plan:** Free tier handles 10K req/day. At 10K DAU (~50K req/day) use **Pay-as-you-go** (~$0.2/100K commands). At 100K DAU use **Pro** ($280/month, 10M commands included).

---

### 5.4 Postgres — Source of Truth

Postgres stays the authoritative ledger. No data is ever lost if Redis is cleared.

**New index required (add in migration `010`):**
```sql
-- Required for get_weekly_leaderboard fallback query
CREATE INDEX IF NOT EXISTS idx_users_total_earned
  ON public.users(total_earned DESC);

-- Partial index for active users (improves leaderboard query further)
CREATE INDEX IF NOT EXISTS idx_users_active_total_earned
  ON public.users(total_earned DESC)
  WHERE total_earned > 0;
```

**Remove from client direct access (migration `011`):**
```sql
-- All of these are now called only from Edge Functions
REVOKE EXECUTE ON FUNCTION public.use_spin(UUID)              FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.get_spin_state(UUID)        FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.increment_user_stat(UUID, TEXT) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.get_leaderboard(TEXT, INTEGER) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.get_weekly_leaderboard(INTEGER) FROM authenticated;
```

**Remove cooldown columns from `users` (optional, keep for audit trail):**  
Once Redis is the cooldown source, `users.spin_cooldown_end` and `users.daily_reward_claimed_at` become backup audit fields only — they don't need to be checked on every request.

---

### 5.5 Read Replica — Analytics & Leaderboards

Supabase Pro and above supports **read replicas** (logical replication to a read-only Postgres instance).

Use the read replica for:
- Historical leaderboard queries (full game stats)
- Analytics dashboards
- Long-running `SELECT` queries that would block the primary

The Flutter app **never queries the read replica directly** — Edge Functions decide which database to use internally.

```typescript
// get-leaderboard edge function decision tree:
// 1. Check Redis ZADD sorted set → return instantly if populated
// 2. Miss → query read replica (not primary) → populate Redis → return
```

---

### 5.6 Supabase Storage — Profile Photos

Replace storing external URLs with actual file uploads.

**Bucket config:**
- Name: `profiles`
- Public: yes (avatars are public)
- Max size: 2 MB
- Allowed MIME: `image/jpeg`, `image/png`, `image/webp`

**RLS (migration `012`):**
```sql
-- Users can upload/replace only their own avatar
CREATE POLICY "upload own avatar" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'profiles' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );

-- Anyone can read avatars (public CDN)
CREATE POLICY "public read avatars" ON storage.objects
  FOR SELECT USING (bucket_id = 'profiles');
```

**`UpdateProfilePhoto` use case flow:**
```
User picks image → compress to <500 KB
→ StorageRepositoryImpl.upload(bytes, userId)
→ Supabase Storage PUT profiles/{userId}/avatar.jpg
→ get public URL
→ UserRepositoryImpl.updateProfilePhotoUrl(url)
→ PATCH users SET profile_photo_url = url
→ invalidate userProfileProvider → UI refreshes
```

---

## 6. Offline & Resilience Strategy

### Hive-based Offline Queue (replaces SharedPreferences)

```dart
// Crash-safe: Hive writes are atomic and survive process kill
await _local.enqueuePending({
  'type': 'credit',
  'amount': 50,
  'source': 'game',
  'txId': uuid,
  'timestamp': DateTime.now().millisecondsSinceEpoch,
});
```

### Flush on Reconnect

`ConnectivityService` (now a Riverpod `StreamProvider`) triggers `FlushPendingQueue` use case on network recovery:

```dart
// In app bootstrap or connectivity listener:
ref.listen(connectivityProvider, (prev, next) {
  if (next == ConnectivityStatus.online) {
    ref.read(flushPendingQueueProvider.notifier).flush();
  }
});
```

### Idempotency on Flush

Every queued transaction carries a `txId`. The `credit_user_coins()` RPC's `UNIQUE` constraint on `transactions.tx_id` means duplicate flushes are silently ignored by the server — the same transaction will never be credited twice.

### Optimistic UI Rules

1. Update local state immediately on user action.
2. Increment `_pendingOps` counter to block Realtime/polling from overwriting.
3. Call use case → Edge Function.
4. On success: reconcile server balance.
5. On failure: enqueue to offline queue, show non-blocking error toast.

---

## 7. Security Model

| Layer | Mechanism | Status |
|---|---|---|
| **DDoS / Bots** | Cloudflare proxy, Bot Fight Mode, per-endpoint rate limits | **NEW** |
| **API rate limiting** | Cloudflare rules + Redis `INCR` inside Edge Functions | **NEW** |
| **Authentication** | Supabase anonymous JWT (unchanged) | existing |
| **Authorization** | RLS on all tables (unchanged) | existing |
| **Coin mutations** | All via `SECURITY DEFINER` RPCs (unchanged) | existing |
| **Anti-cheat** | `process_game_session` daily cap + `tx_id` dedup | existing |
| **Offerwall dedup** | Redis NX key `webhook:dedup:{txId}` (24h TTL) | **NEW** |
| **Cooldown bypass** | Cooldowns enforced in Edge Function via Redis — client cannot skip | **NEW** |
| **Direct RPC bypass** | `REVOKE` remaining client-accessible RPCs (migration 011) | **NEW** |
| **Storage** | Supabase Storage RLS — users can only write their own folder | **NEW** |
| **iOS Keychain** | Fresh-install detection (unchanged) | existing |
| **Secrets** | `.env` via `--dart-define-from-file` (unchanged) | existing |

---

## 8. Scaling Thresholds & Infrastructure Tiers

| DAU | Supabase Plan | Redis Plan | Cloudflare | Est. Monthly Cost |
|---|---|---|---|---|
| 0–2K | Free | Free (10K req/day) | Free | $0 |
| 2K–10K | **Pro** ($25) | Pay-as-you-go (~$5) | Free | ~$30 |
| 10K–50K | Pro ($25) + Add-ons | Pay-as-you-go (~$25) | Pro ($20) | ~$70 |
| 50K–200K | **Team** ($599) | Pro ($280) | Pro ($20) | ~$900 |
| 200K+ | Enterprise | Enterprise | Enterprise | Custom |

**Bottleneck order at scale:**
1. ~~Realtime WebSocket connections~~ → **fixed** (removed persistent WS)
2. ~~Leaderboard full table scan~~ → **fixed** (Redis Sorted Sets)
3. ~~Cooldown row locks~~ → **fixed** (Redis TTL keys)
4. Edge Function cold starts → mitigated by Cloudflare cache on GET endpoints
5. Postgres connection pool → mitigated by PgBouncer (built into Supabase Pro)

---

## 9. Implementation Phases & Checklist

### Phase 0 — Foundation (no behaviour change)

- [ ] Add `flutter_riverpod: ^2.6.1` and `hive_flutter: ^1.1.0` to `pubspec.yaml`
- [ ] Wrap app root in `ProviderScope` (inside existing `MultiProvider` temporarily)
- [ ] Create folder skeleton: `core/`, `domain/`, `data/`, `presentation/providers/`
- [ ] Extract `uuid_generator.dart` and `jwt_retry.dart` into `core/utils/`
- [ ] Run existing app — must be identical to before

### Phase 1 — Domain Layer

- [ ] Define 7 entities (replace `Map<String,dynamic>` passing)
- [ ] Define 7 repository interfaces (`i_*.dart`)
- [ ] Implement all 14 use cases
- [ ] Write unit tests for every use case (pure Dart, no mocks)

### Phase 2 — Data Layer

- [ ] Implement `SupabaseDataSource` (consolidate `CoinService`, `GameService`, `RewardService`)
- [ ] Implement `LocalDataSource` with **Hive** offline queue (replace `SharedPreferences` JSON)
- [ ] Implement all 7 repository classes with offline fallback logic
- [ ] Implement `StorageRepositoryImpl` for profile photo uploads
- [ ] Integration tests against Supabase local development

### Phase 3 — Redis Integration

- [ ] Create Upstash Redis database (free tier)
- [ ] Add `UPSTASH_REDIS_REST_URL` and `UPSTASH_REDIS_REST_TOKEN` to Supabase Edge Function secrets
- [ ] Add Redis client to `_shared/redis.ts`
- [ ] Add `_shared/rate_limit.ts` helper
- [ ] Update `claim-daily-reward`: Redis cooldown check + SET
- [ ] Update `spin-wheel` / `use-spin`: Redis cooldown check + SET
- [ ] Update `add-game-coins`: Redis daily cap INCR
- [ ] Update `credit-coins`: Redis rate limit INCR
- [ ] Update `offerwall-webhook`: Redis dedup NX key
- [ ] New `get-leaderboard` Edge Function: reads Redis Sorted Set
- [ ] Update `credit-coins` and `add-game-coins` to ZADD leaderboard after Postgres credit
- [ ] **Migration 010**: add `idx_users_total_earned` and `idx_users_active_total_earned`

### Phase 4 — Riverpod Migration (screen by screen)

- [ ] Add repository providers and use case providers
- [ ] Replace `AppState` with `userProfileProvider` + `coinBalanceProvider`
- [ ] Replace `AdState` with `AdNotifier` (`AsyncNotifier`)
- [ ] Replace `ConnectivityService` with `connectivityProvider` (`StreamProvider`)
- [ ] Migrate `HomeScreen` → `ref.watch(coinBalanceProvider)` etc.
- [ ] Migrate `GamesScreen`
- [ ] Migrate `OffersScreen`
- [ ] Migrate `RewardsScreen`
- [ ] Migrate `ProfileScreen`
- [ ] Migrate `SpinScreen`
- [ ] Migrate `ChestScreen`
- [ ] Migrate remaining screens (earn, leaderboard, loading, onboarding, mini-games)
- [ ] Remove `provider` package from `pubspec.yaml`
- [ ] Delete `lib/state/` and `lib/services/`

### Phase 5 — Edge Function Hardening

- [ ] Wrap `use_spin` in `spin-wheel` Edge Function (already partially exists as `use-spin`)
- [ ] Ensure `get-spin-state` reads Redis first
- [ ] Move `increment_user_stat` call inside `add-game-coins` Edge Function
- [ ] **Migration 011**: REVOKE client RPC grants for `use_spin`, `get_spin_state`, `increment_user_stat`, `get_leaderboard`, `get_weekly_leaderboard`

### Phase 6 — Cloudflare & Storage

- [ ] Enable Cloudflare proxy on Supabase Edge Function domain
- [ ] Add rate limiting rules: `credit-coins` ≤ 60/min per IP, `claim-daily-reward` ≤ 5/min per IP
- [ ] Enable Bot Fight Mode
- [ ] Cache `get-leaderboard` at Cloudflare edge for 30 seconds
- [ ] Create `profiles` Supabase Storage bucket
- [ ] **Migration 012**: Storage RLS policies
- [ ] Implement `StorageRepositoryImpl.uploadProfilePhoto()`
- [ ] Update `ProfileScreen` to pick local file → upload → refresh

### Phase 7 — Read Replica (optional, >50K DAU)

- [ ] Enable read replica in Supabase Team plan
- [ ] Route `get-leaderboard` fallback queries to read replica connection string
- [ ] Route analytics/reporting queries to read replica

---

## 10. Data Flow Diagrams

### Game Coin Earn (target state)

```
User completes game
      │
      ▼
GameScreen (Flame)
      │  score, sessionId
      ▼
SubmitGameResult use case
      │  calls SupabaseDataSource.submitGameSession()
      ▼
Cloudflare  →  add-game-coins Edge Function
      │
      ├─► Redis: INCR cap:game:{uid}:{date}
      │       If > 5,000 → return cap_reached
      │
      ├─► Redis: SET session:lock:{sessionId} NX EX 30
      │       If exists → return duplicate
      │
      └─► Postgres: process_game_session() RPC
              │  Daily cap check (game_sessions)
              │  INSERT game_sessions
              │  credit_user_coins() → UPDATE users
              │  returns {success, balance, dailyTotal}
              │
      ◄── Edge Function response: {success, balance, credited}
      │
      ├─► Redis: ZADD leaderboard:{game} {score} {uid}
      │
      ▼
CoinRepositoryImpl.syncBalance(newBalance)
      │  saves to Hive cache
      ▼
userProfileProvider.refresh()  ← invalidated
      │
      ▼
UI: coin counter animates, score shown
```

### Daily Reward Claim (target state)

```
User taps "Claim"
      │
      ▼
ClaimDailyReward use case
      │  checks offline queue first
      ▼
Online?
  ├─ No ──► LocalDataSource: +100 coins (optimistic)
  │          enqueue {type: credit, source: daily_reward}
  │          show offline indicator
  │
  └─ Yes ─► Cloudflare → claim-daily-reward Edge Function
                │
                ├─► Redis: GET cooldown:daily:{uid}
                │       If exists → return {success: false, remaining: TTL}
                │
                └─► Postgres: claim_daily_reward() RPC
                        │  consecutive_days update
                        │  UPDATE users.balance
                        │  returns {success, amount, balance, consecutive_days}
                        │
                ◄── response
                │
                └─► Redis: SET cooldown:daily:{uid} 1 EX 86400
                │
      ▼
CoinRepositoryImpl.syncBalance()
      ▼
userProfileProvider.refresh()
      ▼
UI: reward dialog + coin burst animation
```

### Offerwall Webhook (target state, server-to-server)

```
Tapjoy / PubScale server
      │  POST offerwall-webhook (HMAC signed)
      ▼
Cloudflare: validates IP allowlist (Tapjoy CIDRs)
      │
      ▼
offerwall-webhook Edge Function
      │
      ├─► Verify HMAC signature (existing logic)
      │
      ├─► Redis: SET webhook:dedup:{txId} 1 NX EX 86400
      │       If NX fails → already processed → return 200 (idempotent)
      │
      └─► Postgres: credit_user_coins() RPC
              │
              ▼
      Response 200 to Tapjoy/PubScale

      [Flutter client polls after returning to foreground]
      userProfileProvider.refresh() → UI shows new balance
```

---

## 11. Decision Log

| Decision | Rationale |
|---|---|
| **Riverpod over Provider** | Better composability, auto-dispose, no `BuildContext` dependency for business logic, simpler testing |
| **Event-driven polling over Realtime WS** | Eliminates the concurrent WebSocket connection ceiling (biggest scaling risk at 10K DAU) |
| **Redis for cooldowns over Postgres TTL** | Native TTL, O(1) reads, no row locks, survives high concurrency |
| **Redis Sorted Sets for leaderboard** | O(log N) insertion, O(M) range query — no full table scan at any scale |
| **Hive over SharedPreferences for queue** | Crash-safe, typed, no JSON serialization bugs |
| **Cloudflare in front of Edge Functions** | DDoS absorption, per-endpoint rate limits, bot protection, CDN caching — all without code changes to the app |
| **Edge Functions as the only mutation gateway** | Single chokepoint: Redis writes, rate limiting, and logging all happen in one place |
| **REVOKE remaining client RPCs** | Closes the bypass path where the client could skip Edge Function validation |
| **Supabase Storage for avatars** | Proper access control, CDN delivery, no dependency on external URLs |
| **Read replica for analytics** | Offloads long-running analytics queries from the primary — keeps OLTP latency low |
| **Keep `tx_id` idempotency** | Non-negotiable — coin double-crediting is the most catastrophic failure mode |
| **Keep offline queue** | Non-negotiable — coin integrity under poor network conditions |
