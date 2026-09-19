import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol_finders/patrol_finders.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User, AuthState, AuthChangeEvent;
import 'package:rbx_rewards/data/supabase_repository.dart';

import 'package:rbx_rewards/main.dart';
import 'package:rbx_rewards/models/user_profile.dart';
import 'package:rbx_rewards/presentation/providers/user_provider.dart';
import 'package:rbx_rewards/presentation/providers/coin_provider.dart';
import 'package:rbx_rewards/presentation/providers/data_providers.dart';
import 'package:rbx_rewards/presentation/providers/providers.dart';
import 'package:rbx_rewards/presentation/providers/referral_provider.dart';
import 'package:rbx_rewards/models/referral_model.dart';
import 'package:rbx_rewards/business/auth_service.dart';
import 'package:rbx_rewards/data/secure_repository.dart';
import 'package:rbx_rewards/data/hive_repository.dart';

export 'package:patrol/patrol.dart' hide patrolTest;
export 'package:patrol_finders/patrol_finders.dart';

void patrolTest(
  String description,
  Future<void> Function(PatrolTester) callback, {
  bool? skip,
  Timeout? timeout,
  bool semanticsEnabled = true,
  TestVariant<Object?> variant = const DefaultTestVariant(),
  dynamic tags,
}) {
  patrolWidgetTest(
    description,
    callback,
    skip: skip,
    timeout: timeout,
    semanticsEnabled: semanticsEnabled,
    variant: variant,
    tags: tags,
  );
}

class FakeReferralNotifier extends ReferralNotifier {
  FakeReferralNotifier(super.ref) {
    state = const AsyncValue.data(
      ReferralState(
        myReferralCode: 'E2E123',
        hasRedeemedCode: false,
        totalFriendsInvited: 2,
        totalCoinsEarned: 400,
      ),
    );
  }

  @override
  Future<void> load() async {}

  @override
  Future<ReferralRedeemResult> redeemCode(String code) async {
    return const ReferralRedeemResult(
      isSuccess: true,
      message: 'Code redeemed successfully!',
      coinsAwarded: 200,
    );
  }
}

/// Fake AuthService for E2E testing that avoids native Google/Apple sign-in crashes.
/// Extends the concrete AuthService to pass Riverpod type checks.
class FakeAuthService extends AuthService {
  User? _fakeUser;
  final StreamController<AuthState> _authStreamController =
      StreamController<AuthState>.broadcast();

  FakeAuthService({User? initialUser})
      : _fakeUser = initialUser,
        super(secure: SecureRepository());

  @override
  User? get currentUser => _fakeUser;

  @override
  bool get isInitialized => true;

  @override
  Stream<AuthState> get authStateChanges => _authStreamController.stream;

  @override
  Future<bool> signInWithGoogle() async {
    _fakeUser = const User(
      id: 'e2e_tester_uid',
      appMetadata: {},
      userMetadata: {'full_name': 'E2E Tester'},
      aud: 'authenticated',
      createdAt: '2026-01-01',
    );
    _authStreamController.add(AuthState(AuthChangeEvent.signedIn, null));
    return true;
  }

  @override
  Future<bool> signInWithApple() async {
    _fakeUser = const User(
      id: 'e2e_tester_uid',
      appMetadata: {},
      userMetadata: {'full_name': 'E2E Tester'},
      aud: 'authenticated',
      createdAt: '2026-01-01',
    );
    _authStreamController.add(AuthState(AuthChangeEvent.signedIn, null));
    return true;
  }

  @override
  Future<void> signOut() async {
    _fakeUser = null;
    _authStreamController.add(AuthState(AuthChangeEvent.signedOut, null));
  }

  @override
  Future<void> deleteAccount() async {
    _fakeUser = null;
    _authStreamController.add(AuthState(AuthChangeEvent.signedOut, null));
    // Clear shared preferences to simulate app reset
    final prefs = await SharedPreferences.getInstance();
    final currentVersion = prefs.getInt('device_account_version') ?? 0;
    await prefs.clear();
    await prefs.setInt('device_account_version', currentVersion + 1);
  }
}

/// Fake SupabaseRepository that returns authorized status and mock data for E2E tests
class FakeSupabaseRepository extends SupabaseRepository {
  final String? _uid;
  FakeSupabaseRepository({String? uid}) : _uid = uid;

  @override
  String? get currentUserId => _uid ?? 'e2e_tester_uid';

  @override
  Future<Map<String, dynamic>> claimWelcomeBonus() async {
    return {'success': true, 'claimed': true, 'balance': 500, 'amount': 500};
  }

  @override
  Future<Map<String, dynamic>> getUserData() async {
    return {
      'id': _uid ?? 'e2e_tester_uid',
      'welcome_bonus_claimed': false,
      'balance': 0,
      'games_played': 0,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> getCoinDistributions() async {
    return [];
  }

  @override
  Future<Map<String, dynamic>> getUserStats() async {
    return {
      'coins': 500,
      'total_earned': 500,
      'consecutive_days': 1,
      'games_played': 0,
      'offers_completed': 0,
    };
  }

  @override
  Future<int> creditCoinsViaEdge(int amount, String source, String txId) async {
    return 500 + amount;
  }
}

/// Builds a fully-configured ProviderContainer for E2E tests
Future<ProviderContainer> buildE2eContainer({
  bool onboardingCompleted = false,
  int coins = 100,
  int totalEarned = 150,
  int streak = 1,
  User? user,
  List<Map<String, dynamic>>? rewardHistory,
}) async {
  SharedPreferences.setMockInitialValues({
    'onboarding_completed': onboardingCompleted,
    'pref_sound_enabled': true,
    'pref_notifications_enabled': true,
    'pref_haptics_enabled': true,
    'device_account_version': 0,
  });
  FlutterSecureStorage.setMockInitialValues({
    'balance': coins.toString(),
  });

  final prefs = await SharedPreferences.getInstance();
  final secureRepo = SecureRepository();
  final hiveRepo = HiveRepository();

  final profile = UserProfile(
    id: user?.id ?? 'e2e_tester_uid',
    coins: coins,
    totalEarned: totalEarned,
    consecutiveDays: streak,
    gamesPlayed: 5,
    offersCompleted: 1,
    displayName: 'E2E Tester',
  );

  final container = ProviderContainer(
    overrides: [
      userProfileStreamProvider.overrideWith((ref) => Stream.value(profile)),
      userProfileProvider.overrideWith((ref) => profile),
      onboardingCompletedProvider.overrideWith((ref) => OnboardingNotifier(prefs)),
      rewardHistoryProvider.overrideWith((ref) async => rewardHistory ?? <Map<String, dynamic>>[]),
      authServiceProvider.overrideWithValue(FakeAuthService(initialUser: user)),
      supabaseRepositoryProvider.overrideWithValue(FakeSupabaseRepository(uid: user?.id)),
      secureRepositoryProvider.overrideWithValue(secureRepo),
      hiveRepositoryProvider.overrideWithValue(hiveRepo),
      referralStateProvider.overrideWith((ref) => FakeReferralNotifier(ref)),
    ],
  );

  // Initialize initial coin balance
  container.read(coinProvider.notifier).updateBalance(coins);

  return container;
}

/// Boots RbxRewardsApp with the test container and pumps to stability
Future<void> pumpRbxApp(
  PatrolTester $, {
  required ProviderContainer container,
}) async {
  // Use a standard mobile portrait viewport (1080 x 2400)
  $.tester.view.physicalSize = const Size(1080, 2400);
  $.tester.view.devicePixelRatio = 2.5;

  await $.pumpWidget(RbxRewardsApp(container: container));
  await settleApp($);
}

/// Robust settle loop handling timers and microtasks
Future<void> settleApp(PatrolTester $, {int iterations = 8}) async {
  for (int i = 0; i < iterations; i++) {
    await $.tester.pump(const Duration(milliseconds: 150));
  }
}
