import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user_profile.dart';
import 'providers.dart';
import 'coin_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Auth State ─────────────────────────────────────────────────────────────

final authStateProvider = StreamProvider((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

// ── Onboarding ─────────────────────────────────────────────────────────────

final onboardingCompletedProvider =
    StateNotifierProvider<OnboardingNotifier, bool>((ref) {
  return OnboardingNotifier();
});

class OnboardingNotifier extends StateNotifier<bool> {
  OnboardingNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool('onboarding_completed') ?? false;
  }

  Future<void> setCompleted(bool completed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', completed);
    state = completed;
  }
}

// ── User Profile (Cache-first, no persistent DB stream) ────────────────────
//
// Strategy:
//  • On startup, fetch profile from the get-user-stats Edge Function
//    (which serves from Redis cache in <1ms, falls back to Postgres on misses).
//  • The coinProvider handles all in-session balance updates optimistically via
//    Riverpod state so the UI feels instant.
//  • When the app is foregrounded (after being backgrounded), we re-fetch
//    to pick up any backend changes (offerwall payouts, etc.) that happened
//    while the user was away.
//
// This replaces the Supabase .stream() WebSocket subscription which kept
// a persistent Postgres connection open per user — not scalable at 10k+ DAU.

final userProfileStreamProvider = StreamProvider<UserProfile>((ref) {
  // Rebuild when auth state changes (login / logout)
  ref.watch(authStateProvider);

  final uid = ref.watch(authServiceProvider).currentUser?.id;
  if (uid == null) {
    return Stream.value(UserProfile(
      id: '',
      coins: 0,
      totalEarned: 0,
      consecutiveDays: 0,
      gamesPlayed: 0,
      offersCompleted: 0,
      displayName: 'Player',
    ));
  }

  // One-shot fetch via Edge Function (uses Redis cache on backend)
  return Stream.fromFuture(
    ref.read(supabaseRepositoryProvider).getUserStats(),
  ).map((data) {
    if (data.isEmpty) {
      return UserProfile(
        id: uid,
        coins: 0,
        totalEarned: 0,
        consecutiveDays: 0,
        gamesPlayed: 0,
        offersCompleted: 0,
        displayName: 'Player',
      );
    }
    final profile = UserProfile.fromJson(data);
    // Sync the coin provider with the authoritative backend balance
    Future.microtask(() {
      ref.read(coinProvider.notifier).updateBalance(profile.coins);
    });
    return profile;
  });
});

final userProfileProvider = Provider<UserProfile>((ref) {
  return ref.watch(userProfileStreamProvider).value ??
      UserProfile(
        id: '',
        coins: 0,
        totalEarned: 0,
        consecutiveDays: 0,
        gamesPlayed: 0,
        offersCompleted: 0,
        displayName: 'Player',
      );
});

// ── App Lifecycle Observer ─────────────────────────────────────────────────
//
// Invalidates and re-fetches user stats when the app comes back to foreground.
// Register this in main.dart with WidgetsBinding.instance.addObserver(...)

class AppLifecycleObserver extends WidgetsBindingObserver {
  final WidgetRef ref;

  AppLifecycleObserver(this.ref);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-fetch profile from the backend (hits Redis cache — ultra-fast)
      ref.invalidate(userProfileStreamProvider);
    }
  }
}
