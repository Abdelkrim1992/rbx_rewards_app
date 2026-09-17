import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Production-ready High-Performance Audio Engine for RBX Rewards.
/// Manages preloaded audio pools, low-latency playback, and user audio preferences.
class SoundService {
  static SoundService? _instance;
  static SoundService get instance => _instance ??= SoundService._internal();

  SoundService._internal();

  // Visible for testing to inject custom player or preferences
  @visibleForTesting
  factory SoundService.testInstance({bool enabled = true, AudioPlayer? testPlayer}) {
    final s = SoundService._internal();
    s._soundEnabled = enabled;
    s._isTestMode = true;
    if (testPlayer != null) {
      s._primaryPlayer = testPlayer;
    }
    _instance = s;
    return s;
  }

  static const String prefKey = 'pref_sound_enabled';

  bool _soundEnabled = true;
  bool _initialized = false;
  bool _isTestMode = false;

  AudioPlayer? _primaryPlayer;
  AudioPlayer? _ambientPlayer;
  final List<AudioPlayer> _tickPool = [];
  int _tickPoolIndex = 0;

  bool get isSoundEnabled => _soundEnabled;

  /// Initializes the sound service and loads user preference.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      _soundEnabled = prefs.getBool(prefKey) ?? true;
    } catch (e) {
      debugPrint('SoundService: Could not read audio preference: $e');
    }

    try {
      _primaryPlayer = AudioPlayer();
      await _primaryPlayer?.setPlayerMode(PlayerMode.lowLatency);

      _ambientPlayer = AudioPlayer();
      await _ambientPlayer?.setPlayerMode(PlayerMode.mediaPlayer);

      // Create a small pool of 3 players for rapid wheel ticks / rapid coin impacts
      for (int i = 0; i < 3; i++) {
        final p = AudioPlayer();
        await p.setPlayerMode(PlayerMode.lowLatency);
        _tickPool.add(p);
      }
    } catch (e) {
      // Graceful fallback for test runner / headless environments
      debugPrint('SoundService: AudioPlayer init note: $e');
    }
  }

  /// Toggles sound enabled status and persists to SharedPreferences.
  Future<void> setSoundEnabled(bool enabled) async {
    _soundEnabled = enabled;
    if (!enabled) {
      await stopAll();
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefKey, enabled);
    } catch (e) {
      debugPrint('SoundService: Could not persist audio preference: $e');
    }
  }

  /// Internal helper to safely trigger playback from assets.
  Future<void> _playAsset(String path, {AudioPlayer? customPlayer, double volume = 1.0}) async {
    if (!_soundEnabled) return;

    try {
      final player = customPlayer ?? _primaryPlayer;
      if (player == null) return;
      await player.setVolume(volume);
      await player.stop();
      await player.play(AssetSource(path));
    } catch (e) {
      if (!_isTestMode) {
        debugPrint('SoundService playback error ($path): $e');
      }
    }
  }

  /// Two-tone crystal chime (B5 -> E6) for flying coin balance impact (~0.4s).
  Future<void> playCoin() async {
    await _playAsset('sounds/coin_collect.wav', volume: 0.95);
  }

  /// Alias for [playCoin] for audio event compatibility.
  Future<void> playCoinCollect() => playCoin();

  /// Ascending triumphant major triad with bell harmonics (~1.2s).
  Future<void> playJackpot() async {
    await _playAsset('sounds/jackpot_win.wav', customPlayer: _ambientPlayer, volume: 1.0);
  }

  /// Short, dry acoustic transient at 1800 Hz for Lucky Wheel pegs (~0.02s).
  Future<void> playWheelTick() async {
    if (!_soundEnabled) return;
    if (_tickPool.isEmpty) {
      await _playAsset('sounds/wheel_tick.wav', volume: 0.7);
      return;
    }
    final player = _tickPool[_tickPoolIndex];
    _tickPoolIndex = (_tickPoolIndex + 1) % _tickPool.length;
    await _playAsset('sounds/wheel_tick.wav', customPlayer: player, volume: 0.7);
  }

  /// Heavy mechanical latch click rising into magical resonant chord (~0.8s).
  Future<void> playChestOpen() async {
    await _playAsset('sounds/chest_open.wav', customPlayer: _ambientPlayer, volume: 1.0);
  }

  /// Soft organic wooden tap (450 Hz -> 250 Hz) for buttons and dialog actions (~0.04s).
  Future<void> playButton() async {
    await _playAsset('sounds/button_tap.wav', volume: 0.65);
  }

  /// Smooth downward pitch glide (850 Hz -> 180 Hz) for bubble pops & card flips (~0.05s).
  Future<void> playBubble() async {
    await _playAsset('sounds/bubble_pop.wav', volume: 0.85);
  }

  /// Soft textured paper scratch sound (~0.3s).
  Future<void> playScratch() async {
    await _playAsset('sounds/scratch_rustle.wav', volume: 0.6);
  }

  /// Welcome bonus fanfare — played when the bonus overlay coin entrance animates in.
  Future<void> playWelcomeBonus() async {
    await _playAsset(
      'sounds/welcome_bonus.mp3',
      customPlayer: _ambientPlayer,
      volume: 1.0,
    );
  }

  /// Stops all active sound players.
  Future<void> stopAll() async {
    try {
      await _primaryPlayer?.stop();
      await _ambientPlayer?.stop();
      for (final p in _tickPool) {
        await p.stop();
      }
    } catch (_) {}
  }

  /// Disposes all audio player instances.
  void dispose() {
    _primaryPlayer?.dispose();
    _ambientPlayer?.dispose();
    for (final p in _tickPool) {
      p.dispose();
    }
    _tickPool.clear();
    _initialized = false;
  }
}
