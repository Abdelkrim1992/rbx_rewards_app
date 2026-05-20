import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/bottom_nav.dart';

class RewardsScreen extends StatefulWidget {
  final Function(int) onNavTap;

  const RewardsScreen({super.key, required this.onNavTap});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  int _parseRewardCost(String cost) {
    return int.tryParse(cost.replaceAll(',', '')) ?? 0;
  }

  Future<void> _redeemReward(_RewardData reward) async {
    final cost = _parseRewardCost(reward.cost);
    final appState = context.read<AppState>();
    final balance = appState.coins;

    if (balance < cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'You need ${cost - balance} more RBX Coins to redeem ${reward.title}.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final success = await appState.spendCoins(cost);
    if (!success) return;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${reward.title} redeemed successfully! 🎉'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rewards = [
      _RewardData(
        imageUrl:
            'https://www.figma.com/api/mcp/asset/a52090da-83a4-4bf9-8b86-0b1f96d18452',
        title: 'Roblox Gift Card',
        description: 'Get official Roblox gift…',
        cost: '5,000',
        bgColor: const Color(0xFF1A1A2E),
      ),
      _RewardData(
        imageUrl:
            'https://www.figma.com/api/mcp/asset/9317869a-2a98-4f56-ae36-d822a541fd90',
        title: 'Gold Helmet Avatar',
        description: 'Exclusive golden avatar…',
        cost: '5,000',
        bgColor: const Color(0xFFFFCC44),
      ),
      _RewardData(
        imageUrl:
            'https://www.figma.com/api/mcp/asset/ef690607-7ba6-4db4-a851-b0dbca513fa0',
        title: 'Logic Gem Token',
        description: 'Rare collectible token…',
        cost: '5,000',
        bgColor: const Color(0xFF2ECC71),
      ),
      _RewardData(
        imageUrl:
            'https://www.figma.com/api/mcp/asset/6ffe8337-cad6-4012-9285-ac241b3ea726',
        title: 'Treasure Chest Box',
        description: 'Mystery reward chest…',
        cost: '5,000',
        bgColor: const Color(0xFF9B5CFF),
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 20, bottom: 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RbxAppHeader(onNavTap: widget.onNavTap),
                    // Balance widget
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppLayout.screenPadding),
                      child: _BalanceWidget(
                          balance: context.watch<AppState>().coins),
                    ),
                    const SizedBox(height: AppLayout.sectionSpacing),

                    // Redeem Rewards header
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppLayout.screenPadding),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Redeem Rewards',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryText,
                            ),
                          ),
                          Image.network(
                            AppAssets.chevronRight,
                            width: 48,
                            height: 48,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const SizedBox(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppLayout.sectionSpacing),
                    // Reward list
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppLayout.screenPadding),
                      itemCount: rewards.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (ctx, i) {
                        final reward = rewards[i];
                        final appState = context.watch<AppState>();
                        return _RewardItem(
                          data: reward,
                          canRedeem:
                              appState.coins >= _parseRewardCost(reward.cost),
                          onRedeem: () => _redeemReward(reward),
                        );
                      },
                    ),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: RbxBottomNav(currentIndex: 3, onTap: widget.onNavTap),
        ),
      ),
    );
  }
}

class _BalanceWidget extends StatelessWidget {
  final int balance;

  const _BalanceWidget({required this.balance});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color.fromARGB(255, 195, 176, 255).withValues(alpha: 0.85),
            const Color.fromARGB(255, 137, 91, 255),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x226035EE),
            blurRadius: 15,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Decorative sparkles

          Row(
            children: [
              Image.asset(
                AppAssets.goldRbxCoin,
                width: 45,
                height: 45,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.monetization_on,
                  size: 45,
                  color: Color(0xFFFFCC44),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$balance',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Your RBX Balance',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 120,
                height: 90,
                child: Image.asset(
                  AppAssets.balanceWidgetImage,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                      Icons.account_balance_wallet,
                      size: 60,
                      color: Colors.white54),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RewardData {
  final String imageUrl;
  final String title;
  final String description;
  final String cost;
  final Color bgColor;

  const _RewardData({
    required this.imageUrl,
    required this.title,
    required this.description,
    required this.cost,
    required this.bgColor,
  });
}

class _RewardItem extends StatelessWidget {
  final _RewardData data;
  final bool canRedeem;
  final VoidCallback onRedeem;

  const _RewardItem({
    required this.data,
    required this.canRedeem,
    required this.onRedeem,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 15,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon
          Padding(
            padding: const EdgeInsets.all(8),
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: data.bgColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: data.bgColor.withOpacity(0.3), width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Padding(
                  padding: const EdgeInsets.all(9),
                  child: Image.network(
                    data.imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(Icons.card_giftcard,
                        color: data.bgColor, size: 36),
                  ),
                ),
              ),
            ),
          ),
          // Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    data.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Cost & Redeem
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 16, 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              // crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Image.asset(
                      AppAssets.goldCoin,
                      width: 23,
                      height: 23,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.monetization_on,
                        size: 23,
                        color: Color(0xFFFFCC44),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      data.cost,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryText,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: onRedeem,
                  child: Container(
                    width: 75,
                    height: 30,
                    decoration: BoxDecoration(
                      gradient: canRedeem ? AppColors.primaryGradient : null,
                      color: canRedeem ? null : const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: canRedeem
                          ? const [
                              BoxShadow(
                                color: Color(0x446035EE),
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        canRedeem ? 'Redeem' : 'Locked',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: canRedeem
                              ? Colors.white
                              : AppColors.secondaryText,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
