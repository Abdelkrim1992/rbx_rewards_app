import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rbx_rewards/widgets/game_prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GamePrefs Play Count Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Initial play count is 0', () async {
      final count = await GamePrefs.getGamePlayCount('test_game');
      expect(count, equals(0));
    });

    test('Incrementing increases count by 1', () async {
      await GamePrefs.incrementGamePlayCount('test_game');
      var count = await GamePrefs.getGamePlayCount('test_game');
      expect(count, equals(1));

      await GamePrefs.incrementGamePlayCount('test_game');
      count = await GamePrefs.getGamePlayCount('test_game');
      expect(count, equals(2));
    });

    test('Counts are tracked independently per game key', () async {
      await GamePrefs.incrementGamePlayCount('game_one');
      await GamePrefs.incrementGamePlayCount('game_two');
      await GamePrefs.incrementGamePlayCount('game_two');

      final countOne = await GamePrefs.getGamePlayCount('game_one');
      final countTwo = await GamePrefs.getGamePlayCount('game_two');

      expect(countOne, equals(1));
      expect(countTwo, equals(2));
    });

    test('Counts are checked correctly modulo 3', () async {
      await GamePrefs.incrementGamePlayCount('my_game'); // 1
      var count = await GamePrefs.getGamePlayCount('my_game');
      expect(count % 3 == 0, isFalse);

      await GamePrefs.incrementGamePlayCount('my_game'); // 2
      count = await GamePrefs.getGamePlayCount('my_game');
      expect(count % 3 == 0, isFalse);

      await GamePrefs.incrementGamePlayCount('my_game'); // 3
      count = await GamePrefs.getGamePlayCount('my_game');
      expect(count % 3 == 0, isTrue);

      await GamePrefs.incrementGamePlayCount('my_game'); // 4
      count = await GamePrefs.getGamePlayCount('my_game');
      expect(count % 3 == 0, isFalse);
    });
  });

  group('GamePrefs Best Score Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Initial best score is 0', () async {
      final score = await GamePrefs.getFlappyBestScore();
      expect(score, equals(0));
    });

    test('Saving higher score updates best score', () async {
      await GamePrefs.saveFlappyBestScore(10);
      var score = await GamePrefs.getFlappyBestScore();
      expect(score, equals(10));

      await GamePrefs.saveFlappyBestScore(25);
      score = await GamePrefs.getFlappyBestScore();
      expect(score, equals(25));
    });

    test('Saving lower score does not overwrite higher best score', () async {
      await GamePrefs.saveFlappyBestScore(50);
      await GamePrefs.saveFlappyBestScore(30);
      final score = await GamePrefs.getFlappyBestScore();
      expect(score, equals(50));
    });
  });
}
