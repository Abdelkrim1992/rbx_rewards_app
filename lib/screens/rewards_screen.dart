import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/bottom_nav.dart';

class RewardsScreen extends StatelessWidget {
  final Function(int) onNavTap;

  const RewardsScreen({super.key, required this.onNavTap});

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
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    const RbxAppHeader(),
                    // Balance widget
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppLayout.screenPadding),
                      child: _BalanceWidget(),
                    ),
                    const SizedBox(height: AppLayout.sectionSpacing),

                    // Redeem Rewards header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppLayout.screenPadding),
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

                    // Reward list
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: AppLayout.screenPadding),
                      itemCount: rewards.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (ctx, i) => _RewardItem(data: rewards[i]),
                    ),
                    const SizedBox(height: AppLayout.sectionSpacing),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: RbxBottomNav(currentIndex: 2, onTap: onNavTap),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 136,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.85),
            AppColors.primaryLight,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x336035EE),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative sparkles
          Positioned(
            right: 12,
            top: 8,
            child: const Text('✨', style: TextStyle(fontSize: 18)),
          ),
          Positioned(
            right: 60,
            bottom: 12,
            child: const Text('✨', style: TextStyle(fontSize: 12)),
          ),
          // Wallet image placeholder
          Positioned(
            right: 20,
            top: 9,
            child: Container(
              width: 100,
              height: 118,
              child: Image.network(
                AppAssets.purpleGiftBox,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.account_balance_wallet,
                        size: 80, color: Colors.white54),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Image.network(
                  AppAssets.goldRbxCoin,
                  width: 55,
                  height: 60,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.monetization_on,
                    size: 55,
                    color: Color(0xFFFFCC44),
                  ),
                ),
                const SizedBox(width: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text(
                      '12,450',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.8,
                      ),
                    ),
                    Text(
                      'Your RBX Balance',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      'RBX Coins',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ],
            ),
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

  const _RewardItem({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon
          Padding(
            padding: const EdgeInsets.all(8),
            child: Container(
              width: 72,
              height: 72,
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
                    errorBuilder: (_, __, ___) =>
                        Icon(Icons.card_giftcard, color: data.bgColor, size: 36),
                  ),
                ),
              ),
            ),
          ),
          // Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 0, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    data.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.description,
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
            padding: const EdgeInsets.fromLTRB(0, 6, 12, 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Image.network(
                      AppAssets.goldCoin,
                      width: 16,
                      height: 16,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.monetization_on,
                        size: 16,
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
                Container(
                  width: 81,
                  height: 30,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x446035EE),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'Redeem',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
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
