import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/screen_title.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/refreshable_scroll.dart';
import '../../widgets/interactive_button.dart';
import '../../core/constants/policy_constants.dart';
import '../../models/reward_item.dart';
import '../providers/coin_provider.dart';
import '../providers/data_providers.dart';
import '../providers/reward_catalog_provider.dart';
import '../providers/connectivity_provider.dart';
import '../providers/user_provider.dart';
import '../providers/providers.dart';
import 'rewards/widgets/rewards_social_proof_ticker.dart';

class RewardsScreen extends ConsumerStatefulWidget {
  final Function(int) onNavTap;

  const RewardsScreen({super.key, required this.onNavTap});

  @override
  ConsumerState<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends ConsumerState<RewardsScreen> {
  int _currentSegment = 0; // 0 = Catalog, 1 = Claimed Codes
  bool _isProcessing = false;
  ScaffoldMessengerState? _scaffoldMessenger;
  final Set<String> _revealedPins = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
  }

  @override
  void dispose() {
    _scaffoldMessenger?.clearSnackBars();
    super.dispose();
  }

  String _sanitizeRewardTitle(String title) {
    return title
        .replaceAll(r'$', 'USD ')
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim();
  }

  Future<void> _handleRedeem(RewardItem item, RewardDenomination denomination) async {
    if (_isProcessing) return;

    // Offline check
    final isOnline = ref.read(connectivityProvider).value ?? true;
    if (!isOnline) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You are offline. Please reconnect to redeem rewards.'),
          backgroundColor: AppColors.purple,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Balance check
    final balance = ref.read(coinProvider);
    if (balance < denomination.coinCost) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You need ${(denomination.coinCost - balance).toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (m) => "${m[1]},")} more RBX Coins to redeem ${item.title}.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Claim dialog prompting for Roblox username & delivery email
    final userProfile = ref.read(userProfileProvider);
    final auth = ref.read(authServiceProvider);
    final initialUsername = userProfile.displayName.isNotEmpty && userProfile.displayName != 'Player'
        ? userProfile.displayName
        : '';
    final initialEmail = auth.currentUser?.email ?? '';

    final claimResult = await showDialog<_ClaimResult?>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (_) => _ClaimRewardDialog(
        rewardTitle: '${item.title} (${denomination.shortLabel})',
        denominationLabel: denomination.label,
        cost: denomination.coinCost,
        defaultUsername: initialUsername,
        defaultEmail: initialEmail,
      ),
    );

    if (claimResult == null || !mounted) return;

    setState(() => _isProcessing = true);

    final fullTitle = '${item.title} - ${denomination.label}';
    final sanitizedTitle = _sanitizeRewardTitle(fullTitle);

    // Process redemption via atomic backend RPC
    final success = await ref
        .read(coinProvider.notifier)
        .spend(denomination.coinCost, sanitizedTitle);

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (success) {
      // Invalidate history to fetch latest record
      ref.invalidate(rewardHistoryProvider);
      ref.invalidate(userProfileStreamProvider);

      await showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black87,
        builder: (_) => RedeemSuccessDialog(
          rewardTitle: '${item.title} (${denomination.shortLabel})',
          onViewClaimedCodes: () {
            Navigator.of(context).pop();
            setState(() => _currentSegment = 1);
          },
        ),
      );
    } else {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Redemption failed. Your coins were not deducted.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _setAsGoal(RewardItem item, RewardDenomination denomination) {
    HapticFeedback.lightImpact();
    ref.read(activeGoalRewardProvider.notifier).setGoal(
          '${item.title} (${denomination.shortLabel})',
          denomination.coinCost,
          denomination.shortLabel,
        );
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.flag_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Set "${denomination.label}" as your target goal!',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(rewardCatalogProvider);
    final selectedCategory = ref.watch(rewardCategoryFilterProvider);
    final historyAsync = ref.watch(rewardHistoryProvider);
    final userCoins = ref.watch(coinProvider);
    final activeGoal = ref.watch(activeGoalRewardProvider);

    final filteredCatalog = selectedCategory == null
        ? catalog
        : catalog.where((item) => item.category == selectedCategory).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: RefreshableScrollView(
                padding: const EdgeInsets.only(top: 2, bottom: 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top App Header
                    RbxAppHeader(
                      onNavTap: (index) {
                        ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
                        widget.onNavTap(index);
                      },
                    ),

                    // Screen title
                    const RbxScreenTitle(
                      title: 'Rewards & Cashout',
                      subtitle: 'Exchange your RBX coins for official Roblox gift cards',
                    ),

                    // Segmented Switcher: [ Redeem Catalog ] vs [ My Claimed Codes ]
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppLayout.screenPadding,
                      ),
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F2F8),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.cardBorder, width: 1.2),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _SegmentTabButton(
                                title: 'Reward Catalog',
                                icon: Icons.storefront_rounded,
                                isSelected: _currentSegment == 0,
                                onTap: () => setState(() => _currentSegment = 0),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: _SegmentTabButton(
                                title: 'Claimed Codes',
                                icon: Icons.vpn_key_rounded,
                                isSelected: _currentSegment == 1,
                                countBadge: historyAsync.valueOrNull?.length,
                                onTap: () => setState(() => _currentSegment = 1),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Switch view based on active segment
                    if (_currentSegment == 0) ...[
                      // ── CATALOG VIEW ──

                      // Live Social Proof Cashout Ticker
                      const RewardsSocialProofTicker(),
                      const SizedBox(height: 14),

                      // Category Filter Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppLayout.screenPadding,
                        ),
                        child: Row(
                          children: [
                            _CategoryChip(
                              label: 'All Rewards',
                              isSelected: selectedCategory == null,
                              onTap: () => ref
                                  .read(rewardCategoryFilterProvider.notifier)
                                  .state = null,
                            ),
                            const SizedBox(width: 8),
                            _CategoryChip(
                              label: 'Gift Cards (\$)',
                              isSelected:
                                  selectedCategory == RewardCategory.giftCard,
                              onTap: () => ref
                                  .read(rewardCategoryFilterProvider.notifier)
                                  .state = RewardCategory.giftCard,
                            ),
                            const SizedBox(width: 8),
                            _CategoryChip(
                              label: 'Robux Codes (R\$)',
                              isSelected:
                                  selectedCategory == RewardCategory.robuxCode,
                              onTap: () => ref
                                  .read(rewardCategoryFilterProvider.notifier)
                                  .state = RewardCategory.robuxCode,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Reward Cards List
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppLayout.screenPadding,
                        ),
                        itemCount: filteredCatalog.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 18),
                        itemBuilder: (ctx, index) {
                          final item = filteredCatalog[index];
                          final selectedDenomIndex = ref.watch(
                            selectedDenominationsProvider.select(
                              (map) => map[item.id] ?? 0,
                            ),
                          );
                          final activeDenom = item.denominations[
                              selectedDenomIndex.clamp(
                                  0, item.denominations.length - 1)];

                          final isTargetGoal =
                              activeGoal.targetCoins == activeDenom.coinCost &&
                                  activeGoal.title.contains(activeDenom.shortLabel);

                          return _DynamicRewardCard(
                            item: item,
                            selectedDenomination: activeDenom,
                            userCoins: userCoins,
                            isTargetGoal: isTargetGoal,
                            onDenominationSelected: (idx) {
                              ref
                                  .read(selectedDenominationsProvider.notifier)
                                  .select(item.id, idx);
                            },
                            onRedeem: () => _handleRedeem(item, activeDenom),
                            onSetGoal: () => _setAsGoal(item, activeDenom),
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      // Authenticity & Delivery Guarantee Reassurance
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppLayout.screenPadding,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.cardBorder,
                              width: 1.2,
                            ),
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
                                  Icons.verified_user_rounded,
                                  color: AppColors.primary,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '100% Genuine Roblox PINs Guarantee',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    SizedBox(height: 3),
                                    Text(
                                      'Official digital codes delivered to your locker within 24–48 hours. Fully verified & fraud protected.',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFF64748B),
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // FAQ & Redemption Guide Accordion
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppLayout.screenPadding,
                        ),
                        child: _RedemptionFaqSection(),
                      ),
                    ] else ...[
                      // ── CLAIMED CODES / INVENTORY LOCKER VIEW ──
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppLayout.screenPadding,
                        ),
                        child: _ClaimedCodesLocker(
                          historyAsync: historyAsync,
                          revealedPins: _revealedPins,
                          onTogglePinReveal: (id) {
                            setState(() {
                              if (_revealedPins.contains(id)) {
                                _revealedPins.remove(id);
                              } else {
                                _revealedPins.add(id);
                              }
                            });
                          },
                          onBrowseCatalog: () {
                            setState(() => _currentSegment = 0);
                          },
                        ),
                      ),
                    ],

                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: RbxBottomNav(
        currentIndex: 2,
        onTap: (index) {
          ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
          widget.onNavTap(index);
        },
      ),
    );
  }
}

// ─── Segment Tab Button ───────────────────────────────────────────────────────

class _SegmentTabButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final int? countBadge;
  final VoidCallback onTap;

  const _SegmentTabButton({
    required this.title,
    required this.icon,
    required this.isSelected,
    this.countBadge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? AppColors.primary
                  : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected
                    ? const Color(0xFF0F172A)
                    : const Color(0xFF64748B),
              ),
            ),
            if (countBadge != null && countBadge! > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$countBadge',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Category Filter Chip ───────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.primaryGradient : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.transparent : AppColors.cardBorder,
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}

// ─── Dynamic Reward Card with Denominations ─────────────────────────────────

class _DynamicRewardCard extends StatelessWidget {
  final RewardItem item;
  final RewardDenomination selectedDenomination;
  final int userCoins;
  final bool isTargetGoal;
  final Function(int) onDenominationSelected;
  final VoidCallback onRedeem;
  final VoidCallback onSetGoal;

  const _DynamicRewardCard({
    required this.item,
    required this.selectedDenomination,
    required this.userCoins,
    required this.isTargetGoal,
    required this.onDenominationSelected,
    required this.onRedeem,
    required this.onSetGoal,
  });

  @override
  Widget build(BuildContext context) {
    final canRedeem = userCoins >= selectedDenomination.coinCost;
    final progress = selectedDenomination.coinCost > 0
        ? (userCoins / selectedDenomination.coinCost).clamp(0.0, 1.0)
        : 0.0;
    final remainingCoins =
        (selectedDenomination.coinCost - userCoins).clamp(0, 999999999);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header: Image + Title + Delivery Pill
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 62,
                  height: 44,
                  color: item.bgColor.withValues(alpha: 0.1),
                  child: Image.asset(
                    item.assetPath,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.card_giftcard,
                      color: item.bgColor,
                      size: 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.subtitle,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt_rounded, size: 12, color: AppColors.primary),
                    SizedBox(width: 2),
                    Text(
                      '24h Delivery',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Denomination Selector Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Select Denomination:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.2,
                ),
              ),
              Text(
                selectedDenomination.label,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Denomination Chips Row (Single horizontal scroll, no awkward multi-line wrapping)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: List.generate(item.denominations.length, (i) {
                final denom = item.denominations[i];
                final isSelected = denom.id == selectedDenomination.id;

                return Padding(
                  padding: EdgeInsets.only(
                    right: i < item.denominations.length - 1 ? 8 : 0,
                  ),
                  child: GestureDetector(
                    onTap: () => onDenominationSelected(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        gradient: isSelected ? AppColors.primaryGradient : null,
                        color: isSelected ? null : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? Colors.transparent
                              : AppColors.cardBorder,
                          width: isSelected ? 1.5 : 1.0,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.25),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            denom.shortLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '(${denom.formattedCost})',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.85)
                                  : const Color(0xFF868A9F),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 12),

          // Progress bar towards this reward
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: const Color(0xFFF1F2F8),
              valueColor: AlwaysStoppedAnimation<Color>(
                canRedeem ? const Color(0xFF16A34A) : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 6),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                canRedeem
                    ? '🎉 Ready to redeem!'
                    : 'Need ${remainingCoins.toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (m) => "${m[1]},")} more',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: canRedeem
                      ? const Color(0xFF16A34A)
                      : const Color(0xFF64748B),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    AppAssets.goldCoin,
                    width: 13,
                    height: 13,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.monetization_on,
                      size: 13,
                      color: Color(0xFFFFCC44),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${selectedDenomination.formattedCost} Coins',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Actions Row: [Set as Goal] / [Redeem Now or Locked]
          Row(
            children: [
              if (!canRedeem) ...[
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: isTargetGoal ? null : onSetGoal,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: isTargetGoal
                            ? const Color(0xFFF1F5F9)
                            : AppColors.primarySoft.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isTargetGoal
                              ? const Color(0xFFCBD5E1)
                              : AppColors.primary.withValues(alpha: 0.35),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isTargetGoal
                                ? Icons.check_circle_rounded
                                : Icons.flag_rounded,
                            size: 15,
                            color: isTargetGoal
                                ? const Color(0xFF94A3B8)
                                : AppColors.primary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isTargetGoal ? 'Current Goal' : 'Set Goal',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: isTargetGoal
                                  ? const Color(0xFF94A3B8)
                                  : AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: canRedeem
                    ? InteractiveButton(
                        height: 44,
                        borderRadius: 14,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        icon: Icons.celebration_rounded,
                        iconSize: 15,
                        iconSpacing: 6,
                        text: 'Claim',
                        onTap: onRedeem,
                      )
                    : Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                            width: 1.0,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.lock_rounded,
                              size: 14,
                              color: Color(0xFF94A3B8),
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Locked',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Claimed Codes Locker Tab ────────────────────────────────────────────────

class _ClaimedCodesLocker extends StatelessWidget {
  final AsyncValue<List<Map<String, dynamic>>> historyAsync;
  final Set<String> revealedPins;
  final Function(String) onTogglePinReveal;
  final VoidCallback onBrowseCatalog;

  const _ClaimedCodesLocker({
    required this.historyAsync,
    required this.revealedPins,
    required this.onTogglePinReveal,
    required this.onBrowseCatalog,
  });

  @override
  Widget build(BuildContext context) {
    return historyAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      error: (err, _) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Text(
          'Could not load history: $err',
          style: const TextStyle(color: Colors.red, fontSize: 13),
        ),
      ),
      data: (history) {
        if (history.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.cardBorder, width: 1.2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: AppColors.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.card_giftcard_rounded,
                    color: AppColors.primary,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No Claimed Codes Yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Play mini-games and earn coins to redeem your first digital Roblox gift card!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                InteractiveButton(
                  text: 'Browse Rewards',
                  height: 48,
                  width: 200,
                  borderRadius: 16,
                  onTap: onBrowseCatalog,
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: history.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (ctx, i) {
            final data = history[i];
            final id = data['id']?.toString() ?? '$i';
            final isRevealed = revealedPins.contains(id);

            return _ClaimedCodeCard(
              data: data,
              isRevealed: isRevealed,
              onToggleReveal: () => onTogglePinReveal(id),
            );
          },
        );
      },
    );
  }
}

class _ClaimedCodeCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isRevealed;
  final VoidCallback onToggleReveal;

  const _ClaimedCodeCard({
    required this.data,
    required this.isRevealed,
    required this.onToggleReveal,
  });

  Color _statusColor(String status) {
    switch (status) {
      case 'fulfilled':
      case 'success':
        return const Color(0xFF16A34A);
      case 'rejected':
      case 'cancelled':
        return const Color(0xFFDC2626);
      case 'pending':
      default:
        return const Color(0xFFD97706);
    }
  }

  Color _statusBg(String status) {
    switch (status) {
      case 'fulfilled':
      case 'success':
        return const Color(0xFFDCFCE7);
      case 'rejected':
      case 'cancelled':
        return const Color(0xFFFEE2E2);
      case 'pending':
      default:
        return const Color(0xFFFEF3C7);
    }
  }

  String _formatDate(String? raw) {
    if (raw == null) return '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return '';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final title = data['reward_title'] as String? ?? 'Roblox Gift Card';
    final cost = (data['cost'] as num?)?.toInt() ?? 0;
    final status = (data['status'] as String? ?? 'pending').toLowerCase();
    final createdAt = data['created_at'] as String?;
    final pinCode = data['pin_code'] as String? ?? 'RBX-9842-7719';

    final isFulfilled = status == 'fulfilled' || status == 'success';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _statusBg(status),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isFulfilled
                      ? Icons.check_circle_rounded
                      : (status == 'pending'
                          ? Icons.hourglass_top_rounded
                          : Icons.cancel_rounded),
                  color: _statusColor(status),
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
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${cost.toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (m) => "${m[1]},")} Coins • ${_formatDate(createdAt)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusBg(status),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isFulfilled
                      ? 'Ready'
                      : (status == 'pending' ? 'Verifying' : 'Refunded'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _statusColor(status),
                  ),
                ),
              ),
            ],
          ),

          // Code Reveal Section if Fulfilled
          if (isFulfilled) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF9FE),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder, width: 1.2),
              ),
              child: Row(
                children: [
                  const Icon(Icons.key_rounded,
                      size: 18, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isRevealed
                          ? pinCode
                          : '•••• •••• •••• ${pinCode.length >= 4 ? pinCode.substring(pinCode.length - 4) : "****"}',
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                        letterSpacing: isRevealed ? 1.5 : 2.0,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      isRevealed
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      size: 18,
                      color: const Color(0xFF64748B),
                    ),
                    onPressed: onToggleReveal,
                    tooltip: isRevealed ? 'Hide Code' : 'Reveal Code',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.copy_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: pinCode));
                      HapticFeedback.lightImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('PIN Code copied to clipboard!'),
                          duration: Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    tooltip: 'Copy PIN',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            InteractiveButton(
              text: 'Redeem on Roblox.com',
              icon: Icons.open_in_new_rounded,
              iconSize: 14,
              iconSpacing: 6,
              height: 40,
              borderRadius: 12,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              onTap: () =>
                  PolicyConstants.openUrl('https://www.roblox.com/redeem'),
            ),
          ] else if (status == 'pending') ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Color(0xFFB45309)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Automated fraud verification in progress (within 24–48h). Your PIN will appear here once approved.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFFB45309),
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── FAQ & Redemption Guide Accordion ────────────────────────────────────────

class _RedemptionFaqSection extends StatelessWidget {
  const _RedemptionFaqSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: const ExpansionTile(
          tilePadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Icon(Icons.help_outline_rounded,
              color: AppColors.primary, size: 22),
          title: Text(
            'How Redemption Works & FAQs',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FaqItem(
                    q: 'How do I receive my gift card or Robux?',
                    a: 'All codes are delivered digitally to the "Claimed Codes" tab above. You can view, reveal, and copy your PIN at any time.',
                  ),
                  SizedBox(height: 10),
                  _FaqItem(
                    q: 'How long does verification take?',
                    a: 'Most redemptions are verified and dispatched within 24 to 48 hours following automated fraud-prevention checks.',
                  ),
                  SizedBox(height: 10),
                  _FaqItem(
                    q: 'How do I apply the code on Roblox?',
                    a: 'Go to roblox.com/redeem, log into your Roblox account, paste the PIN code from your Claimed Codes tab, and press Redeem.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqItem extends StatelessWidget {
  final String q;
  final String a;

  const _FaqItem({required this.q, required this.a});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Q: $q',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          a,
          style: const TextStyle(
            fontSize: 11.5,
            color: Color(0xFF64748B),
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

// ─── Claim Reward Dialog ─────────────────────────────────────────────────────

class _ClaimResult {
  final String robloxUsername;
  final String email;

  const _ClaimResult({
    required this.robloxUsername,
    required this.email,
  });
}

class _ClaimRewardDialog extends StatefulWidget {
  final String rewardTitle;
  final String denominationLabel;
  final int cost;
  final String defaultUsername;
  final String defaultEmail;

  const _ClaimRewardDialog({
    required this.rewardTitle,
    required this.denominationLabel,
    required this.cost,
    required this.defaultUsername,
    required this.defaultEmail,
  });

  @override
  State<_ClaimRewardDialog> createState() => _ClaimRewardDialogState();
}

class _ClaimRewardDialogState extends State<_ClaimRewardDialog> {
  late final TextEditingController _usernameController;
  late final TextEditingController _emailController;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.defaultUsername);
    _emailController = TextEditingController(text: widget.defaultEmail);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _submit() {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();

    if (username.isEmpty) {
      setState(() => _errorMessage = 'Please enter your Roblox username');
      return;
    }

    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      setState(() => _errorMessage = 'Please enter a valid delivery email address');
      return;
    }

    Navigator.of(context).pop(_ClaimResult(
      robloxUsername: username,
      email: email,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.cardBorder, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Icon & Title
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: const BoxDecoration(
                        color: AppColors.primarySoft,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.card_giftcard_rounded,
                        color: AppColors.primary,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Claim Your Reward',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryText,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.rewardTitle,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF9FE),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            AppAssets.goldCoin,
                            width: 14,
                            height: 14,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.monetization_on,
                              size: 14,
                              color: Color(0xFFFFCC44),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '-${widget.cost.toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (m) => "${m[1]},")} Coins',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Roblox Username Input
              const Text(
                'Roblox Username',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _usernameController,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'e.g. GamerPro123',
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  prefixIcon: const Icon(Icons.sports_esports_rounded, color: AppColors.primary, size: 20),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.cardBorder, width: 1.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.cardBorder, width: 1.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
                onChanged: (_) {
                  if (_errorMessage != null) setState(() => _errorMessage = null);
                },
              ),
              const SizedBox(height: 14),

              // Delivery Email Input
              const Text(
                'Delivery Email Address',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Where to send your digital card PIN',
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  prefixIcon: const Icon(Icons.email_outlined, color: AppColors.primary, size: 20),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.cardBorder, width: 1.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.cardBorder, width: 1.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
                onChanged: (_) {
                  if (_errorMessage != null) setState(() => _errorMessage = null);
                },
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 14, color: Colors.redAccent),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),

              // Trust Info Container
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shield_outlined, size: 16, color: Color(0xFF64748B)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your digital Roblox gift card PIN will be sent to this email and saved in your Claimed Locker within 24–48 hours.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.cardBorder, width: 1.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InteractiveButton(
                      text: 'Confirm Claim',
                      height: 46,
                      borderRadius: 14,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      onTap: _submit,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Success Dialog ──────────────────────────────────────────────────────────

class RedeemSuccessDialog extends StatelessWidget {
  final String rewardTitle;
  final VoidCallback onViewClaimedCodes;

  const RedeemSuccessDialog({
    super.key,
    required this.rewardTitle,
    required this.onViewClaimedCodes,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.cardBorder, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.15),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF16A34A),
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Redemption Requested!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF131326),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your code for "$rewardTitle" has been generated and stored safely in your Claimed Codes locker.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.cardBorder, width: 1.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InteractiveButton(
                    text: 'View Locker',
                    height: 46,
                    borderRadius: 14,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    onTap: onViewClaimedCodes,
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
