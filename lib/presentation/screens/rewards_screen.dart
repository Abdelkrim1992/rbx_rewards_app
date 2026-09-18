import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import '../providers/ad_provider.dart';
import '../../models/ad_models.dart';
import '../../widgets/coin_fly_overlay.dart';
import '../../core/utils/device_fingerprint.dart';
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
  bool _localStarterClaimed = false;
  ScaffoldMessengerState? _scaffoldMessenger;
  final Set<String> _revealedPins = {};
  late final ScrollController _scrollController;
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()
      ..addListener(() {
        final scrolled = _scrollController.hasClients && _scrollController.offset > 12;
        if (scrolled != _isScrolled) {
          setState(() => _isScrolled = scrolled);
        }
      });
    _loadStarterClaimStatus();
  }

  Future<void> _loadStarterClaimStatus() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _localStarterClaimed =
            prefs.getBool('starter_reward_claimed_v1') ?? false;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _scaffoldMessenger?.clearSnackBars();
    super.dispose();
  }

  String _sanitizeRewardTitle(String title) {
    return title
        .replaceAll(r'$', 'USD ')
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim();
  }

  Future<void> _showDenominationSheet(
    RewardItem item,
    int initialDenomIndex,
    GoalRewardState activeGoal,
    bool isStarterClaimed,
  ) async {
    HapticFeedback.lightImpact();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => _RewardDenominationSheet(
          scrollController: scrollController,
          item: item,
          initialDenomIndex: initialDenomIndex,
          userCoins: ref.read(coinProvider),
          activeGoal: activeGoal,
          isStarterClaimed: isStarterClaimed,
          onDenominationSelected: (idx) {
            ref.read(selectedDenominationsProvider.notifier).select(item.id, idx);
          },
          onRedeem: (denom) {
            Navigator.of(context).pop();
            _handleRedeem(item, denom);
          },
          onSetGoal: (denom) {
            Navigator.of(context).pop();
            _setAsGoal(item, denom);
          },
        ),
      ),
    );
  }

  void _showLockedRequirementsSheet(RewardItem item, RewardDenomination denomination) {
    HapticFeedback.lightImpact();
    final userCoins = ref.read(coinProvider);
    final lifetimeAds = ref.read(adTrackerServiceProvider).lifetimeAdsWatched;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LockedRequirementsSheet(
        item: item,
        denomination: denomination,
        userCoins: userCoins,
        lifetimeAds: lifetimeAds,
        onPlayGames: () {
          Navigator.of(ctx).pop();
          widget.onNavTap(1);
        },
        onWatchVideo: () async {
          Navigator.of(ctx).pop();
          final adNotifier = ref.read(adProvider.notifier);
          await adNotifier.showOptionalAd(
            AdPlacement.doubleReward,
            onReward: (_) async {
              final yieldMultiplier = ref.read(dailyCapServiceProvider).getYieldMultiplier();
              final bonus = (25 * yieldMultiplier).round().clamp(4, 25);
              await ref.read(coinProvider.notifier).credit(bonus, 'watch_video');
              if (mounted) {
                final size = MediaQuery.of(context).size;
                CoinFlyOverlay.spawn(
                  context,
                  fromPosition: Offset(size.width / 2, size.height / 2),
                  coinCount: 10,
                );
              }
            },
            onAdFailed: (err) async {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Video unavailable: $err'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          );
        },
      ),
    );
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

    // Dual-Gated requirements check (Coin balance and minimum lifetime ads)
    final balance = ref.read(coinProvider);
    final lifetimeAds = ref.read(adTrackerServiceProvider).lifetimeAdsWatched;
    if (balance < denomination.coinCost || lifetimeAds < denomination.minLifetimeAds) {
      _showLockedRequirementsSheet(item, denomination);
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
        isStarter: denomination.isOneTimeStarter || denomination.coinCost == 4500,
      ),
    );

    if (claimResult == null || !mounted) return;

    setState(() => _isProcessing = true);

    // Sync latest ad counts before redemption
    await ref.read(adTrackerServiceProvider).forceSync();

    // Capture stable hashed hardware device ID
    final deviceId = await DeviceFingerprint.getDeviceId();

    final fullTitle = '${item.title} - ${denomination.label}';
    final sanitizedTitle = _sanitizeRewardTitle(fullTitle);

    // Process redemption via atomic backend RPC
    final success = await ref.read(coinProvider.notifier).spend(
      denomination.coinCost,
      sanitizedTitle,
      denomId: denomination.id,
      deviceId: deviceId,
    );

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (success) {
      if (denomination.isOneTimeStarter || denomination.coinCost == 4500) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('starter_reward_claimed_v1', true);
        } catch (_) {}
        if (mounted) {
          setState(() => _localStarterClaimed = true);
        }
      }

      // Invalidate history to fetch latest record
      ref.invalidate(rewardHistoryProvider);
      ref.invalidate(userProfileStreamProvider);

      if (!mounted) return;
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
      if (!mounted) return;
      final errorMsg = ref.read(coinProvider.notifier).lastSpendError ??
          'Redemption failed. Your coins were not deducted.';
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
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

    final history = historyAsync.valueOrNull ?? [];
    final hasClaimedInHistory = history.any((r) {
      final title = (r['reward_title'] ?? '').toString().toLowerCase();
      final cost = (r['cost'] as num?)?.toInt() ?? 0;
      return cost == 4500 || title.contains('starter');
    });
    final isStarterClaimed = _localStarterClaimed || hasClaimedInHistory;

    final filteredCatalog = selectedCategory == null
        ? catalog
        : catalog.where((item) => item.category == selectedCategory).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top App Header (Fixed & Sticky)
            RbxAppHeader(
              isScrolled: _isScrolled,
              onNavTap: (index) {
                ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
                widget.onNavTap(index);
              },
            ),

            Expanded(
              child: RefreshableScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.only(
                    top: 2, bottom: AppLayout.sectionSpacing),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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

                      // Reward Cards Grid
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppLayout.screenPadding,
                        ),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.80,
                          ),
                          itemCount: filteredCatalog.length,
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

                            return _RewardGridCard(
                              item: item,
                              selectedDenomination: activeDenom,
                              userCoins: userCoins,
                              isStarterClaimed: isStarterClaimed,
                              onTap: () => _showDenominationSheet(
                                item,
                                selectedDenomIndex,
                                activeGoal,
                                isStarterClaimed,
                              ),
                              onLockedTap: () => _showLockedRequirementsSheet(item, activeDenom),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
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

// ─── Compact Reward Grid Card ─────────────────────────────────────────────────

class _RewardGridCard extends StatelessWidget {
  final RewardItem item;
  final RewardDenomination selectedDenomination;
  final int userCoins;
  final bool isStarterClaimed;
  final VoidCallback onTap;
  final VoidCallback? onLockedTap;

  const _RewardGridCard({
    required this.item,
    required this.selectedDenomination,
    required this.userCoins,
    this.isStarterClaimed = false,
    required this.onTap,
    this.onLockedTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDenomClaimed =
        selectedDenomination.isOneTimeStarter && isStarterClaimed;
    final canRedeem =
        !isDenomClaimed && userCoins >= selectedDenomination.coinCost;
    final progress = selectedDenomination.coinCost > 0
        ? (userCoins / selectedDenomination.coinCost).clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.cardBorder, width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image area
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(17),
                ),
                child: Container(
                  color: item.bgColor.withValues(alpha: 0.10),
                  child: Stack(
                    children: [
                      Center(
                        child: Image.asset(
                          item.assetPath,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.card_giftcard_rounded,
                            color: item.bgColor,
                            size: 52,
                          ),
                        ),
                      ),
                      // 24h delivery pill
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bolt_rounded,
                                  size: 10, color: AppColors.primary),
                              SizedBox(width: 2),
                              Text(
                                '24h',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Starter Quick Reward Badge
                      if (selectedDenomination.isOneTimeStarter)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF4500), Color(0xFFFF8C00)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF4500)
                                      .withValues(alpha: 0.35),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('🔥', style: TextStyle(fontSize: 9)),
                                SizedBox(width: 2),
                                Text(
                                  '1-Time Starter',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Content area
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Coin cost row
                  Row(
                    children: [
                      Image.asset(
                        AppAssets.goldCoin,
                        width: 11,
                        height: 11,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.monetization_on,
                          size: 11,
                          color: Color(0xFFFFCC44),
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${item.denominations.first.formattedCost}+ RBX',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 3,
                      backgroundColor: const Color(0xFFF1F2F8),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        canRedeem
                            ? const Color(0xFF16A34A)
                            : AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),

                  // Redeem / Locked / Claimed button
                  SizedBox(
                    width: double.infinity,
                    height: 34,
                    child: isDenomClaimed
                        ? DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: const Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    size: 13,
                                    color: Color(0xFF16A34A),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Claimed',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : canRedeem
                            ? DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: AppColors.primaryGradient,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          AppColors.primary.withValues(alpha: 0.30),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Text(
                                    'Redeem',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              )
                            : GestureDetector(
                                onTap: onLockedTap,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: const Center(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.lock_rounded,
                                          size: 11,
                                          color: Color(0xFF94A3B8),
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Locked',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ],
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
      ),
    );
  }
}

// ─── Denomination Bottom Sheet ─────────────────────────────────────────────────

class _RewardDenominationSheet extends StatefulWidget {
  final RewardItem item;
  final int initialDenomIndex;
  final int userCoins;
  final GoalRewardState activeGoal;
  final bool isStarterClaimed;
  final Function(int) onDenominationSelected;
  final Function(RewardDenomination) onRedeem;
  final Function(RewardDenomination) onSetGoal;
  final ScrollController scrollController;

  const _RewardDenominationSheet({
    required this.item,
    required this.initialDenomIndex,
    required this.userCoins,
    required this.activeGoal,
    this.isStarterClaimed = false,
    required this.onDenominationSelected,
    required this.onRedeem,
    required this.onSetGoal,
    required this.scrollController,
  });

  @override
  State<_RewardDenominationSheet> createState() =>
      _RewardDenominationSheetState();
}

class _RewardDenominationSheetState extends State<_RewardDenominationSheet> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialDenomIndex
        .clamp(0, widget.item.denominations.length - 1);
  }

  RewardDenomination get _activeDenom =>
      widget.item.denominations[_selectedIndex];

  @override
  Widget build(BuildContext context) {
    final isDenomClaimed =
        _activeDenom.isOneTimeStarter && widget.isStarterClaimed;
    final canRedeem =
        !isDenomClaimed && widget.userCoins >= _activeDenom.coinCost;
    final progress = _activeDenom.coinCost > 0
        ? (widget.userCoins / _activeDenom.coinCost).clamp(0.0, 1.0)
        : 0.0;
    final remainingCoins =
        (_activeDenom.coinCost - widget.userCoins).clamp(0, 999999999);
    final isTargetGoal =
        widget.activeGoal.targetCoins == _activeDenom.coinCost &&
            widget.activeGoal.title.contains(_activeDenom.shortLabel);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        controller: widget.scrollController,
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header: image + title
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 56,
                  height: 40,
                  color: widget.item.bgColor.withValues(alpha: 0.10),
                  child: Image.asset(
                    widget.item.assetPath,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.card_giftcard_rounded,
                      color: widget.item.bgColor,
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
                      widget.item.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryText,
                      ),
                    ),
                    Text(
                      widget.item.subtitle,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              // Close
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Denomination label
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Choose an Amount:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.2,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _activeDenom.shortLabel,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Denomination chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: List.generate(widget.item.denominations.length, (i) {
                final denom = widget.item.denominations[i];
                final isSelected = i == _selectedIndex;

                return Padding(
                  padding: EdgeInsets.only(
                    right: i < widget.item.denominations.length - 1 ? 8 : 0,
                  ),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedIndex = i);
                      widget.onDenominationSelected(i);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        gradient: isSelected ? AppColors.primaryGradient : null,
                        color: isSelected ? null : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? Colors.transparent
                              : AppColors.cardBorder,
                          width: isSelected ? 1.5 : 1.0,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.25),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (denom.isOneTimeStarter)
                            Container(
                              margin: const EdgeInsets.only(bottom: 3),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: (denom.isOneTimeStarter &&
                                        widget.isStarterClaimed)
                                    ? const Color(0xFF64748B)
                                    : (isSelected
                                        ? Colors.white
                                        : const Color(0xFFFF5722)),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                (denom.isOneTimeStarter &&
                                        widget.isStarterClaimed)
                                    ? 'CLAIMED'
                                    : '🔥 STARTER',
                                style: TextStyle(
                                  fontSize: 7.5,
                                  fontWeight: FontWeight.w900,
                                  color: (denom.isOneTimeStarter &&
                                          widget.isStarterClaimed)
                                      ? Colors.white
                                      : (isSelected
                                          ? AppColors.primary
                                          : Colors.white),
                                ),
                              ),
                            ),
                          Text(
                            denom.shortLabel,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${denom.formattedCost} RBX',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
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
          const SizedBox(height: 16),

          // Divider
          const Divider(height: 1, color: Color(0xFFF1F2F8)),
          const SizedBox(height: 14),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: const Color(0xFFF1F2F8),
              valueColor: AlwaysStoppedAnimation<Color>(
                canRedeem ? const Color(0xFF16A34A) : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 7),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                canRedeem
                    ? '🎉 Ready to redeem!'
                    : 'Need ${remainingCoins.toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (m) => "${m[1]},")} more',
                style: TextStyle(
                  fontSize: 11.5,
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
                    '${_activeDenom.formattedCost} Coins',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              if (!canRedeem) ...[
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: isTargetGoal ? null : () => widget.onSetGoal(_activeDenom),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
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
                            size: 16,
                            color: isTargetGoal
                                ? const Color(0xFF94A3B8)
                                : AppColors.primary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isTargetGoal ? 'Current Goal' : 'Set Goal',
                            style: TextStyle(
                              fontSize: 12,
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
                const SizedBox(width: 10),
              ],
              Expanded(
                child: isDenomClaimed
                    ? Material(
                        color: Colors.transparent,
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                size: 16,
                                color: Color(0xFF16A34A),
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Already Claimed',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : canRedeem
                        ? InteractiveButton(
                            height: 48,
                            borderRadius: 14,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            icon: Icons.celebration_rounded,
                            iconSize: 16,
                            iconSpacing: 6,
                            text: 'Claim Now',
                            onTap: () => widget.onRedeem(_activeDenom),
                          )
                        : Material(
                        color: Colors.transparent,
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.lock_rounded,
                                size: 15,
                                color: Color(0xFF94A3B8),
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Locked',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
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
      case 'pending_review':
        return const Color(0xFFE11D48); // Rose/Amber security review
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
      case 'pending_review':
        return const Color(0xFFFFE4E6);
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
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
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
                      : (status == 'pending_review'
                          ? Icons.security_update_good_rounded
                          : (status == 'pending'
                              ? Icons.hourglass_top_rounded
                              : Icons.cancel_rounded)),
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
                      : (status == 'pending_review'
                          ? 'In Review (24-48h)'
                          : (status == 'pending' ? 'Verifying' : 'Refunded')),
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
  final bool isStarter;

  const _ClaimRewardDialog({
    required this.rewardTitle,
    required this.denominationLabel,
    required this.cost,
    required this.defaultUsername,
    required this.defaultEmail,
    this.isStarter = false,
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

              // Delivery & Reassurance Container
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.isStarter
                      ? const Color(0xFFF0FDF4)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.isStarter
                        ? const Color(0xFFBBF7D0)
                        : const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          widget.isStarter
                              ? Icons.local_fire_department_rounded
                              : Icons.shield_outlined,
                          size: 16,
                          color: widget.isStarter
                              ? const Color(0xFF16A34A)
                              : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.isStarter
                              ? '40 Robux Delivery Instructions'
                              : 'Redemption Guarantee',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: widget.isStarter
                                ? const Color(0xFF15803D)
                                : const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.isStarter
                          ? '• Ensure your Roblox username is accurate.\n'
                            '• Official 40 Robux voucher PIN is delivered to your email & claimed locker within 24–48 hours.\n'
                            '• Visit roblox.com/redeem, submit your code, and receive 40 Robux instantly!'
                          : 'Your digital Roblox gift card PIN will be sent to this email and saved in your Claimed Locker within 24–48 hours.',
                      style: TextStyle(
                        fontSize: 11,
                        color: widget.isStarter
                            ? const Color(0xFF166534)
                            : const Color(0xFF64748B),
                        height: 1.4,
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

// ─── Locked Requirements Progress Sheet (Phase 6) ─────────────────────────────

class _LockedRequirementsSheet extends StatelessWidget {
  final RewardItem item;
  final RewardDenomination denomination;
  final int userCoins;
  final int lifetimeAds;
  final VoidCallback onPlayGames;
  final VoidCallback onWatchVideo;

  const _LockedRequirementsSheet({
    required this.item,
    required this.denomination,
    required this.userCoins,
    required this.lifetimeAds,
    required this.onPlayGames,
    required this.onWatchVideo,
  });

  @override
  Widget build(BuildContext context) {
    final coinCost = denomination.coinCost;
    final minAds = denomination.minLifetimeAds;
    final hasEnoughCoins = userCoins >= coinCost;
    final hasEnoughAds = minAds == 0 || lifetimeAds >= minAds;

    final coinProgress = coinCost > 0 ? (userCoins / coinCost).clamp(0.0, 1.0) : 1.0;
    final adProgress = minAds > 0 ? (lifetimeAds / minAds).clamp(0.0, 1.0) : 1.0;

    final coinsNeeded = (coinCost - userCoins).clamp(0, coinCost);
    final adsNeeded = (minAds - lifetimeAds).clamp(0, minAds);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Header Row: Item Info & Short Label
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: item.bgColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: item.bgColor.withValues(alpha: 0.3)),
                  ),
                  child: Center(
                    child: Image.asset(
                      item.assetPath,
                      width: 28,
                      height: 28,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.card_giftcard_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Unlock Requirements for ${denomination.label}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Text(
                    denomination.shortLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1D4ED8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Requirement 1: Coin Balance
            _RequirementTile(
              icon: Icons.monetization_on_rounded,
              iconColor: const Color(0xFFEAB308),
              iconBgColor: const Color(0xFFFEF9C3),
              title: 'Coin Balance',
              currentStr: userCoins.toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (m) => "${m[1]},"),
              targetStr: '${coinCost.toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (m) => "${m[1]},")} Coins',
              progress: coinProgress,
              isCompleted: hasEnoughCoins,
              subtitle: hasEnoughCoins
                  ? 'Requirement met!'
                  : 'Need ${coinsNeeded.toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (m) => "${m[1]},")} more coins',
            ),
            const SizedBox(height: 12),

            // Requirement 2: Lifetime Ads
            if (minAds > 0) ...[
              _RequirementTile(
                icon: Icons.play_circle_fill_rounded,
                iconColor: AppColors.primary,
                iconBgColor: AppColors.primarySoft,
                title: 'Verified Ad Views',
                currentStr: '$lifetimeAds',
                targetStr: '$minAds Views',
                progress: adProgress,
                isCompleted: hasEnoughAds,
                subtitle: hasEnoughAds
                    ? 'Requirement met!'
                    : 'Need $adsNeeded more video views to unlock',
              ),
              const SizedBox(height: 14),
            ],

            // Guarantee Box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.verified_user_rounded,
                    color: Color(0xFF10B981),
                    size: 18,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '100% Genuine Roblox digital codes delivered within 24–48 hours.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Action CTAs
            Row(
              children: [
                Expanded(
                  child: InteractiveButton(
                    text: 'Play Games',
                    icon: Icons.sports_esports_rounded,
                    height: 46,
                    borderRadius: 14,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    onTap: onPlayGames,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onWatchVideo,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.ondemand_video_rounded, color: AppColors.primary, size: 18),
                        SizedBox(width: 6),
                        Text(
                          '+25 RBX Ad',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
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
      ),
    );
  }
}

class _RequirementTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String currentStr;
  final String targetStr;
  final double progress;
  final bool isCompleted;
  final String subtitle;

  const _RequirementTile({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.currentStr,
    required this.targetStr,
    required this.progress,
    required this.isCompleted,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCompleted ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted ? const Color(0xFFBBF7D0) : AppColors.cardBorder,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isCompleted ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$currentStr / $targetStr',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isCompleted ? const Color(0xFF16A34A) : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                isCompleted ? const Color(0xFF16A34A) : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
