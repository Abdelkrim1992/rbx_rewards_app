import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/reward_item.dart';
import 'coin_provider.dart';

/// Provides the catalog of redeemable reward items
final rewardCatalogProvider = Provider<List<RewardItem>>((ref) {
  return RewardItem.defaultCatalog;
});

/// Filter for categories: null = All, or specific RewardCategory
final rewardCategoryFilterProvider = StateProvider<RewardCategory?>((ref) => null);

/// Tracks selected denomination index for each reward card: rewardId -> index
final selectedDenominationsProvider =
    StateNotifierProvider<SelectedDenominationsNotifier, Map<String, int>>((ref) {
  return SelectedDenominationsNotifier();
});

class SelectedDenominationsNotifier extends StateNotifier<Map<String, int>> {
  SelectedDenominationsNotifier() : super({});

  int getIndex(String rewardId) => state[rewardId] ?? 0;

  void select(String rewardId, int index) {
    state = {...state, rewardId: index};
  }
}

/// Active goal reward target denomination chosen by the user
final activeGoalRewardProvider =
    StateNotifierProvider<ActiveGoalNotifier, GoalRewardState>((ref) {
  return ActiveGoalNotifier();
});

class GoalRewardState {
  final String title;
  final int targetCoins;
  final String label;

  const GoalRewardState({
    required this.title,
    required this.targetCoins,
    required this.label,
  });

  static const GoalRewardState defaultGoal = GoalRewardState(
    title: r'$5 Roblox Gift Card',
    targetCoins: 40000,
    label: r'$5 USD',
  );
}

class ActiveGoalNotifier extends StateNotifier<GoalRewardState> {
  ActiveGoalNotifier() : super(GoalRewardState.defaultGoal) {
    _load();
  }

  static const _kPrefGoalTitle = 'active_goal_title';
  static const _kPrefGoalTarget = 'active_goal_target';
  static const _kPrefGoalLabel = 'active_goal_label';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final title = prefs.getString(_kPrefGoalTitle);
    final target = prefs.getInt(_kPrefGoalTarget);
    final label = prefs.getString(_kPrefGoalLabel);

    if (title != null && target != null && label != null) {
      state = GoalRewardState(
        title: title,
        targetCoins: target,
        label: label,
      );
    }
  }

  Future<void> setGoal(String title, int targetCoins, String label) async {
    state = GoalRewardState(
      title: title,
      targetCoins: targetCoins,
      label: label,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefGoalTitle, title);
    await prefs.setInt(_kPrefGoalTarget, targetCoins);
    await prefs.setString(_kPrefGoalLabel, label);
  }
}

/// Promo code validation & redemption result
class PromoResult {
  final bool success;
  final String message;
  final int coinsAdded;

  const PromoResult({
    required this.success,
    required this.message,
    this.coinsAdded = 0,
  });
}

final promoCodeServiceProvider = Provider<PromoCodeService>((ref) {
  return PromoCodeService(ref);
});

class PromoCodeService {
  final Ref _ref;

  PromoCodeService(this._ref);

  static const _kRedeemedCodesPref = 'redeemed_promo_codes';

  // Valid codes and rewards
  static const Map<String, int> _validCodes = {
    'RBXBOOST': 100,
    'WELCOME2026': 150,
    'DISCORD50': 50,
    'GAMERPASS': 200,
  };

  Future<PromoResult> redeem(String rawCode) async {
    final code = rawCode.trim().toUpperCase();
    if (code.isEmpty) {
      return const PromoResult(
        success: false,
        message: 'Please enter a valid promo code.',
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final redeemed = prefs.getStringList(_kRedeemedCodesPref) ?? [];

    if (redeemed.contains(code)) {
      return const PromoResult(
        success: false,
        message: 'This promo code has already been redeemed.',
      );
    }

    final rewardCoins = _validCodes[code];
    if (rewardCoins == null) {
      return const PromoResult(
        success: false,
        message: 'Invalid or expired promo code.',
      );
    }

    // Credit coins via coin provider
    await _ref.read(coinProvider.notifier).credit(rewardCoins, 'promo_code_$code');

    // Save as redeemed
    redeemed.add(code);
    await prefs.setStringList(_kRedeemedCodesPref, redeemed);

    return PromoResult(
      success: true,
      message: 'Successfully redeemed +$rewardCoins RBX Coins!',
      coinsAdded: rewardCoins,
    );
  }
}
