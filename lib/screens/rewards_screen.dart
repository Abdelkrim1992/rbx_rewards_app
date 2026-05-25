import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/refreshable_scroll.dart';

class RewardsScreen extends StatefulWidget {
  final Function(int) onNavTap;

  const RewardsScreen({super.key, required this.onNavTap});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _historyLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final appState = context.read<AppState>();
    final data = await appState.fetchRedeemedRewards();
    if (mounted) {
      setState(() {
        _history = data;
        _historyLoading = false;
      });
    }
  }

  int _parseRewardCost(String cost) {
    return int.tryParse(cost.replaceAll(',', '')) ?? 0;
  }

  String _sanitizeRewardTitle(String title) {
    // Replace $ with USD and remove other potentially problematic characters
    return title
        .replaceAll(r'$', 'USD ')
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim();
  }

  Future<void> _redeemReward(_RewardData reward) async {
    final cost = _parseRewardCost(reward.cost);
    final appState = context.read<AppState>();
    final balance = appState.coins;

    if (balance < cost) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'You need ${cost - balance} more RBX Coins to redeem ${reward.title}.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Show confirmation dialog first
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (_) => _RedeemConfirmDialog(
        rewardTitle: reward.title,
        cost: cost,
      ),
    );

    if (confirmed != true || !mounted) return;

    // Show success popup immediately after confirmation
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black87,
        builder: (_) => RedeemSuccessDialog(rewardTitle: reward.title),
      );
    }

    // Sanitize the reward title for backend
    final sanitizedTitle = _sanitizeRewardTitle(reward.title);

    // Perform the redemption in the background
    final success = await appState.spendCoins(cost, rewardTitle: sanitizedTitle);
    
    if (!mounted) return;

    if (!success) {
      // Close the success dialog
      Navigator.of(context).pop();
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            appState.errorMessage ??
                'Failed to redeem ${reward.title}. Please try again.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      appState.clearError();
      return;
    }

    // Reload history in the background (dialog is still open)
    await _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    final rewards = [
      const _RewardData(
        assetPath: 'assets/images/robux_coins.png',
        title: '1,000 RBX Coins',
        description: 'Instant coin boost to your balance',
        cost: '500',
        bgColor: Color(0xFFFFCC44),
      ),
      const _RewardData(
        assetPath: 'assets/images/open_chest_quick_actions.png',
        title: 'Premium Chest',
        description: 'Mystery loot box with random rewards',
        cost: '1,500',
        bgColor: Color(0xFF9B5CFF),
      ),
      const _RewardData(
        assetPath: 'assets/images/robux_coins.png',
        title: '5,000 RBX Coins',
        description: 'Big coin pack for serious grinders',
        cost: '2,000',
        bgColor: Color(0xFF2ECC71),
      ),
      const _RewardData(
        icon: Icons.card_giftcard,
        title: 'Roblox Gift Card \$5',
        description: 'Official Roblox digital gift card',
        cost: '10,000',
        bgColor: Color(0xFF1A1A2E),
      ),
      const _RewardData(
        assetPath: 'assets/images/profile_image.png',
        title: 'Avatar Skin Pack',
        description: 'Exclusive premium avatar skins',
        cost: '3,000',
        bgColor: Color(0xFFFF6B6B),
      ),
      const _RewardData(
        icon: Icons.card_giftcard,
        title: 'Roblox Gift Card \$10',
        description: 'Official Roblox digital gift card',
        cost: '20,000',
        bgColor: Color(0xFF6A2FD8),
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
              child: RefreshableScrollView(
                padding: const EdgeInsets.only(top: 12, bottom: 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RbxAppHeader(onNavTap: widget.onNavTap),
                    // Balance widget
                    Padding(
                      padding: const EdgeInsets.only(
                        left: AppLayout.screenPadding,
                        right: AppLayout.screenPadding,
                        top: 5,
                      ),
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
                    const SizedBox(height: AppLayout.sectionSpacing),

                    // Redemption History
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppLayout.screenPadding),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Redemption History',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryText,
                            ),
                          ),
                          if (_historyLoading)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppLayout.sectionSpacing),
                    if (_history.isEmpty && !_historyLoading)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppLayout.screenPadding),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FA),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFF1F5F9)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.history,
                                  color: AppColors.secondaryText, size: 20),
                              SizedBox(width: 12),
                              Text(
                                'No redemptions yet.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.secondaryText,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppLayout.screenPadding),
                        itemCount: _history.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (ctx, i) {
                          final item = _history[i];
                          return _RedemptionHistoryItem(data: item);
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
        gradient: AppColors.primaryGradient,
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
  final String? assetPath;
  final IconData? icon;
  final String title;
  final String description;
  final String cost;
  final Color bgColor;

  const _RewardData({
    this.assetPath,
    this.icon,
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
                  child: data.assetPath != null
                      ? Image.asset(
                          data.assetPath!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Icon(
                            data.icon ?? Icons.card_giftcard,
                            color: data.bgColor,
                            size: 36,
                          ),
                        )
                      : Icon(
                          data.icon ?? Icons.card_giftcard,
                          color: data.bgColor,
                          size: 36,
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
                _RedeemButton(
                  canRedeem: canRedeem,
                  onTap: onRedeem,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RedeemButton extends StatefulWidget {
  final bool canRedeem;
  final VoidCallback onTap;

  const _RedeemButton({required this.canRedeem, required this.onTap});

  @override
  State<_RedeemButton> createState() => _RedeemButtonState();
}

class _RedeemButtonState extends State<_RedeemButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.92),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: Container(
          width: 75,
          height: 30,
          decoration: BoxDecoration(
            gradient: widget.canRedeem ? AppColors.primaryGradient : null,
            color: widget.canRedeem ? null : const Color(0xFFE5E7EB),
            borderRadius: BorderRadius.circular(10),
            boxShadow: widget.canRedeem
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
              widget.canRedeem ? 'Redeem' : 'Locked',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color:
                    widget.canRedeem ? Colors.white : AppColors.secondaryText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RedemptionHistoryItem extends StatelessWidget {
  final Map<String, dynamic> data;

  const _RedemptionHistoryItem({required this.data});

  Color _statusColor(String status) {
    switch (status) {
      case 'fulfilled':
      case 'success':
        return const Color(0xFF27AE60);
      case 'rejected':
      case 'cancelled':
        return const Color(0xFFE74C3C);
      case 'pending':
      default:
        return const Color(0xFFFF9800);
    }
  }

  Color _statusBgColor(String status) {
    switch (status) {
      case 'fulfilled':
      case 'success':
        return const Color(0xFFE8F5E9);
      case 'rejected':
      case 'cancelled':
        return const Color(0xFFFFEBEE);
      case 'pending':
      default:
        return const Color(0xFFFFF3E0);
    }
  }

  String _formatDate(String? raw) {
    if (raw == null) return '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      if (diff.inHours == 0) return '${diff.inMinutes}m ago';
      return '${diff.inHours}h ago';
    }
    if (diff.inDays == 1) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final title = data['reward_title'] as String? ?? 'Unknown';
    final cost = (data['cost'] as num?)?.toInt() ?? 0;
    final status = data['status'] as String? ?? 'pending';
    final createdAt = data['created_at'] as String?;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.card_giftcard,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$cost RBX',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _statusBgColor(status),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status == 'fulfilled'
                      ? 'Success'
                      : status[0].toUpperCase() + status.substring(1),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _statusColor(status),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatDate(createdAt),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.mutedText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Redeem Confirm Popup ─────────────────────────────────────────────

class _RedeemConfirmDialog extends StatelessWidget {
  final String rewardTitle;
  final int cost;

  const _RedeemConfirmDialog({
    required this.rewardTitle,
    required this.cost,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.25),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
            const BoxShadow(
              color: Colors.black12,
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFFF9800),
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Confirm Redemption',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Are you sure you want to redeem',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.secondaryText,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              rewardTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'for $cost RBX Coins?',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.secondaryText,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(false),
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(true),
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Confirm',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Redeem Success Popup ─────────────────────────────────────────────

class RedeemSuccessDialog extends StatelessWidget {
  final String rewardTitle;

  const RedeemSuccessDialog({super.key, required this.rewardTitle});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.25),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
            const BoxShadow(
              color: Colors.black12,
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Celebration icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.celebration,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),

            // Title
            const Text(
              'Congratulations!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 8),

            // Reward name
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Text(
                rewardTitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 48h message
            const Text(
              'You will receive your reward within 48 hours.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.secondaryText,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),

            // Close button
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Awesome!',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
