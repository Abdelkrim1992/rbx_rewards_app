import 'package:flutter_test/flutter_test.dart';
import 'package:rbx_rewards/models/reward_item.dart';
import 'package:rbx_rewards/presentation/providers/reward_catalog_provider.dart';

void main() {
  group('Phase 2: Reward Catalog Restructuring Tests', () {
    test('defaultCatalog has robux_direct_code as default item with starter_rbx_50c in Robux Voucher category', () {
      final catalog = RewardItem.defaultCatalog;
      expect(catalog.first.id, 'robux_direct_code', reason: 'Robux Direct Voucher must be the default catalog item');
      expect(catalog.first.category, RewardCategory.robuxCode, reason: 'Must be in Robux Voucher category');

      final robuxItem = catalog.firstWhere((item) => item.id == 'robux_direct_code');
      final starterDenom = robuxItem.denominations.firstWhere(
        (denom) => denom.id == 'starter_rbx_50c',
        orElse: () => throw StateError('starter_rbx_50c not found in catalog'),
      );

      expect(robuxItem.denominations.first.id, 'starter_rbx_50c', reason: 'starter_rbx_50c must be the first denomination');
      expect(starterDenom.coinCost, 4500);
      expect(starterDenom.usdAmount, 0.50);
      expect(starterDenom.robuxAmount, 40);
      expect(starterDenom.isOneTimeStarter, isTrue);
      expect(starterDenom.shortLabel, '40 R\$');
    });

    test('no denominations in defaultCatalog have coinCost below 4,500 (no active 1,000 test vouchers)', () {
      final catalog = RewardItem.defaultCatalog;

      // Verify test_reward_voucher is removed
      final hasTestVoucher = catalog.any((item) => item.id == 'test_reward_voucher');
      expect(hasTestVoucher, isFalse);

      for (final item in catalog) {
        for (final denom in item.denominations) {
          expect(
            denom.coinCost,
            greaterThanOrEqualTo(4500),
            reason: 'Denomination ${denom.id} in ${item.id} has cost ${denom.coinCost} < 4500',
          );
          expect(denom.id, isNot('rbx_card_1k_test'));
          expect(denom.id, isNot('robux_code_1k_test'));
          expect(denom.id, isNot('test_voucher_1000'));
        }
      }
    });

    test('re-scaled denominations match Phase 2 specification', () {
      final catalog = RewardItem.defaultCatalog;
      final giftCardItem = catalog.firstWhere((item) => item.id == 'roblox_gift_card');

      final card3 = giftCardItem.denominations.firstWhere((d) => d.id == 'rbx_card_3');
      expect(card3.coinCost, 24000, reason: r'$3 card must be re-scaled to 24,000 coins');
      expect(card3.robuxAmount, 240);

      final card5 = giftCardItem.denominations.firstWhere((d) => d.id == 'rbx_card_5');
      expect(card5.coinCost, 38000, reason: r'$5 card must be re-scaled to 38,000 coins');
      expect(card5.robuxAmount, 400);

      final card10 = giftCardItem.denominations.firstWhere((d) => d.id == 'rbx_card_10');
      expect(card10.coinCost, 72000, reason: r'$10 card must be re-scaled to 72,000 coins');
      expect(card10.robuxAmount, 800);
    });

    test('GoalRewardState.defaultGoal defaults to Starter Reward (4,500 coins / 40 Robux)', () {
      const defaultGoal = GoalRewardState.defaultGoal;
      expect(defaultGoal.targetCoins, 4500);
      expect(defaultGoal.label, '40 R\$');
      expect(defaultGoal.title, contains('Starter Robux'));
    });

    test('500 coins welcome bonus provides 11% endowed progress towards 4,500 coins starter goal', () {
      const welcomeBonus = 500;
      const targetCoins = 4500;

      const progress = welcomeBonus / targetCoins;
      final percent = (progress * 100).toInt();
      const remaining = targetCoins - welcomeBonus;

      expect(percent, 11);
      expect(remaining, 4000);
      expect((progress * 100).toStringAsFixed(1), '11.1');
    });

    test('formattedCost outputs comma-separated string for denominations', () {
      final catalog = RewardItem.defaultCatalog;
      final robuxItem = catalog.firstWhere((item) => item.id == 'robux_direct_code');
      final giftCardItem = catalog.firstWhere((item) => item.id == 'roblox_gift_card');

      final starter = robuxItem.denominations.firstWhere((d) => d.id == 'starter_rbx_50c');
      expect(starter.formattedCost, '4,500');

      final card3 = giftCardItem.denominations.firstWhere((d) => d.id == 'rbx_card_3');
      expect(card3.formattedCost, '24,000');
    });
  });
}
