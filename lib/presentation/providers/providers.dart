import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/supabase_repository.dart';
import '../../data/hive_repository.dart';
import '../../data/secure_repository.dart';
import '../../business/auth_service.dart';
import '../../business/coin_service.dart';
import '../../business/reward_service.dart';
import '../../business/spin_service.dart';
import '../../business/game_service.dart';
import '../../business/profile_service.dart';
import '../../business/connectivity_service.dart';

import '../../business/ad_service.dart';
import '../../business/ad_tracker_service.dart';
import '../../business/badge_service.dart';
import '../../business/daily_cap_service.dart';

final supabaseRepositoryProvider = Provider((ref) => SupabaseRepository());
final hiveRepositoryProvider = Provider((ref) => HiveRepository());
final secureRepositoryProvider = Provider((ref) => SecureRepository());

final connectivityServiceProvider = Provider((ref) => ConnectivityService());

final authServiceProvider = Provider((ref) {
  return AuthService(secure: ref.watch(secureRepositoryProvider));
});

final coinServiceProvider = Provider((ref) {
  return CoinService(
    remote: ref.watch(supabaseRepositoryProvider),
    queue: ref.watch(hiveRepositoryProvider),
    secure: ref.watch(secureRepositoryProvider),
    connectivity: ref.watch(connectivityServiceProvider),
  );
});

final rewardServiceProvider = Provider((ref) {
  return RewardService(
    remote: ref.watch(supabaseRepositoryProvider),
    secure: ref.watch(secureRepositoryProvider),
    connectivity: ref.watch(connectivityServiceProvider),
  );
});

final spinServiceProvider = Provider((ref) {
  return SpinService(
    remote: ref.watch(supabaseRepositoryProvider),
    secure: ref.watch(secureRepositoryProvider),
    connectivity: ref.watch(connectivityServiceProvider),
  );
});

final gameServiceProvider = Provider((ref) {
  return GameService(
    remote: ref.watch(supabaseRepositoryProvider),
    queue: ref.watch(hiveRepositoryProvider),
  );
});

final profileServiceProvider = Provider((ref) {
  return ProfileService(remote: ref.watch(supabaseRepositoryProvider));
});

final adServiceProvider = Provider((ref) => AdService());
final adTrackerServiceProvider = Provider((ref) => AdTrackerService());
final badgeServiceProvider = Provider((ref) => BadgeService());
final dailyCapServiceProvider = Provider((ref) => DailyCapService());
