import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rbx_rewards/widgets/game_prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GamePrefs Scratch Card Limits Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Initial free scratches is 3', () async {
      expect(GamePrefs.maxScratchesPerDay, equals(3));
      expect(GamePrefs.maxFreeScratchesPerDay, equals(3));
      final remaining = await GamePrefs.getScratchesRemaining();
      expect(remaining, equals(3));
    });

    test('Decrementing scratches reduces available count', () async {
      await GamePrefs.decrementScratchesRemaining();
      var remaining = await GamePrefs.getScratchesRemaining();
      expect(remaining, equals(2));

      await GamePrefs.decrementScratchesRemaining();
      remaining = await GamePrefs.getScratchesRemaining();
      expect(remaining, equals(1));

      await GamePrefs.decrementScratchesRemaining();
      remaining = await GamePrefs.getScratchesRemaining();
      expect(remaining, equals(0));

      // Does not decrement below 0
      await GamePrefs.decrementScratchesRemaining();
      remaining = await GamePrefs.getScratchesRemaining();
      expect(remaining, equals(0));
    });

    test('Incrementing scratches increases available count after watching ad', () async {
      // Consume all 3
      await GamePrefs.decrementScratchesRemaining();
      await GamePrefs.decrementScratchesRemaining();
      await GamePrefs.decrementScratchesRemaining();
      expect(await GamePrefs.getScratchesRemaining(), equals(0));

      // User watches ad -> increments
      await GamePrefs.incrementScratchesRemaining();
      expect(await GamePrefs.getScratchesRemaining(), equals(1));

      await GamePrefs.incrementScratchesRemaining();
      expect(await GamePrefs.getScratchesRemaining(), equals(2));
    });

    test('Initial extra scratches remaining is 8', () async {
      expect(GamePrefs.maxExtraScratchesPerDay, equals(8));
      final remaining = await GamePrefs.getExtraScratchesRemaining();
      expect(remaining, equals(8));
    });

    test('Decrementing extra scratches reduces ad count', () async {
      await GamePrefs.decrementExtraScratchesRemaining();
      var remaining = await GamePrefs.getExtraScratchesRemaining();
      expect(remaining, equals(7));

      for (int i = 0; i < 7; i++) {
        await GamePrefs.decrementExtraScratchesRemaining();
      }
      remaining = await GamePrefs.getExtraScratchesRemaining();
      expect(remaining, equals(0));

      // Does not decrement below 0
      await GamePrefs.decrementExtraScratchesRemaining();
      remaining = await GamePrefs.getExtraScratchesRemaining();
      expect(remaining, equals(0));
    });
  });
}
