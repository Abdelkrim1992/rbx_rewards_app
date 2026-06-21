# RBX Rewards — Full Architecture Plan
### 3-Layer Architecture + System Design · Customised for This App

> This document fuses the **3-layer architecture** (Presentation → Business → Data) with the
> **system design** (Flutter → Cloudflare → Edge Functions → Redis + Postgres → Read Replica)
> into one complete, file-specific implementation guide for the **existing RBX Rewards codebase**.

---

## Part 1 — The Combined Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│  FLUTTER APP  (iOS / Android)                                    │
│                                                                  │
│  ┌─────────────────────── LAYER 1: PRESENTATION ─────────────┐  │
│  │  Screens (16)  ·  Widgets (15)  ·  Riverpod Providers     │  │
│  │  Optimistic UI  ·  AnimatedSwitcher nav  ·  Flame games   │  │
│  └───────────────────────────┬────────────────────────────────┘  │
│                              │ calls services                    │
│  ┌─────────────────────── LAYER 2: BUSINESS ─────────────────┐  │
│  │  Services (one per domain)                                 │  │
│  │  CoinService · RewardService · GameService                 │  │
│  │  AdService · SpinService · ChestService                    │  │
│  │  OfferwallService · ProfileService                         │  │
│  └───────────────────────────┬────────────────────────────────┘  │
│                              │ reads / writes via                │
│  ┌─────────────────────── LAYER 3: DATA ─────────────────────┐  │
│  │  Repositories (one per aggregate)                          │  │
│  │  SupabaseRepository · HiveRepository · SecureRepository    │  │
│  │  Offline Queue (Hive)  ·  Local Cache (SecureStorage)      │  │
│  └───────────────────────────┬────────────────────────────────┘  │
└─────────────────────────────-┼───────────────────────────────────┘
                               │ HTTPS only
                               ▼
┌──────────────────────────────────────────────────────────────────┐
│  CLOUDFLARE                                                      │
│  DDoS Protection · Rate Limiting · Bot Shield · API Routing      │
│  CDN cache for GET endpoints (leaderboard, offers)               │
└──────────────────────────────┬───────────────────────────────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────────┐
│  SUPABASE EDGE FUNCTIONS  (Deno · auto-scaled)                   │
│                                                                  │
│  claimDailyReward()     submitGameScore()                        │
│  openChest()            openMegaChest()                          │
│  spinWheel()            redeemReward()                           │
│  creditCoins()          offerwallWebhook()                       │
│  getLeaderboard()       getUserStats()                           │
└──────────────┬────────────────────────┬─────────────────────────┘
               │                        │
               ▼                        ▼
┌──────────────────────┐   ┌────────────────────────────────────┐
│  Upstash Redis       │   │  Supabase Postgres                 │
│                      │   │  (Source of Truth)                 │
│  Rate Limits         │   │                                    │
│  Cooldowns (TTL)     │   │  users  ·  transactions            │
│  Leaderboard Sorted  │   │  game_sessions  ·  game_stats      │
│  Sets                │   │  redeemed_rewards                  │
│  Session Locks       │   │                                    │
│  Offerwall Dedup     │   │  RLS · SECURITY DEFINER RPCs       │
└──────────────────────┘   └──────────────┬─────────────────────┘
                                          │ logical replication
                                          ▼
                           ┌────────────────────────────────────┐
                           │  Postgres Read Replica             │
                           │  Leaderboards · Analytics · Stats  │
                           └────────────────────────────────────┘

                      Supabase Storage
                      ──────────────────
                      profiles/  (avatars, public CDN)
```

---

## Part 2 — Layer Breakdown (Mapped to Current Files)

---

### Layer 1 — Presentation
**Technology: Flutter + Riverpod**

This layer only renders UI and calls services. It never touches Supabase, Redis, or Hive directly.

#### Current state → target state

| Current | Target | Change |
|---|---|---|
| `lib/state/app_state.dart` (`ChangeNotifier`) | Riverpod `Notifier` / `AsyncNotifier` providers | Replace |
| `lib/state/ad_state.dart` (`ChangeNotifier`) | Riverpod `AsyncNotifier` `AdNotifier` | Replace |
| `context.watch<AppState>()` in screens | `ref.watch(coinProvider)` etc. | Replace |
| `context.read<AppState>().addCoins()` | `ref.read(coinService).creditCoins()` | Replace |
| `MultiProvider` in `main.dart` | `ProviderScope` in `main.dart` | Replace |

#### Riverpod provider map (what replaces AppState)

```dart
// presentation/providers/coin_provider.dart
final coinProvider = NotifierProvider<CoinNotifier, int>(() => CoinNotifier());

class CoinNotifier extends Notifier<int> {
  @override
  int build() => ref.watch(hiveRepositoryProvider).getCachedBalance();

  // Optimistic credit — same pattern as current AppState.addCoins()
  Future<int> credit(int amount, String source, String txId) async {
    state += amount;                                        // optimistic
    final newBalance = await ref.read(coinServiceProvider)
        .creditCoins(amount, source: source, txId: txId);
    state = newBalance;                                     // reconcile
    return state;
  }

  Future<bool> spend(int amount, String rewardTitle, String txId) async {
    if (state < amount) return false;
    state -= amount;                                        // optimistic
    final newBalance = await ref.read(coinServiceProvider)
        .spendCoins(amount, rewardTitle: rewardTitle, txId: txId);
    state = newBalance;
    return true;
  }
}

// Derived providers — zero extra network calls
final levelProvider    = Provider<int>((ref) => (ref.watch(totalEarnedProvider) / 5000).floor() + 1);
final totalEarnedProvider = Provider<int>((ref) => ref.watch(userProfileProvider).value?.totalEarned ?? 0);
```

```dart
// presentation/providers/spin_provider.dart
final spinStateProvider = FutureProvider<SpinState>((ref) async {
  return ref.read(spinServiceProvider).getSpinState();
});
```

```dart
// presentation/providers/ad_provider.dart
final adProvider = AsyncNotifierProvider<AdNotifier, AdModel>(() => AdNotifier());
// Wraps existing AdService + AdTrackerService unchanged
```

```dart
// presentation/providers/connectivity_provider.dart
final connectivityProvider = StreamProvider<bool>((ref) {
  return Connectivity().onConnectivityChanged
      .map((r) => r.any((c) => c != ConnectivityResult.none));
});
```

#### Navigation — no change needed

Keep the existing `AppNavigator` (`StatefulWidget` with `AnimatedSwitcher`). It is already correct and has no coupling to state management.

#### Screens — mechanical replacement only

Screens change only how they read state. Business logic does not move into screens.

```dart
// Before
final coins = context.watch<AppState>().coins;
await context.read<AppState>().addCoins(50, source: 'game');

// After
final coins = ref.watch(coinProvider);
await ref.read(coinProvider.notifier).credit(50, 'game', uuid);
```

---

### Layer 2 — Business (Services)
**One service class per domain. Contains all business rules. No UI, no DB calls.**

This replaces the current flat `lib/services/` folder with **domain-scoped** services. The key difference from the current state: **services call repositories, not Supabase directly**.

#### Service inventory (mapped from current code)

| Service | Replaces | Key responsibility |
|---|---|---|
| `CoinService` | `CoinService` (refactored) | `creditCoins()`, `spendCoins()`, optimistic ops, offline queue |
| `RewardService` | `RewardService` (refactored) | `claimDailyReward()`, cooldown logic, chest opening |
| `SpinService` | spin logic from `AppState` | `useSpin()`, `getSpinState()`, cooldown timer |
| `GameService` | `GameService` (refactored) | `submitGameResult()`, daily cap, leaderboard |
| `AdService` | `AdService` (unchanged) | Load, preload, show rewarded/interstitial/rewarded-interstitial |
| `AdTrackerService` | `AdTrackerService` (unchanged) | Daily ad counts, placement tracking |
| `ProfileService` | profile logic from `AppState` | `updateDisplayName()`, `updateProfilePhoto()` (now uploads to Storage) |
| `OfferwallService` | `TapjoyService` + `PubscaleService` (unchanged) | SDK init, event handling |
| `ConnectivityService` | `ConnectivityService` (refactored) | Online/offline stream, trigger queue flush |
| `AuthService` | `AuthService` (refactored) | Anonymous sign-in, fresh-install Keychain clear |
| `BadgeService` | `BadgeService` (unchanged) | Badge check and award |
| `AnalyticsService` | `AnalyticsService` (unchanged) | Event logging |

#### CoinService — the core business service

```dart
// business/coin_service.dart
class CoinService {
  final SupabaseRepository _remote;
  final HiveRepository _queue;
  final SecureRepository _secure;
  final ConnectivityService _connectivity;

  // Replaces AppState.addCoins() — same optimistic pattern, cleaner
  Future<int> creditCoins(int amount, {required String source, required String txId}) async {
    if (!await _connectivity.isOnline) {
      await _queue.enqueuePending({'type': 'credit', 'amount': amount, 'source': source, 'txId': txId});
      final cached = await _secure.getBalance();
      final optimistic = cached + amount;
      await _secure.saveBalance(optimistic);
      return optimistic;
    }
    try {
      final balance = await _remote.creditCoinsViaEdge(amount, source, txId);
      await _secure.saveBalance(balance);
      return balance;
    } catch (e) {
      await _queue.enqueuePending({'type': 'credit', 'amount': amount, 'source': source, 'txId': txId});
      rethrow;
    }
  }

  // Replaces AppState.spendCoins()
  Future<int> spendCoins(int amount, {required String rewardTitle, required String txId}) async {
    if (!await _connectivity.isOnline) {
      await _queue.enqueuePending({'type': 'spend', 'amount': amount, 'rewardTitle': rewardTitle, 'txId': txId});
      final cached = await _secure.getBalance();
      return cached - amount;
    }
    final balance = await _remote.spendCoinsViaEdge(amount, rewardTitle, txId);
    await _secure.saveBalance(balance);
    return balance;
  }

  // Replaces AppState._flushPendingTransactions()
  Future<void> flushPendingQueue() async {
    if (!await _connectivity.isOnline) return;
    final queue = await _queue.getPendingQueue();
    final remaining = <Map<String, dynamic>>[];
    for (final tx in queue) {
      try {
        switch (tx['type']) {
          case 'credit': await _remote.creditCoinsViaEdge(tx['amount'], tx['source'], tx['txId']); break;
          case 'spend':  await _remote.spendCoinsViaEdge(tx['amount'], tx['rewardTitle'], tx['txId']); break;
          case 'game':   await _remote.submitGameSessionViaEdge(tx); break;
        }
      } catch (e) {
        if (!_isIdempotencyError(e)) remaining.add(tx);
      }
    }
    await _queue.setPendingQueue(remaining);
  }

  bool _isIdempotencyError(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('duplicate') || msg.contains('already processed') ||
           msg.contains('insufficient') || msg.contains('cap reached');
  }
}
```

#### RewardService — daily reward + cooldown

```dart
// business/reward_service.dart
class RewardService {
  final SupabaseRepository _remote;
  final SecureRepository _secure;
  final ConnectivityService _connectivity;

  // Replaces AppState.claimDailyReward() + RewardService.claimDailyReward()
  Future<ClaimResult> claimDailyReward() async {
    // Offline fallback — identical to current AppState logic
    if (!await _connectivity.isOnline) {
      final now = DateTime.now();
      await _secure.writeDailyRewardClaimedAt(now);
      return ClaimResult.offlineClaim(amount: RewardConfig.dailyBase);
    }
    final result = await _remote.callEdgeFunction('claim-daily-reward', body: {});
    return ClaimResult.fromMap(result);
  }

  Future<Duration> getDailyRewardCooldown() async {
    // Try server first, fall back to local Keychain timestamp
    // (same logic as current AppState._refreshDailyRewardCooldown())
    if (await _connectivity.isOnline) {
      return _remote.getDailyRewardCooldown();
    }
    return _secure.getDailyRewardCooldownLocal();
  }

  Future<ChestResult> openChest()     => _remote.callEdgeFunctionAs('open-chest',     {});
  Future<ChestResult> openMegaChest() => _remote.callEdgeFunctionAs('open-mega-chest', {});
}
```

#### SpinService — extracted from AppState

```dart
// business/spin_service.dart
class SpinService {
  final SupabaseRepository _remote;
  final SecureRepository _secure;

  // Replaces AppState.useSpin() + AppState.consumeLocalSpin()
  Future<SpinResult> useSpin() async {
    final result = await _remote.callEdgeFunctionAs<SpinResult>('spin-wheel', {});
    await _secure.saveSpinState(result.spinsRemaining, result.cooldownEnd);
    return result;
  }

  // Replaces AppState._refreshSpinState()
  Future<SpinState> getSpinState() async {
    return _remote.callEdgeFunctionAs<SpinState>('get-spin-state', {});
  }
}
```

#### GameService — same logic, cleaner structure

```dart
// business/game_service.dart
class GameService {
  final SupabaseRepository _remote;
  final HiveRepository _queue;

  // Replaces GameService.submitGameResult() — same anti-cheat, same queue logic
  Future<GameSubmitResult> submitGameResult({
    required String gameName,
    required int score,
    required int durationSeconds,
    required String sessionId,
    int multiplier = 1,
  }) async {
    final txId = 'game_$sessionId';
    try {
      return await _remote.callEdgeFunctionAs('add-game-coins', {
        'amount': score,
        'gameName': gameName,
        'sessionId': sessionId,
        'txId': txId,
        'durationSeconds': durationSeconds,
        'multiplier': multiplier,
      });
    } catch (e) {
      if (!_isNonRetryable(e)) {
        await _queue.enqueuePending({'type': 'game', 'gameName': gameName, 'score': score,
          'durationSeconds': durationSeconds, 'sessionId': sessionId, 'txId': txId});
      }
      rethrow;
    }
  }

  Future<List<LeaderboardEntry>> getLeaderboard(String gameName) =>
      _remote.callEdgeFunctionAsList('get-leaderboard', {'gameName': gameName, 'limit': 50});
}
```

---

### Layer 3 — Data (Repositories)
**One repository per storage backend. No business rules here.**

#### Repository inventory

| Repository | Storage | Replaces |
|---|---|---|
| `SupabaseRepository` | Supabase Edge Functions | All `_client.functions.invoke()` calls across services |
| `HiveRepository` | Hive offline queue box | `PendingTransactionService` (SharedPreferences JSON) |
| `SecureRepository` | FlutterSecureStorage + SharedPreferences | Keychain/prefs reads scattered in `AppState` |

#### SupabaseRepository

Consolidates all 3 duplicated JWT retry helpers (`CoinService`, `GameService`, `RewardService`) into one place.

```dart
// data/repositories/supabase_repository.dart
class SupabaseRepository {
  SupabaseClient get _client => Supabase.instance.client;

  // Single shared JWT retry helper (replaces 3 identical copies)
  Future<T> _call<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } catch (e) {
      if (_isJwtFutureError(e)) {
        await Future.delayed(const Duration(milliseconds: 1500));
        return await fn();
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> callEdgeFunction(String name, Map<String, dynamic> body) async {
    return _call(() async {
      final resp = await _client.functions.invoke(name, body: body);
      if (resp.status != 200) throw ServerException(resp.data?['error'] ?? '$name failed');
      return resp.data as Map<String, dynamic>;
    });
  }

  Future<int> creditCoinsViaEdge(int amount, String source, String txId) async {
    final data = await callEdgeFunction('credit-coins', {'amount': amount, 'source': source, 'txId': txId});
    return data['balance'] as int;
  }

  Future<int> spendCoinsViaEdge(int amount, String rewardTitle, String txId) async {
    final data = await callEdgeFunction('spend-coins', {'amount': amount, 'rewardTitle': rewardTitle, 'txId': txId});
    return data['remaining'] as int;
  }

  Future<Map<String, dynamic>> getUserData() => _call(() =>
    _client.from('users').select().eq('id', _uid).maybeSingle().then((d) => d ?? {}));

  String get _uid => _client.auth.currentUser!.id;
  bool _isJwtFutureError(Object e) { /* same as current, extracted once */ }
}
```

#### HiveRepository — replaces PendingTransactionService

```dart
// data/repositories/hive_repository.dart
class HiveRepository {
  static const String _pendingBoxName = 'pending_txs';
  static const String _coinsBoxName   = 'local_cache';
  late Box<Map> _pendingBox;

  Future<void> init() async {
    await Hive.initFlutter();
    _pendingBox = await Hive.openBox<Map>(_pendingBoxName);
  }

  // Replaces PendingTransactionService.enqueue()
  Future<void> enqueuePending(Map<String, dynamic> tx) => _pendingBox.add(tx);

  // Replaces PendingTransactionService.getQueue()
  List<Map<String, dynamic>> getPendingQueue() =>
      _pendingBox.values.cast<Map<String, dynamic>>().toList();

  // Replaces PendingTransactionService.setQueue()
  Future<void> setPendingQueue(List<Map<String, dynamic>> queue) async {
    await _pendingBox.clear();
    for (final tx in queue) { await _pendingBox.add(tx); }
  }
}
```

#### SecureRepository — consolidates Keychain / prefs

```dart
// data/repositories/secure_repository.dart
class SecureRepository {
  static const _storage = FlutterSecureStorage();

  // Replaces GamePrefs.getCoins() / saveCoins()
  Future<int>  getBalance()        async => int.tryParse(await _storage.read(key: 'balance') ?? '0') ?? 0;
  Future<void> saveBalance(int v)        => _storage.write(key: 'balance', value: '$v');

  // Replaces AppState._clearKeychainOnFreshInstall()
  Future<void> clearAllOnFreshInstall() => _storage.deleteAll();

  // Replaces AppState._keyDailyRewardClaimedAt
  Future<void>   writeDailyRewardClaimedAt(DateTime t) => _storage.write(key: 'daily_claimed_at', value: '${t.millisecondsSinceEpoch}');
  Future<Duration> getDailyRewardCooldownLocal() async {
    final v = await _storage.read(key: 'daily_claimed_at');
    if (v == null) return Duration.zero;
    final claimedAt = DateTime.fromMillisecondsSinceEpoch(int.parse(v));
    final remaining = claimedAt.add(const Duration(hours: 24)).difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  // Replaces AppState._keySpinFreeSpins / _keySpinCooldownEnd
  Future<void> saveSpinState(int spins, int? cooldownEndMs) async {
    await _storage.write(key: 'spin_free_spins', value: '$spins');
    if (cooldownEndMs != null) await _storage.write(key: 'spin_cooldown_end', value: '$cooldownEndMs');
    else await _storage.delete(key: 'spin_cooldown_end');
  }
}
```

---

## Part 3 — System Design (Infrastructure)

---

### Cloudflare — Gateway Layer

Place Cloudflare in front of the Supabase Edge Function URL.  
The Flutter app continues calling the same `SUPABASE_URL` — Cloudflare is invisible to the client.

| Rule | Config | Protects |
|---|---|---|
| Rate limit `credit-coins` | 60 req / min / IP | Coin farming bots |
| Rate limit `claim-daily-reward` | 5 req / min / IP | Cooldown bypass attempts |
| Rate limit `add-game-coins` | 30 req / min / IP | Score spamming |
| Rate limit `offerwall-webhook` | 100 req / min | Webhook flood |
| Bot Fight Mode | ON | Automated fake-user accounts |
| Cache `get-leaderboard` | 30 sec TTL at CDN edge | Reduces Redis + Edge Function load |
| Cache `get-offers` | 60 sec TTL at CDN edge | Static config, no need to hit edge every time |
| IP allowlist for `offerwall-webhook` | Tapjoy + PubScale CIDRs only | Block spoofed webhook calls |

---

### Supabase Edge Functions — Business API Gateway

**Rule:** every mutation from Flutter goes through an Edge Function.  
No direct Postgres RPC or table writes from the client after migration.

#### Full function list (current + additions)

| Function | Method | Redis op | Postgres op | Status |
|---|---|---|---|---|
| `claim-daily-reward` | POST | Check + SET `cooldown:daily:{uid}` EX 86400 | `claim_daily_reward()` RPC | exists → add Redis |
| `open-chest` | POST | SET `lock:chest:{uid}` NX EX 5 | `credit_user_coins()` | exists → add Redis lock |
| `open-mega-chest` | POST | SET `lock:chest:{uid}` NX EX 5 | `credit_user_coins()` | exists → add Redis lock |
| `spin-wheel` | POST | Check + SET `cooldown:spin:{uid}` EX 86400 | `use_spin()` RPC | exists as `use-spin` → rename + Redis |
| `get-spin-state` | GET | GET TTL of `cooldown:spin:{uid}` | fallback `get_spin_state()` | exists → add Redis read |
| `add-game-coins` | POST | INCR `cap:game:{uid}:{date}` ≤ 5000; SET `lock:session:{id}` NX | `process_game_session()` | exists → add Redis cap |
| `credit-coins` | POST | INCR `ratelimit:credit:{uid}` ≤ 60/hr; ZADD `leaderboard:{game}` | `credit_user_coins()` | exists → add Redis |
| `spend-coins` | POST | — | `redeem_reward()` RPC | exists, no change |
| `get-user-stats` | GET | — | SELECT from users | exists, no change |
| `get-leaderboard` | GET | ZREVRANGE `leaderboard:weekly` 0 49 | fallback query on read replica | **NEW** |
| `get-offers` | GET | — | static config | exists, no change |
| `offerwall-webhook` | POST | SET `dedup:webhook:{txId}` NX EX 86400 | `credit_user_coins()` | exists → add Redis dedup |

#### Shared `_shared/` utilities to add

```typescript
// _shared/redis.ts
import { Redis } from 'https://deno.land/x/upstash_redis/mod.ts';
export const redis = new Redis({
  url: Deno.env.get('UPSTASH_REDIS_REST_URL')!,
  token: Deno.env.get('UPSTASH_REDIS_REST_TOKEN')!,
});

// _shared/rate_limit.ts
export async function enforceRateLimit(key: string, max: number, windowSecs: number) {
  const count = await redis.incr(key);
  if (count === 1) await redis.expire(key, windowSecs);
  if (count > max) throw new Response('Rate limit exceeded', { status: 429 });
}

// _shared/cooldown.ts
export async function checkCooldown(key: string): Promise<number> {
  const ttl = await redis.ttl(key);  // -2 = key gone, -1 = no TTL, >0 = seconds remaining
  return Math.max(0, ttl);
}
export async function setCooldown(key: string, ttlSecs: number) {
  await redis.set(key, '1', { ex: ttlSecs });
}
```

---

### Upstash Redis — Hot Data

Redis handles all **time-sensitive, high-frequency reads** that would otherwise hit Postgres on every request.

#### Key schema for this app

| Key pattern | Type | TTL | Used by |
|---|---|---|---|
| `cooldown:daily:{userId}` | String | 86400s (24h) | `claim-daily-reward` |
| `cooldown:spin:{userId}` | String | 86400s (24h) | `spin-wheel`, `get-spin-state` |
| `cap:game:{userId}:{YYYY-MM-DD}` | String (INCR) | Until midnight | `add-game-coins` |
| `ratelimit:credit:{userId}` | String (INCR) | 3600s (1h) | `credit-coins` |
| `lock:session:{sessionId}` | String | 30s | `add-game-coins` (double-submit guard) |
| `lock:chest:{userId}` | String | 5s | `open-chest`, `open-mega-chest` |
| `dedup:webhook:{txId}` | String | 86400s | `offerwall-webhook` |
| `leaderboard:weekly` | ZSet (score=totalEarned) | no TTL | `get-leaderboard`, `credit-coins` |
| `leaderboard:{gameName}` | ZSet (score=highScore) | no TTL | `get-leaderboard`, `add-game-coins` |

#### Leaderboard flow

```typescript
// Inside credit-coins — after Postgres credit succeeds:
const newTotal = user.total_earned;
await redis.zadd('leaderboard:weekly', { score: newTotal, member: userId });

// Inside add-game-coins — after game session credited:
await redis.zadd(`leaderboard:${gameName}`, { score: newHighScore, member: userId });

// Inside get-leaderboard:
const entries = await redis.zrevrangeWithScores('leaderboard:weekly', 0, 49);
// If empty (cold start), fall back to Postgres read replica
```

---

### Postgres — Source of Truth

All 5 tables stay unchanged. Two new migrations required.

#### Migration 010 — performance indexes

```sql
-- 010_performance_indexes.sql
-- Required for leaderboard fallback query on read replica
CREATE INDEX IF NOT EXISTS idx_users_total_earned
  ON public.users(total_earned DESC)
  WHERE total_earned > 0;

-- Helps game_sessions daily cap fallback query
CREATE INDEX IF NOT EXISTS idx_game_sessions_user_date
  ON public.game_sessions(user_id, created_at DESC)
  WHERE validated = true;
```

#### Migration 011 — revoke remaining client-callable RPCs

After moving all calls into Edge Functions:

```sql
-- 011_revoke_client_rpcs.sql
REVOKE EXECUTE ON FUNCTION public.use_spin(UUID)                    FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.get_spin_state(UUID)              FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.increment_user_stat(UUID, TEXT)   FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.get_leaderboard(TEXT, INTEGER)    FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.get_weekly_leaderboard(INTEGER)   FROM authenticated;
```

#### Migration 012 — Supabase Storage RLS

```sql
-- 012_storage_rls.sql
-- Authenticated users can upload only into their own folder
CREATE POLICY "upload own avatar" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'profiles' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "public read avatars" ON storage.objects
  FOR SELECT USING (bucket_id = 'profiles');
```

---

### Read Replica — Analytics & Cold-Start Fallback

Available on Supabase Pro / Team. Route two categories of queries to the replica:

| Query | Reason |
|---|---|
| `get-leaderboard` Redis miss fallback | Don't hit the primary for read-heavy ranking queries |
| Admin analytics (total users, daily earn totals) | Long scans should not compete with OLTP |
| `get-user-stats` batch calls | Profile reads don't need primary consistency |

The Flutter client never queries the replica directly — Edge Functions decide the routing internally.

---

### Supabase Storage — Profile Photos

Bucket name: `profiles` · Public: yes · Max size: 2 MB

#### ProfileService — upload flow

```dart
// business/profile_service.dart
class ProfileService {
  final SupabaseRepository _remote;

  // Replaces AppState.updateProfilePhoto() — now uploads real files
  Future<String> uploadProfilePhoto(Uint8List imageBytes, String userId) async {
    final path = '$userId/avatar.jpg';
    await Supabase.instance.client.storage
        .from('profiles')
        .uploadBinary(path, imageBytes,
            fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'));
    return Supabase.instance.client.storage.from('profiles').getPublicUrl(path);
  }

  Future<void> updateDisplayName(String name) => _remote.callEdgeFunction('update-profile', {'displayName': name});
}
```

---

## Part 4 — Complete File Map

### Flutter app — final folder structure

```
lib/
├── main.dart                           # ProviderScope root; Hive.init(); Supabase.init()
│
├── core/
│   ├── constants/
│   │   └── app_constants.dart          # RewardConfig values, level formula, cooldown durations
│   └── utils/
│       └── uuid_generator.dart         # extracted from AppState._generateUuidV4()
│
├── data/                               ← Layer 3: Data (Repositories)
│   ├── supabase_repository.dart        # all Edge Function calls + JWT retry (replaces 3 service duplicates)
│   ├── hive_repository.dart            # Hive offline queue (replaces PendingTransactionService)
│   └── secure_repository.dart          # SecureStorage + SharedPreferences (replaces GamePrefs + AppState Keychain)
│
├── business/                           ← Layer 2: Business (Services)
│   ├── coin_service.dart               # creditCoins, spendCoins, flushQueue
│   ├── reward_service.dart             # claimDailyReward, openChest, openMegaChest
│   ├── spin_service.dart               # useSpin, getSpinState, cooldown timer
│   ├── game_service.dart               # submitGameResult, getLeaderboard
│   ├── ad_service.dart                 # UNCHANGED — load/preload/show ads
│   ├── ad_tracker_service.dart         # UNCHANGED — daily ad counts
│   ├── profile_service.dart            # updateDisplayName, uploadProfilePhoto
│   ├── auth_service.dart               # signInAnonymously, freshInstallCheck
│   ├── connectivity_service.dart       # online stream, triggers queue flush
│   ├── offerwall_service.dart          # TapjoyService + PubscaleService merged
│   ├── badge_service.dart              # UNCHANGED
│   └── analytics_service.dart          # UNCHANGED
│
├── presentation/                       ← Layer 1: Presentation
│   ├── providers/
│   │   ├── coin_provider.dart          # CoinNotifier (replaces AppState coins + addCoins/spendCoins)
│   │   ├── user_provider.dart          # userProfileProvider (replaces AppState profile fields)
│   │   ├── spin_provider.dart          # spinStateProvider (replaces AppState spin state)
│   │   ├── reward_provider.dart        # dailyRewardProvider (replaces AppState daily reward)
│   │   ├── ad_provider.dart            # AdNotifier (replaces AdState)
│   │   └── connectivity_provider.dart  # connectivityProvider (replaces ConnectivityService ChangeNotifier)
│   └── screens/                        # SAME 16 screens — only ref.watch() calls change
│
├── widgets/                            # UNCHANGED (15 widgets)
├── theme/                              # UNCHANGED (app_theme.dart)
└── models/                             # Extend with typed entities
    ├── ad_models.dart                  # UNCHANGED
    ├── badge_model.dart                # UNCHANGED
    ├── reward_config.dart              # UNCHANGED
    ├── user_profile.dart               # NEW — replaces Map<String,dynamic> from AppState
    ├── spin_state.dart                 # NEW — replaces raw map from CoinService.getSpinState()
    ├── claim_result.dart               # NEW — replaces Map from RewardService.claimDailyReward()
    ├── chest_result.dart               # NEW
    └── game_submit_result.dart         # NEW — replaces Map from GameService.submitGameResult()

supabase/
├── migrations/
│   ├── 001–009  (existing)
│   ├── 010_performance_indexes.sql     # NEW
│   ├── 011_revoke_client_rpcs.sql      # NEW
│   └── 012_storage_rls.sql             # NEW
└── functions/
    ├── _shared/
    │   ├── cors.ts                     # existing
    │   ├── auth.ts                     # existing
    │   ├── redis.ts                    # NEW — Upstash client
    │   ├── rate_limit.ts               # NEW
    │   └── cooldown.ts                 # NEW
    ├── add-game-coins/                 # + Redis daily cap + session lock
    ├── claim-daily-reward/             # + Redis cooldown
    ├── claim-chest/ → open-chest/      # + Redis lock
    ├── claim-mega-chest/ → open-mega-chest/ # + Redis lock
    ├── credit-coins/                   # + Redis rate limit + leaderboard ZADD
    ├── spend-coins/                    # unchanged
    ├── use-spin/ → spin-wheel/         # + Redis cooldown
    ├── get-spin-state/                 # + Redis TTL read
    ├── get-user-stats/                 # unchanged
    ├── get-offers/                     # unchanged
    ├── get-leaderboard/                # NEW — Redis ZREVRANGE + replica fallback
    └── offerwall-webhook/              # + Redis NX dedup
```

---

## Part 5 — Implementation Checklist

### Phase 0 — Foundation (app stays identical, zero risk)

- [ ] Add packages: `flutter_riverpod ^2.6.1`, `hive_flutter ^1.1.0`, `image_picker ^1.0.0`
- [ ] Wrap `main.dart` root in `ProviderScope` (keep `MultiProvider` inside during transition)
- [ ] Call `HiveRepository().init()` in `main()` before `runApp()`
- [ ] Create folder skeleton: `core/`, `business/`, `data/`, `presentation/providers/`
- [ ] Create typed model classes: `UserProfile`, `SpinState`, `ClaimResult`, `ChestResult`, `GameSubmitResult`

### Phase 1 — Data Layer

- [ ] Implement `SupabaseRepository` — consolidate all Edge Function calls and JWT retry
- [ ] Implement `HiveRepository` — replace `PendingTransactionService`
- [ ] Implement `SecureRepository` — consolidate all `FlutterSecureStorage` and `GamePrefs` calls

### Phase 2 — Business Layer

- [ ] Implement `CoinService` (replaces `AppState.addCoins/spendCoins/_flushPendingTransactions`)
- [ ] Implement `RewardService` (replaces `RewardService` + chest logic)
- [ ] Implement `SpinService` (extracts spin logic from `AppState`)
- [ ] Implement `GameService` (refactors existing `GameService`)
- [ ] Implement `ProfileService` (replaces profile methods in `AppState`)
- [ ] Implement `AuthService` (keep logic, add fresh-install detection)
- [ ] Implement `ConnectivityService` (trigger `CoinService.flushPendingQueue()` on reconnect)
- [ ] Keep `AdService`, `AdTrackerService`, `BadgeService`, `AnalyticsService` unchanged

### Phase 3 — Redis (Backend)

- [ ] Create Upstash Redis database
- [ ] Add `UPSTASH_REDIS_REST_URL` + `UPSTASH_REDIS_REST_TOKEN` to Supabase Edge Function secrets
- [ ] Add `_shared/redis.ts`, `_shared/rate_limit.ts`, `_shared/cooldown.ts`
- [ ] Update `claim-daily-reward`: add Redis cooldown check + SET
- [ ] Update `spin-wheel` / `get-spin-state`: add Redis cooldown
- [ ] Update `add-game-coins`: add Redis daily cap INCR + session lock NX
- [ ] Update `credit-coins`: add Redis rate limit + ZADD leaderboard
- [ ] Update `offerwall-webhook`: add Redis NX dedup
- [ ] Create `get-leaderboard` Edge Function (Redis ZREVRANGE + read replica fallback)
- [ ] Run migration **010** (performance indexes)

### Phase 4 — Presentation Layer (Riverpod)

- [ ] Implement `CoinNotifier` provider (replaces `AppState` coins)
- [ ] Implement `userProfileProvider` (replaces `AppState` profile fields)
- [ ] Implement `spinStateProvider`
- [ ] Implement `dailyRewardProvider`
- [ ] Implement `AdNotifier` (replaces `AdState`)
- [ ] Implement `connectivityProvider` (replaces `ConnectivityService` as `ChangeNotifier`)
- [ ] Migrate `HomeScreen` → `ref.watch`
- [ ] Migrate `SpinScreen`
- [ ] Migrate `GamesScreen` + all mini-game screens
- [ ] Migrate `ChestScreen`
- [ ] Migrate `OffersScreen`, `RewardsScreen`, `ProfileScreen`
- [ ] Migrate `LeaderboardScreen`
- [ ] Remove `provider` package from `pubspec.yaml`
- [ ] Delete `lib/state/app_state.dart` and `lib/state/ad_state.dart`
- [ ] Delete `lib/services/` (replaced by `business/` + `data/`)

### Phase 5 — Edge Function Hardening

- [ ] Run migration **011** (revoke remaining client RPC grants)
- [ ] Verify no direct RPC calls remain in `SupabaseRepository`

### Phase 6 — Cloudflare

- [ ] Enable Cloudflare proxy on Supabase Edge Function domain
- [ ] Add rate limiting rules per endpoint (see table in Part 3)
- [ ] Enable Bot Fight Mode
- [ ] Add CDN cache rules for `get-leaderboard` (30s) and `get-offers` (60s)
- [ ] Add IP allowlist rule for `offerwall-webhook`

### Phase 7 — Storage

- [ ] Create `profiles` bucket in Supabase Storage (public, 2 MB max)
- [ ] Run migration **012** (storage RLS policies)
- [ ] Implement `ProfileService.uploadProfilePhoto()`
- [ ] Update `ProfileScreen` to use `image_picker` → compress → upload

### Phase 8 — Read Replica (when on Supabase Pro/Team)

- [ ] Enable read replica in Supabase dashboard
- [ ] Update `get-leaderboard` to use read replica connection for cold-start fallback
- [ ] Route admin analytics queries to read replica

---

## Part 6 — Dependency Rule (enforced)

```
Screens / Widgets
      │  ref.watch / ref.read providers only
      ▼
Riverpod Providers
      │  call services only
      ▼
Business Services (business/)
      │  call repositories only
      ▼
Data Repositories (data/)
      │  call Supabase Edge Functions only
      ▼
Cloudflare → Edge Functions → Redis + Postgres
```

> [!IMPORTANT]
> **Screens must never import from `data/` or `business/` directly.**  
> **Business services must never import from `presentation/`.**  
> **Data repositories must never contain business rules (no daily cap logic, no cooldown calculation).**

---

## Part 7 — Scaling Numbers for This App

| DAU | Supabase | Redis | Cloudflare | Est. Cost |
|---|---|---|---|---|
| < 2K | Free | Free | Free | $0 |
| 2K–10K | **Pro** ($25/mo) | Pay-as-you-go (~$5/mo) | Free | ~$30 |
| 10K–50K | Pro + add-ons | Pay-as-you-go (~$25/mo) | Pro ($20/mo) | ~$70 |
| 50K+ | **Team** ($599/mo) | Pro ($280/mo) | Pro ($20/mo) | ~$900 |

**Resolved scaling bottlenecks (vs. current architecture):**

| Problem | Solution |
|---|---|
| Realtime WS connection limit | Removed persistent WS — polling after mutations only |
| Leaderboard full Postgres scan | Redis Sorted Sets — O(log N) insert, O(M) range read |
| Cooldown row locks under concurrency | Redis TTL keys — atomic, no row contention |
| Offerwall webhook duplicates | Redis NX dedup — single atomic check-and-set |
| Bot farming / reward abuse | Cloudflare Bot Fight Mode + per-endpoint rate limits |
| JWT retry code duplicated 3× | Consolidated in `SupabaseRepository` — one place |
| Offline queue crash-unsafe (SharedPrefs JSON) | Hive box — atomic writes, typed, crash-safe |
