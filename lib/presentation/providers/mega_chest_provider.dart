import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'coin_provider.dart';

final megaChestMilestoneProvider = StateNotifierProvider<MegaChestMilestoneNotifier, int>((ref) {
  return MegaChestMilestoneNotifier(ref);
});

class MegaChestMilestoneNotifier extends StateNotifier<int> {
  final Ref _ref;
  static const String _keyLastClaimedMilestone = 'mega_chest_last_claimed_milestone';
  bool _mounted = true;

  MegaChestMilestoneNotifier(this._ref) : super(0) {
    _ref.onDispose(() => _mounted = false);
    _loadMilestone();
  }

  Future<void> _loadMilestone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!_mounted) return;
      state = prefs.getInt(_keyLastClaimedMilestone) ?? 0;
    } catch (_) {
      // Keep state as 0 on error
    }
  }

  Future<void> setMilestone(int value) async {
    if (!_mounted) return;
    state = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyLastClaimedMilestone, value);
    } catch (_) {}
  }

  Future<bool> claimReward() async {
    if (!_mounted) return false;
    
    // Credit 1,000 coins via coinProvider
    await _ref.read(coinProvider.notifier).credit(1000, 'mega_chest');
    
    // Update the milestone
    final nextMilestone = state + 1;
    await setMilestone(nextMilestone);
    
    return true;
  }
}
