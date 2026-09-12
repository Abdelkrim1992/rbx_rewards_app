import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/referral_model.dart';
import '../../business/referral_service.dart';
import 'coin_provider.dart';
import 'providers.dart';
import 'user_provider.dart';

final referralServiceProvider = Provider<ReferralService>((ref) {
  return ReferralService(
    remote: ref.watch(supabaseRepositoryProvider),
    coinService: ref.watch(coinServiceProvider),
    antiCheat: ref.watch(antiCheatServiceProvider),
  );
});

final referralStateProvider =
    StateNotifierProvider<ReferralNotifier, AsyncValue<ReferralState>>((ref) {
  return ReferralNotifier(ref);
});

class ReferralNotifier extends StateNotifier<AsyncValue<ReferralState>> {
  final Ref _ref;

  ReferralNotifier(this._ref) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    try {
      final service = _ref.read(referralServiceProvider);
      final stateData = await service.getReferralState();
      state = AsyncValue.data(stateData);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<ReferralRedeemResult> redeemCode(String code) async {
    final service = _ref.read(referralServiceProvider);
    final result = await service.redeemCode(code);

    if (result.isSuccess) {
      // Refresh user balance and profile
      _ref.invalidate(coinProvider);
      _ref.invalidate(userProfileStreamProvider);
      await load();
    }

    return result;
  }
}
