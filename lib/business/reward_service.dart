import '../data/secure_repository.dart';
import '../data/supabase_repository.dart';
import '../models/claim_result.dart';
import '../models/chest_result.dart';
import 'connectivity_service.dart';

class RewardService {
  final SupabaseRepository _remote;
  final SecureRepository _secure;
  final ConnectivityService _connectivity;

  RewardService({
    required SupabaseRepository remote,
    required SecureRepository secure,
    required ConnectivityService connectivity,
  })  : _remote = remote,
        _secure = secure,
        _connectivity = connectivity;

  Future<ClaimResult> claimDailyReward({int amount = 100}) async {
    final online = await _connectivity.isOnline;
    if (!online) {
      final now = DateTime.now();
      await _secure.writeDailyRewardClaimedAt(now);
      return ClaimResult.offlineClaim(amount: amount);
    }
    try {
      final result = await _remote.callEdgeFunction('claim-daily-reward', body: {'amount': amount});
      final claimResult = ClaimResult.fromMap(result);
      if (claimResult.success) {
        await _secure.writeDailyRewardClaimedAt(DateTime.now());
      }
      return claimResult;
    } catch (e) {
      // Offline fallback on error
      final now = DateTime.now();
      await _secure.writeDailyRewardClaimedAt(now);
      return ClaimResult.offlineClaim(amount: amount);
    }
  }

  Future<Duration> getDailyRewardCooldown() async {
    final online = await _connectivity.isOnline;
    if (online) {
      try {
        return await _remote.getDailyRewardCooldown();
      } catch (_) {
        // fall back to secure storage
      }
    }
    return _secure.getDailyRewardCooldownLocal();
  }

  Future<ChestResult> openChest() async {
    try {
      final result = await _remote.callEdgeFunction('open-chest', body: {});
      return ChestResult.fromMap(result);
    } catch (e) {
      return ChestResult(success: false, coinsEarned: 0, errorMessage: e.toString());
    }
  }


  Future<List<Map<String, dynamic>>> getRedeemedRewards({int limit = 50}) async {
    return _remote.getRedeemedRewards(limit: limit);
  }
}
