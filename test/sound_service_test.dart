import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rbx_rewards/business/sound_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SoundService Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'pref_sound_enabled': true,
      });
    });

    test('Initializes with default enabled preference', () async {
      final service = SoundService.testInstance(enabled: true);
      await service.init();
      expect(service.isSoundEnabled, isTrue);
    });

    test('Loads disabled sound preference from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'pref_sound_enabled': false,
      });
      final service = SoundService.testInstance(enabled: false);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('pref_sound_enabled'), isFalse);
      expect(service.isSoundEnabled, isFalse);
    });

    test('setSoundEnabled toggles state and updates SharedPreferences', () async {
      final service = SoundService.testInstance(enabled: true);
      await service.init();
      
      await service.setSoundEnabled(false);
      expect(service.isSoundEnabled, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('pref_sound_enabled'), isFalse);

      await service.setSoundEnabled(true);
      expect(service.isSoundEnabled, isTrue);
      expect(prefs.getBool('pref_sound_enabled'), isTrue);
    });

    test('All sound playback methods execute safely without unhandled exceptions', () async {
      final service = SoundService.testInstance(enabled: true);
      await service.init();

      await expectLater(service.playCoin(), completes);
      await expectLater(service.playJackpot(), completes);
      await expectLater(service.playWheelTick(), completes);
      await expectLater(service.playChestOpen(), completes);
      await expectLater(service.playButton(), completes);
      await expectLater(service.playBubble(), completes);
      await expectLater(service.playScratch(), completes);
      await expectLater(service.playWelcomeBonus(), completes);
      await expectLater(service.stopAll(), completes);
    });

    test('Playback methods no-op immediately when sound is disabled', () async {
      final service = SoundService.testInstance(enabled: false);
      expect(service.isSoundEnabled, isFalse);

      // Should return immediately without invoking players
      await expectLater(service.playCoin(), completes);
      await expectLater(service.playWheelTick(), completes);
      await expectLater(service.playWelcomeBonus(), completes);
    });
  });
}
