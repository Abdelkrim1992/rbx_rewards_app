import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum RewardCategory {
  giftCard,
  robuxCode,
}

class RewardDenomination {
  final String id;
  final String label;
  final String shortLabel;
  final double? usdAmount;
  final int? robuxAmount;
  final int coinCost;
  final bool inStock;

  const RewardDenomination({
    required this.id,
    required this.label,
    required this.shortLabel,
    this.usdAmount,
    this.robuxAmount,
    required this.coinCost,
    this.inStock = true,
  });

  String get formattedCost {
    return coinCost.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}

class RewardItem {
  final String id;
  final String title;
  final String subtitle;
  final String description;
  final RewardCategory category;
  final String assetPath;
  final Color bgColor;
  final int deliveryHours;
  final List<RewardDenomination> denominations;
  final String redeemInstructions;

  const RewardItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.category,
    required this.assetPath,
    required this.bgColor,
    this.deliveryHours = 24,
    required this.denominations,
    required this.redeemInstructions,
  });

  int get minCost => denominations.isEmpty ? 0 : denominations.first.coinCost;
  int get maxCost => denominations.isEmpty ? 0 : denominations.last.coinCost;

  static List<RewardItem> get defaultCatalog => [
        const RewardItem(
          id: 'roblox_gift_card',
          title: 'Roblox Digital Gift Card',
          subtitle: 'Official USD Prepaid Card',
          description:
              'Redeemable for Robux or a Roblox Premium subscription on Roblox.com.',
          category: RewardCategory.giftCard,
          assetPath: AppAssets.roblox5UsdCard,
          bgColor: Color(0xFF6035EE),
          deliveryHours: 24,
          redeemInstructions:
              '1. Go to roblox.com/redeem in your web browser.\n'
              '2. Log in to your Roblox account.\n'
              '3. Enter your unique PIN code from the Claimed Codes tab.\n'
              '4. Click Redeem to credit your account immediately!',
          denominations: [
            RewardDenomination(
              id: 'rbx_card_3',
              label: r'$3 Roblox Gift Card',
              shortLabel: r'$3 USD',
              usdAmount: 3.0,
              robuxAmount: 240,
              coinCost: 20000,
            ),
            RewardDenomination(
              id: 'rbx_card_5',
              label: r'$5 Roblox Gift Card',
              shortLabel: r'$5 USD',
              usdAmount: 5.0,
              robuxAmount: 400,
              coinCost: 40000,
            ),
            RewardDenomination(
              id: 'rbx_card_10',
              label: r'$10 Roblox Gift Card',
              shortLabel: r'$10 USD',
              usdAmount: 10.0,
              robuxAmount: 800,
              coinCost: 70000,
            ),
            RewardDenomination(
              id: 'rbx_card_25',
              label: r'$25 Roblox Gift Card',
              shortLabel: r'$25 USD',
              usdAmount: 25.0,
              robuxAmount: 2000,
              coinCost: 160000,
            ),
          ],
        ),
        const RewardItem(
          id: 'robux_direct_code',
          title: 'Robux Direct Voucher',
          subtitle: 'Direct Robux PIN Code',
          description:
              'Adds Robux currency directly to your Roblox avatar balance without needing a credit card.',
          category: RewardCategory.robuxCode,
          assetPath: AppAssets.roblox10UsdCard,
          bgColor: Color(0xFF2ECC71),
          deliveryHours: 24,
          redeemInstructions:
              '1. Visit roblox.com/redeem.\n'
              '2. Enter your Robux voucher code.\n'
              '3. Confirm your avatar username.\n'
              '4. Robux will appear in your wallet instantly.',
          denominations: [
            RewardDenomination(
              id: 'robux_code_400',
              label: '400 Robux Voucher',
              shortLabel: '400 R\$',
              robuxAmount: 400,
              coinCost: 35000,
            ),
            RewardDenomination(
              id: 'robux_code_800',
              label: '800 Robux Voucher',
              shortLabel: '800 R\$',
              robuxAmount: 800,
              coinCost: 65000,
            ),
            RewardDenomination(
              id: 'robux_code_1700',
              label: '1,700 Robux Voucher',
              shortLabel: '1,700 R\$',
              robuxAmount: 1700,
              coinCost: 135000,
            ),
          ],
        ),
      ];
}
