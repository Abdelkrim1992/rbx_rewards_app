import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/badge_model.dart';

/// Tracks earned badges and awards bonus coins.
class BadgeService {
  static const String _earnedBadgesKey = 'earned_badges';
  static const String _consecutiveDaysKey = 'badge_consecutive_days';
  static const String _lastCheckDateKey = 'badge_last_check_date';

  Set<String> _earnedBadgeIds = {};
  int _consecutiveDays = 0;
  String _lastCheckDate = '';

  /// Load persisted badge state.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_earnedBadgesKey);
    if (jsonStr != null) {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      _earnedBadgeIds = list.cast<String>().toSet();
    }
    _consecutiveDays = prefs.getInt(_consecutiveDaysKey) ?? 0;
    _lastCheckDate = prefs.getString(_lastCheckDateKey) ?? '';
  }

  /// Check which badges should be awarded based on today's ad count and streak.
  List<Badge> checkAndAwardBadges({
    required int dailyAdCount,
    required int dailyForcedAdCount,
  }) {
    final newlyEarned = <Badge>[];
    final now = DateTime.now();
    final today = '${now.year}-${now.month}-${now.day}';

    // Update consecutive days streak
    if (dailyForcedAdCount >= 15) {
      if (_lastCheckDate == today) {
        // Already counted today
      } else if (_isYesterday(_lastCheckDate)) {
        _consecutiveDays++;
      } else {
        _consecutiveDays = 1;
      }
      _lastCheckDate = today;
    }

    // Check each badge
    if (dailyAdCount >= 5 && !_earnedBadgeIds.contains(Badges.adWatcher.id)) {
      newlyEarned.add(Badges.adWatcher);
    }
    if (dailyAdCount >= 15 && !_earnedBadgeIds.contains(Badges.adMaster.id)) {
      newlyEarned.add(Badges.adMaster);
    }
    if (dailyAdCount >= 25 && !_earnedBadgeIds.contains(Badges.adChampion.id)) {
      newlyEarned.add(Badges.adChampion);
    }
    if (_consecutiveDays >= 7 &&
        !_earnedBadgeIds.contains(Badges.weekStreak.id)) {
      newlyEarned.add(Badges.weekStreak);
    }

    for (final badge in newlyEarned) {
      _earnedBadgeIds.add(badge.id);
    }

    _persist();
    return newlyEarned;
  }

  bool _isYesterday(String dateStr) {
    if (dateStr.isEmpty) return false;
    try {
      final parts = dateStr.split('-').map(int.parse).toList();
      final last = DateTime(parts[0], parts[1], parts[2]);
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      return last.year == yesterday.year &&
          last.month == yesterday.month &&
          last.day == yesterday.day;
    } catch (_) {
      return false;
    }
  }

  /// All earned badge IDs.
  Set<String> get earnedBadgeIds => Set.unmodifiable(_earnedBadgeIds);

  /// Get full badge objects for earned badges.
  List<Badge> get earnedBadges {
    return Badges.all.where((b) => _earnedBadgeIds.contains(b.id)).toList();
  }

  /// Progress toward next badge.
  Map<String, dynamic> get nextBadgeProgress {
    if (!_earnedBadgeIds.contains(Badges.adWatcher.id)) {
      return {'name': Badges.adWatcher.name, 'current': 0, 'target': 5};
    }
    if (!_earnedBadgeIds.contains(Badges.adMaster.id)) {
      return {'name': Badges.adMaster.name, 'current': 5, 'target': 15};
    }
    if (!_earnedBadgeIds.contains(Badges.adChampion.id)) {
      return {'name': Badges.adChampion.name, 'current': 15, 'target': 25};
    }
    if (!_earnedBadgeIds.contains(Badges.weekStreak.id)) {
      return {
        'name': Badges.weekStreak.name,
        'current': _consecutiveDays,
        'target': 7
      };
    }
    return {'name': 'All badges earned!', 'current': 0, 'target': 0};
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _earnedBadgesKey, jsonEncode(_earnedBadgeIds.toList()));
    await prefs.setInt(_consecutiveDaysKey, _consecutiveDays);
    await prefs.setString(_lastCheckDateKey, _lastCheckDate);
  }
}
