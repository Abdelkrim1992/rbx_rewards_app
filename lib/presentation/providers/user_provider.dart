import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_profile.dart';
import 'providers.dart';
import 'coin_provider.dart';

final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

final onboardingCompletedProvider = StateNotifierProvider<OnboardingNotifier, bool>((ref) {
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

final userProfileStreamProvider = StreamProvider<UserProfile>((ref) {
  // Watch authStateProvider so that this stream updates when auth state changes (e.g. login/logout)
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

  // Stream user changes from Supabase
  return Supabase.instance.client
      .from('users')
      .stream(primaryKey: ['id'])
      .eq('id', uid)
      .map((rows) {
        if (rows.isEmpty) {
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
        final profile = UserProfile.fromJson(rows.first);
        
        // Synchronously update the coinProvider when a new verified balance comes from the server.
        ref.read(coinProvider.notifier).updateBalance(profile.coins);
        
        return profile;
      });
});

final userProfileProvider = Provider<UserProfile>((ref) {
  return ref.watch(userProfileStreamProvider).value ?? UserProfile(
    id: '',
    coins: 0,
    totalEarned: 0,
    consecutiveDays: 0,
    gamesPlayed: 0,
    offersCompleted: 0,
    displayName: 'Player',
  );
});
