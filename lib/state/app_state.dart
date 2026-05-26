import 'dart:async';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../services/coin_service.dart';
import '../services/game_service.dart';
import '../services/pending_transaction_service.dart';
import '../services/reward_service.dart';
import '../widgets/game_prefs.dart';

class AppState extends ChangeNotifier {
  static const String _keyOnboardingCompleted = 'onboarding_completed';
  static const String _keySpinFreeSpins = 'spin_free_spins';
  static const String _keySpinCooldownEnd = 'spin_cooldown_end';
  static const String _keyDailyRewardClaimedAt = 'daily_reward_claimed_at';

  final bool supabaseEnabled;
  final AuthService _authService;
  final CoinService _coinService;
  final RewardService _rewardService;
  final GameService _gameService = GameService();

  AppState({
    this.supabaseEnabled = false,
    required AuthService authService,
    required CoinService coinService,
    required RewardService rewardService,
  })  : _authService = authService,
        _coinService = coinService,
        _rewardService = rewardService;

  // --- User data (streamed from Supabase) ---
  int _coins = 0;
  int _totalCoinsEarned = 0;
  int _consecutiveDays = 0;
  int _gamesPlayed = 0;
  int _offersCompleted = 0;
  int _level = 1;
  String _displayName = 'Player';
  String? _profilePhotoUrl;

  bool _isLoaded = false;
  bool _isOnboardingCompleted = false;
  bool _isOnline = true;
  bool _isAuthenticated = false;
  String? _errorMessage;

  // --- Daily reward ---
  Timer? _dailyRewardTimer;
  Duration _dailyRewardRemaining = Duration.zero;

  // --- Spin state (local only) ---
  int _spinFreeSpins = 3;
  Timer? _spinCooldownTimer;
  Duration _spinCooldownRemaining = Duration.zero;

  StreamSubscription? _connectivitySubscription;
  StreamSubscription? _balanceSub;

  /// Guards the realtime stream handler from overwriting optimistic local balances
  /// while an addCoins/spendCoins operation is in-flight.
  int _pendingCoinOps = 0;

  int get coins => _coins;
  int get totalCoinsEarned => _totalCoinsEarned;
  int get consecutiveDays => _consecutiveDays;
  int get gamesPlayed => _gamesPlayed;
  int get totalGamesPlayed => _gamesPlayed;
  int get offersCompleted => _offersCompleted;
  int get totalOffersCompleted => _offersCompleted;
  int get level => _level;
  String get displayName => _displayName;
  String? get profilePhotoUrl => _profilePhotoUrl;

  bool get isLoaded => _isLoaded;
  bool get isOnboardingCompleted => _isOnboardingCompleted;
  bool get isOnline => _isOnline;
  bool get isAuthenticated => _isAuthenticated;
  String? get errorMessage => _errorMessage;

  Duration get dailyRewardRemaining => _dailyRewardRemaining;
  bool get isDailyRewardCoolingDown => _dailyRewardRemaining > Duration.zero;

  int get spinFreeSpins => _spinFreeSpins;
  bool get isSpinOnCooldown => _spinCooldownRemaining > Duration.zero;
  Duration get spinCooldownRemaining => _spinCooldownRemaining;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> load() async {
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (_isOnline != hasConnection) {
        final wasOffline = !_isOnline;
        _isOnline = hasConnection;
        notifyListeners();
        if (wasOffline && _isOnline) {
          _flushPendingTransactions().catchError((e) {
            debugPrint('Failed to flush pending transactions: $e');
          });
        }
      }
    });
    final initialResult = await Connectivity().checkConnectivity();
    _isOnline = initialResult.any((r) => r != ConnectivityResult.none);

    final prefs = await SharedPreferences.getInstance();
    _isOnboardingCompleted = prefs.getBool(_keyOnboardingCompleted) ?? false;
    _profilePhotoUrl = await GamePrefs.getProfilePhotoUrl();

    _spinFreeSpins = prefs.getInt(_keySpinFreeSpins) ?? 5;
    final spinCooldownEnd = prefs.getInt(_keySpinCooldownEnd);
    if (spinCooldownEnd != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final remainingMs = spinCooldownEnd - now;
      if (remainingMs > 0) {
        _spinCooldownRemaining = Duration(milliseconds: remainingMs);
        _syncSpinCooldownTimer();
      } else {
        _spinCooldownRemaining = Duration.zero;
        if (_spinFreeSpins == 0) {
          _spinFreeSpins = 3;
          prefs.setInt(_keySpinFreeSpins, _spinFreeSpins);
        }
      }
    }

    bool authSuccess = false;
    if (supabaseEnabled) {
      try {
        final user = await _authService.signInAnonymously();
        authSuccess = user != null;
        _isAuthenticated = authSuccess;
        if (user != null) {
          debugPrint('✅ Anonymous auth success: uid=${user.id}');
        } else {
          debugPrint('⚠️ Anonymous auth returned null user');
        }
      } catch (e) {
        debugPrint('❌ Anonymous auth failed: $e');
        _isAuthenticated = false;
      }
    }

    _coins = await GamePrefs.getCoins();

    if (supabaseEnabled) {
      _balanceSub = _coinService.userDataStream.listen(
        (data) {
          if (data.isEmpty) return;
          final serverBalance = data['balance'] as int? ?? _coins;
          // Only apply stream balance updates that increase the local balance.
          // This prevents server updates from reverting optimistic local credits
          // while an addCoins/spendCoins operation is in-flight or recently failed.
          if (_pendingCoinOps == 0 && serverBalance > _coins) {
            _coins = serverBalance;
            GamePrefs.saveCoins(_coins);
          }
          _totalCoinsEarned = data['total_earned'] as int? ?? _totalCoinsEarned;
          _gamesPlayed = data['games_played'] as int? ?? _gamesPlayed;
          _offersCompleted =
              data['offers_completed'] as int? ?? _offersCompleted;
          _consecutiveDays =
              data['consecutive_days'] as int? ?? _consecutiveDays;
          _level = data['level'] as int? ?? _level;
          _displayName = data['display_name'] as String? ?? _displayName;
          _profilePhotoUrl =
              data['profile_photo_url'] as String? ?? _profilePhotoUrl;
          GamePrefs.saveProfilePhotoUrl(_profilePhotoUrl);
          notifyListeners();
        },
        onError: (e) {
          debugPrint('User data stream error: $e');
        },
      );
    }

    if (supabaseEnabled && authSuccess) {
      await _refreshSpinState();
    }

    _flushPendingTransactions().catchError((e) {
      debugPrint('Failed to flush pending transactions on load: $e');
    });

    _refreshDailyRewardCooldown();

    _isLoaded = true;
    notifyListeners();
  }

  Future<void> _refreshDailyRewardCooldown() async {
    if (supabaseEnabled && _isOnline && _isAuthenticated) {
      try {
        final remaining = await _rewardService.getDailyRewardCooldown();
        _dailyRewardRemaining = remaining;
        _syncDailyRewardTimer();
        notifyListeners();
        return;
      } catch (e) {
        debugPrint('Failed to refresh daily reward cooldown from server: $e');
      }
    }

    // Local fallback
    final prefs = await SharedPreferences.getInstance();
    final claimedAt = prefs.getInt(_keyDailyRewardClaimedAt);
    if (claimedAt != null) {
      final lastClaimed = DateTime.fromMillisecondsSinceEpoch(claimedAt);
      final cooldownEnd = lastClaimed.add(const Duration(hours: 24));
      final remaining = cooldownEnd.difference(DateTime.now());
      _dailyRewardRemaining = remaining.isNegative ? Duration.zero : remaining;
    } else {
      _dailyRewardRemaining = Duration.zero;
    }
    _syncDailyRewardTimer();
    notifyListeners();
  }

  Future<void> _refreshSpinState() async {
    if (!supabaseEnabled || !_isOnline) return;
    try {
      final state = await _coinService.getSpinState();
      _spinFreeSpins = (state['spins_remaining'] as num?)?.toInt() ?? 3;
      final cooldownMs = (state['cooldown_end'] as num?)?.toInt() ?? 0;
      if (cooldownMs > 0) {
        _spinCooldownRemaining = Duration(milliseconds: cooldownMs);
        _syncSpinCooldownTimer();
        final prefs = await SharedPreferences.getInstance();
        final cooldownEnd = DateTime.now().millisecondsSinceEpoch + cooldownMs;
        await prefs.setInt(_keySpinCooldownEnd, cooldownEnd);
      } else {
        _spinCooldownRemaining = Duration.zero;
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_keySpinCooldownEnd);
        if (_spinFreeSpins == 0) {
          _spinFreeSpins = 3;
          await prefs.setInt(_keySpinFreeSpins, 3);
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to refresh spin state: $e');
    }
  }

  Future<void> updateDisplayName(String name) async {
    if (!supabaseEnabled || !_isOnline) return;
    try {
      await _coinService.updateDisplayName(name);
      _displayName = name;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to update name: $e';
      notifyListeners();
    }
  }

  Future<void> updateProfilePhoto(String? url) async {
    _profilePhotoUrl = url;
    notifyListeners();
    await GamePrefs.saveProfilePhotoUrl(url);

    if (!supabaseEnabled || !_isOnline || !_isAuthenticated) return;
    try {
      await _coinService.updateProfilePhoto(url);
    } catch (e) {
      _errorMessage = 'Failed to update profile photo: $e';
      notifyListeners();
    }
  }

  Future<void> setOnboardingCompleted(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    _isOnboardingCompleted = value;
    await prefs.setBool(_keyOnboardingCompleted, value);
    notifyListeners();
  }

  Future<void> refreshCoins() async {
    if (_pendingCoinOps > 0) return;
    try {
      final data = await _coinService.getUserData();
      if (data.isNotEmpty) {
        final serverBalance = data['balance'] as int? ?? _coins;
        if (serverBalance > _coins) {
          _coins = serverBalance;
        }
        _totalCoinsEarned = data['total_earned'] as int? ?? _totalCoinsEarned;
        _gamesPlayed = data['games_played'] as int? ?? _gamesPlayed;
        _offersCompleted = data['offers_completed'] as int? ?? _offersCompleted;
        _consecutiveDays = data['consecutive_days'] as int? ?? _consecutiveDays;
        _level = data['level'] as int? ?? _level;
        _displayName = data['display_name'] as String? ?? _displayName;
        await GamePrefs.saveCoins(_coins);
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Failed to refresh data: $e';
      notifyListeners();
    }
  }

  Future<int> addCoins(int value, {String source = 'in_app'}) async {
    _coins += value;
    _totalCoinsEarned += value;
    _level = (_totalCoinsEarned / 5000).floor() + 1;
    _pendingCoinOps++;
    notifyListeners();

    final txId = _generateUuidV4();

    if (!supabaseEnabled || !_isOnline || !_isAuthenticated) {
      await GamePrefs.saveCoins(_coins);
      await PendingTransactionService.enqueue({
        'type': 'credit',
        'amount': value,
        'source': source,
        'txId': txId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      _pendingCoinOps--;
      return _coins;
    }
    try {
      final newBalance =
          await _coinService.creditCoins(value, source: source, txId: txId);
      _coins = newBalance;
      notifyListeners();
      await GamePrefs.saveCoins(_coins);
      _pendingCoinOps--;
      return _coins;
    } catch (e) {
      await GamePrefs.saveCoins(_coins);
      await PendingTransactionService.enqueue({
        'type': 'credit',
        'amount': value,
        'source': source,
        'txId': txId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      _errorMessage = 'Failed to sync coins to server: $e';
      notifyListeners();
      _pendingCoinOps--;
      return _coins;
    }
  }

  void optimisticAddCoins(int value) {
    _coins += value;
    _totalCoinsEarned += value;
    _level = (_totalCoinsEarned / 5000).floor() + 1;
    _pendingCoinOps++;
    notifyListeners();
    GamePrefs.saveCoins(_coins);
  }

  void syncBalanceFromServer(int serverBalance) {
    if (serverBalance > _coins) {
      _coins = serverBalance;
      GamePrefs.saveCoins(_coins);
    }
    if (_pendingCoinOps > 0) _pendingCoinOps--;
    notifyListeners();
  }

  void releaseOptimisticOp() {
    if (_pendingCoinOps > 0) {
      _pendingCoinOps--;
      notifyListeners();
    }
  }

  Future<bool> spendCoins(int value, {String rewardTitle = 'redeem'}) async {
    if (_coins < value) return false;

    _coins -= value;
    _pendingCoinOps++;
    notifyListeners();

    final txId = _generateUuidV4();

    if (!supabaseEnabled || !_isOnline || !_isAuthenticated) {
      await GamePrefs.saveCoins(_coins);
      await PendingTransactionService.enqueue({
        'type': 'spend',
        'amount': value,
        'rewardTitle': rewardTitle,
        'txId': txId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      _pendingCoinOps--;
      return true;
    }

    try {
      final newBalance = await _coinService.spendCoins(value,
          rewardTitle: rewardTitle, txId: txId);
      _coins = newBalance;
      notifyListeners();
      await GamePrefs.saveCoins(_coins);
      _pendingCoinOps--;
      return true;
    } catch (e) {
      _coins += value; // Revert optimistic deduction
      _pendingCoinOps--;
      await GamePrefs.saveCoins(_coins);
      await PendingTransactionService.enqueue({
        'type': 'spend',
        'amount': value,
        'rewardTitle': rewardTitle,
        'txId': txId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      _errorMessage = 'Failed to spend coins: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> claimDailyReward() async {
    if (isDailyRewardCoolingDown) return false;

    if (supabaseEnabled && _isOnline && _isAuthenticated) {
      try {
        final result = await _rewardService.claimDailyReward();
        final data = result;
        if (data['success'] == true) {
          final amount = data['amount'] as int? ?? 0;
          final balance = data['balance'] as int? ?? (_coins + amount);
          _coins = balance;
          _totalCoinsEarned += amount;
          _level = (_totalCoinsEarned / 5000).floor() + 1;
          _consecutiveDays =
              data['consecutive_days'] as int? ?? _consecutiveDays;
          notifyListeners();
        }
        await _refreshDailyRewardCooldown();
        return data['success'] == true;
      } catch (e) {
        _errorMessage = 'Failed to claim daily reward: $e';
        notifyListeners();
        return false;
      }
    }

    // Local offline fallback
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    await prefs.setInt(_keyDailyRewardClaimedAt, now.millisecondsSinceEpoch);
    _dailyRewardRemaining = const Duration(hours: 24);
    _syncDailyRewardTimer();
    _coins += 100;
    _totalCoinsEarned += 100;
    _level = (_totalCoinsEarned / 5000).floor() + 1;
    await GamePrefs.saveCoins(_coins);
    notifyListeners();
    return true;
  }

  Future<void> addFreeSpin() async {
    _spinFreeSpins++;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySpinFreeSpins, _spinFreeSpins);
  }

  Future<bool> consumeLocalSpin() async {
    if (_spinFreeSpins <= 0) return false;
    _spinFreeSpins--;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySpinFreeSpins, _spinFreeSpins);
    return true;
  }

  Future<bool> useSpin() async {
    if (!supabaseEnabled || !_isOnline) return false;
    try {
      final result = await _coinService.useSpin();
      if (result['success'] == true) {
        _spinFreeSpins = result['spins_remaining'] as int? ?? 0;
        final cooldownMs = (result['cooldown_end'] as num?)?.toInt() ?? 0;
        if (cooldownMs > 0) {
          _spinCooldownRemaining = Duration(milliseconds: cooldownMs);
          _syncSpinCooldownTimer();
          final prefs = await SharedPreferences.getInstance();
          final cooldownEnd =
              DateTime.now().millisecondsSinceEpoch + cooldownMs;
          await prefs.setInt(_keySpinCooldownEnd, cooldownEnd);
        } else {
          _spinCooldownRemaining = Duration.zero;
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove(_keySpinCooldownEnd);
          if (_spinFreeSpins == 0) {
            _spinFreeSpins = 3;
            await prefs.setInt(_keySpinFreeSpins, 3);
          }
        }
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = 'Failed to use spin: $e';
      notifyListeners();
      return false;
    }
  }

  void _syncSpinCooldownTimer() {
    _spinCooldownTimer?.cancel();
    if (!isSpinOnCooldown) return;

    _spinCooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_spinCooldownRemaining.inSeconds > 0) {
        _spinCooldownRemaining =
            _spinCooldownRemaining - const Duration(seconds: 1);
      } else {
        _spinCooldownRemaining = Duration.zero;
        _spinCooldownTimer?.cancel();
        // Sync from server when cooldown expires locally (fire-and-forget)
        _refreshSpinState().catchError((e) {
          debugPrint('Failed to refresh spin state on timer expiry: $e');
        });
      }
      try {
        notifyListeners();
      } catch (_) {
        // Widget may have been disposed; ignore.
      }
    });
  }

  void _syncDailyRewardTimer() {
    _dailyRewardTimer?.cancel();
    if (!isDailyRewardCoolingDown) return;

    _dailyRewardTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_dailyRewardRemaining.inSeconds > 0) {
        _dailyRewardRemaining =
            _dailyRewardRemaining - const Duration(seconds: 1);
      } else {
        _dailyRewardRemaining = Duration.zero;
        _dailyRewardTimer?.cancel();
      }
      try {
        notifyListeners();
      } catch (_) {
        // Widget may have been disposed; ignore.
      }
    });
  }

  Future<void> incrementOffersCompleted() async {
    _offersCompleted++;
    notifyListeners();

    if (!supabaseEnabled || !_isOnline || !_isAuthenticated) {
      return;
    }
    try {
      await _coinService.incrementUserStat('offers_completed');
    } catch (e) {
      debugPrint('Failed to increment offers completed: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchRedeemedRewards() async {
    if (!supabaseEnabled || !_isOnline) return [];
    try {
      return await _coinService.getRedeemedRewards();
    } catch (e) {
      debugPrint('Failed to fetch redeemed rewards: $e');
      return [];
    }
  }

  String _generateUuidV4() {
    final random = Random();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  bool _shouldDiscardPendingTxError(String msg) {
    return msg.contains('duplicate') ||
        msg.contains('conflict') ||
        msg.contains('already exists') ||
        msg.contains('unique constraint') ||
        msg.contains('already processed') ||
        msg.contains('insufficient') ||
        msg.contains('cap reached') ||
        msg.contains('validation failed');
  }

  Future<void> _flushPendingTransactions() async {
    if (!supabaseEnabled || !_isOnline || !_isAuthenticated) return;

    final queue = await PendingTransactionService.getQueue();
    if (queue.isEmpty) return;

    final remaining = <Map<String, dynamic>>[];

    for (final tx in queue) {
      try {
        final type = tx['type'] as String?;
        switch (type) {
          case 'credit':
            await _coinService.creditCoins(
              tx['amount'] as int,
              source: tx['source'] as String,
              txId: tx['txId'] as String,
            );
            break;
          case 'spend':
            await _coinService.spendCoins(
              tx['amount'] as int,
              rewardTitle: tx['rewardTitle'] as String,
              txId: tx['txId'] as String,
            );
            break;
          case 'game_result':
            final result = await _gameService.submitGameResult(
              gameName: tx['gameName'] as String,
              score: tx['score'] as int,
              durationSeconds: tx['durationSeconds'] as int,
              sessionId: tx['sessionId'] as String,
              originalScore: tx['originalScore'] as int? ?? 0,
              multiplier: tx['multiplier'] as int? ?? 1,
              queueOnFailure: false,
            );
            if (result['success'] != true) {
              final msg =
                  (result['error'] as String? ?? 'game submission failed')
                      .toLowerCase();
              final retryable = result['retryable'] == true;
              if (!_shouldDiscardPendingTxError(msg) && retryable) {
                remaining.add(tx);
              }
            }
            break;
        }
      } catch (e) {
        final msg = e.toString().toLowerCase();
        if (_shouldDiscardPendingTxError(msg)) {
          // Safe to discard – server already has this transaction.
        } else {
          remaining.add(tx);
        }
      }
    }

    await PendingTransactionService.setQueue(remaining);

    if (queue.length != remaining.length) {
      await refreshCoins();
    }
  }

  @override
  void dispose() {
    _dailyRewardTimer?.cancel();
    _spinCooldownTimer?.cancel();
    _connectivitySubscription?.cancel();
    _balanceSub?.cancel();
    super.dispose();
  }
}
