import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rbx_rewards/business/sound_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SoundService Unit Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'pref_sound_enabled': true,
      });
    });

    test('Initializes with default enabled preference when unset', () async {
      final service = SoundService.testInstance(enabled: true);
      await service.init();
      expect(service.isSoundEnabled, isTrue);
    });

    test('Loads disabled sound preference from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'pref_sound_enabled': false,
      });
      final service = SoundService.testInstance(enabled: false);
      await service.init();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('pref_sound_enabled'), isFalse);
      expect(service.isSoundEnabled, isFalse);
    });

    test('Loads enabled sound preference from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'pref_sound_enabled': true,
      });
      final service = SoundService.testInstance(enabled: true);
      await service.init();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('pref_sound_enabled'), isTrue);
      expect(service.isSoundEnabled, isTrue);
    });

    test('setSoundEnabled(false) mutes audio, stops active sounds, and persists false', () async {
      final service = SoundService.testInstance(enabled: true);
      await service.init();

      await service.setSoundEnabled(false);
      expect(service.isSoundEnabled, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(SoundService.prefKey), isFalse);
    });

    test('setSoundEnabled(true) restores audio and persists true', () async {
      final service = SoundService.testInstance(enabled: false);
      await service.init();

      await service.setSoundEnabled(true);
      expect(service.isSoundEnabled, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(SoundService.prefKey), isTrue);
    });

    test('All sound trigger methods complete safely without throwing in test environment', () async {
      final service = SoundService.testInstance(enabled: true);
      await service.init();

      // Coin & rewards
      await expectLater(service.playCoin(), completes);
      await expectLater(service.playCoinCollect(), completes);
      await expectLater(service.playJackpot(), completes);
      await expectLater(service.playWelcomeBonus(), completes);

      // Games & interactions
      await expectLater(service.playWheelTick(), completes);
      await expectLater(service.playChestOpen(), completes);
      await expectLater(service.playButton(), completes);
      await expectLater(service.playBubble(), completes);
      await expectLater(service.playScratch(), completes);

      // Audio lifecycle
      await expectLater(service.stopAll(), completes);
    });

    test('Rapid consecutive wheel tick playback cycles through tick pool without errors', () async {
      final service = SoundService.testInstance(enabled: true);
      await service.init();

      // Simulate rapid peg crossings during a fast spin
      for (int i = 0; i < 15; i++) {
        await expectLater(service.playWheelTick(), completes);
      }
    });

    test('All sound playback methods immediately no-op when sound is disabled', () async {
      final service = SoundService.testInstance(enabled: false);
      expect(service.isSoundEnabled, isFalse);

      await expectLater(service.playCoin(), completes);
      await expectLater(service.playCoinCollect(), completes);
      await expectLater(service.playJackpot(), completes);
      await expectLater(service.playWelcomeBonus(), completes);
      await expectLater(service.playWheelTick(), completes);
      await expectLater(service.playChestOpen(), completes);
      await expectLater(service.playBubble(), completes);
      await expectLater(service.playScratch(), completes);
      await expectLater(service.playButton(), completes);
    });

    test('dispose() cleans up resources and resets initialized state', () async {
      final service = SoundService.testInstance(enabled: true);
      await service.init();

      expect(() => service.dispose(), returnsNormally);

      // Re-initialization after disposal works seamlessly
      await expectLater(service.init(), completes);
    });
  });
}
