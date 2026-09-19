import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/refreshable_scroll.dart';
import '../../widgets/screen_title.dart';
import '../providers/data_providers.dart';
import '../providers/user_provider.dart';
import 'home/widgets/home_referral_card.dart';
import 'profile/profile_dialogs.dart';
import 'settings_screen.dart';

/// Gamer Profile Screen combining the modern layout with the established brand UI design:
/// - App header and screen title
/// - Gamer Passport card with purple-accented borders and avatar ring
/// - Career / Quick stats styled with AppColors.cardBorder and vibrant badges
/// - Referral hero card
/// - Grouped menu portal with primary-colored icons
/// - Conditional Logout button (only visible for Google/Apple authenticated users)
class ProfileScreen extends ConsumerStatefulWidget {
  final void Function(int index) onNavTap;

  const ProfileScreen({super.key, required this.onNavTap});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final ScrollController _scrollController;
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()
      ..addListener(() {
        final scrolled =
            _scrollController.hasClients && _scrollController.offset > 12;
        if (scrolled != _isScrolled) {
          setState(() => _isScrolled = scrolled);
        }
      });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  int _xpForCurrentLevel(int totalCoins) => totalCoins % 5000;

  String _formatCoins(int amount) {
    return amount.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Sept 2026';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final month = months[(dt.month - 1).clamp(0, 11)];
    return '$month ${dt.year}';
  }

  void _copyPlayerId(String fullId) {
    Clipboard.setData(ClipboardData(text: fullId));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.copy_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text(
              'Player Account ID copied to clipboard!',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = ref.watch(userProfileProvider);
    final historyAsync = ref.watch(rewardHistoryProvider);

    final level = (userProfile.totalEarned / 5000).floor() + 1;
    final xpCurrent = _xpForCurrentLevel(userProfile.totalEarned);
    const xpGoal = 5000;
    final xpProgress = (xpCurrent / xpGoal).clamp(0.0, 1.0);

    final (tierTitle, tierColor, tierIcon) = switch (level) {
      >= 16 => (
          'Gold Legend',
          const Color(0xFFD97706),
          Icons.military_tech_rounded
        ),
      >= 6 => (
          'Silver Pro',
          const Color(0xFF475569),
          Icons.workspace_premium_rounded
        ),
      _ => ('Bronze Rookie', const Color(0xFFB45309), Icons.shield_rounded),
    };

    final shortId = userProfile.id.isNotEmpty
        ? (userProfile.id.length > 8
            ? userProfile.id.substring(0, 8).toUpperCase()
            : userProfile.id.toUpperCase())
        : 'RBX-USER';

    final totalRedeemedCount = historyAsync.valueOrNull?.length ?? 0;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 360;
    final isMedium = screenWidth < 400;

    final horizontalPadding = isCompact ? 12.0 : 16.0;
    final cardPadding = isCompact ? 14.0 : (isMedium ? 16.0 : 20.0);
    final avatarSize = isCompact ? 64.0 : (isMedium ? 70.0 : 76.0);
    final avatarSpacing = isCompact ? 10.0 : 14.0;

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
                      title: 'Gamer Profile',
                      subtitle:
                          'Manage your perks, account, and app preferences',
                    ),
                    const SizedBox(height: 6),

                    // ── 1. GAMER PASSPORT HEADER (Original Brand UI) ──
                    Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: horizontalPadding),
                      child: Container(
                        padding: EdgeInsets.all(cardPadding),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppColors.cardBorder, width: 1.2),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                // Avatar with ring
                                Container(
                                  width: avatarSize,
                                  height: avatarSize,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.25),
                                      width: 2.5,
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(3),
                                  child: ClipOval(
                                    child: (userProfile.profilePhotoUrl !=
                                                null &&
                                            userProfile
                                                .profilePhotoUrl!.isNotEmpty)
                                        ? CachedNetworkImage(
                                            imageUrl:
                                                userProfile.profilePhotoUrl!,
                                            fit: BoxFit.cover,
                                            placeholder: (_, __) => Container(
                                              color: const Color(0xFFF1F2F8),
                                              child: Icon(
                                                Icons.person,
                                                color: AppColors.purple,
                                                size: isCompact ? 32 : 38,
                                              ),
                                            ),
                                            errorWidget: (_, __, ___) =>
                                                Image.asset(
                                              AppAssets.profileAvatar,
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        : Image.asset(
                                            AppAssets.profileAvatar,
                                            fit: BoxFit.cover,
                                          ),
                                  ),
                                ),
                                SizedBox(width: avatarSpacing),

                                // User info, 1-tap copy ID & VIP badge
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              userProfile.displayName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: isCompact
                                                    ? 17
                                                    : (isMedium ? 18 : 20),
                                                fontWeight: FontWeight.w800,
                                                color: const Color(0xFF0F172A),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          GestureDetector(
                                            onTap: () => showEditProfileDialog(
                                                context, userProfile),
                                            child: Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: AppColors.primarySoft,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: AppColors.cardBorder,
                                                  width: 1.2,
                                                ),
                                              ),
                                              child: const Icon(
                                                Icons.edit_rounded,
                                                size: 15,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),

                                      // 1-Tap Copy Player ID & Join Date (Responsive FittedBox avoids overflow)
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            GestureDetector(
                                              onTap: () =>
                                                  _copyPlayerId(userProfile.id),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    'ID: #$shortId',
                                                    style: const TextStyle(
                                                      fontSize: 11.5,
                                                      fontFamily: 'monospace',
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Color(0xFF64748B),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  const Icon(
                                                    Icons.copy_rounded,
                                                    size: 11.5,
                                                    color: AppColors.primary,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '• Joined ${_formatDate(userProfile.createdAt)}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF94A3B8),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 6),

                                      // VIP Tier Badge with View Perks CTA (Responsive FittedBox)
                                      GestureDetector(
                                        onTap: () => showVipPerksModal(
                                          context,
                                          level: level,
                                          tierTitle: tierTitle,
                                        ),
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: tierColor.withValues(
                                                  alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                              border: Border.all(
                                                color: tierColor.withValues(
                                                    alpha: 0.3),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(tierIcon,
                                                    size: 14, color: tierColor),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '$tierTitle • Lvl $level',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: tierColor,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Icon(
                                                    Icons.chevron_right_rounded,
                                                    size: 14,
                                                    color: tierColor),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Level XP Progress Bar
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          'LEVEL $level PROGRESS',
                                          style: TextStyle(
                                            fontSize: isCompact ? 10 : 11,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.8,
                                            color: const Color(0xFF64748B),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        '${_formatCoins(xpCurrent)} / ${_formatCoins(xpGoal)} XP',
                                        style: TextStyle(
                                          fontSize: isCompact ? 10 : 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Stack(
                                  children: [
                                    Container(
                                      height: 7,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F2F8),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                    ),
                                    FractionallySizedBox(
                                      widthFactor: xpProgress,
                                      child: Container(
                                        height: 7,
                                        decoration: BoxDecoration(
                                          gradient: AppColors.xpBarGradient,
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── 2. QUICK STATS ROW (Original Brand CardBorder UI) ──
                    Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: horizontalPadding),
                      child: Row(
                        children: [
                          Expanded(
                            child: _CareerStatCard(
                              icon: Image.asset(
                                AppAssets.rbxCoinIcon,
                                width: isCompact ? 18 : 20,
                                height: isCompact ? 18 : 20,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.monetization_on,
                                  color: const Color(0xFFFFB000),
                                  size: isCompact ? 18 : 20,
                                ),
                              ),
                              value: _formatCoins(userProfile.coins),
                              title: 'RBX Coins',
                              isCompact: isCompact,
                            ),
                          ),
                          SizedBox(width: isCompact ? 6 : 8),
                          Expanded(
                            child: _CareerStatCard(
                              icon: Icon(
                                Icons.local_fire_department_rounded,
                                color: const Color(0xFFF97316),
                                size: isCompact ? 18 : 20,
                              ),
                              value: '${userProfile.consecutiveDays}',
                              title: 'Day Streak',
                              isCompact: isCompact,
                            ),
                          ),
                          SizedBox(width: isCompact ? 6 : 8),
                          Expanded(
                            child: _CareerStatCard(
                              icon: Icon(
                                Icons.card_giftcard_rounded,
                                color: AppColors.primary,
                                size: isCompact ? 18 : 20,
                              ),
                              value: '$totalRedeemedCount',
                              title: 'Rewards',
                              onTap: () =>
                                  showMyRewardsBottomSheet(context, ref),
                              isCompact: isCompact,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── 3. REFERRAL HERO CARD ──
                    const HomeReferralCard(),

                    const SizedBox(height: 14),

                    // ── 4. GROUPED MENU CARD (Original Brand Primary Icons) ──
                    Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: horizontalPadding),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppColors.cardBorder, width: 1.2),
                        ),
                        child: Column(
                          children: [
                            _ProfileMenuTile(
                              icon: Icons.card_giftcard_rounded,
                              title: 'My Rewards',
                              onTap: () =>
                                  showMyRewardsBottomSheet(context, ref),
                              hasDivider: true,
                            ),
                            _ProfileMenuTile(
                              icon: Icons.receipt_long_rounded,
                              title: 'Transaction History',
                              onTap: () => showTransactionHistoryBottomSheet(
                                  context, ref),
                              hasDivider: true,
                            ),
                            _ProfileMenuTile(
                              icon: Icons.settings_outlined,
                              title: 'Settings',
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const SettingsScreen(),
                                  ),
                                );
                              },
                              hasDivider: true,
                            ),
                            _ProfileMenuTile(
                              icon: Icons.help_outline_rounded,
                              title: 'Help & Support',
                              onTap: () => showHelpDialog(context),
                              hasDivider: false,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── 5. CONDITIONAL LOGOUT BUTTON (Only for Google/Apple users) ──
                    // if (isSocialUser) ...[
                    //   const SizedBox(height: 16),
                    //   Padding(
                    //     padding:
                    //         EdgeInsets.symmetric(horizontal: horizontalPadding),
                    //     child: InteractiveButton(
                    //       icon: Icons.logout_rounded,
                    //       iconSize: 18,
                    //       text: 'Logout',
                    //       height: 48,
                    //       borderRadius: 14,
                    //       fontSize: 14,
                    //       fontWeight: FontWeight.w700,
                    //       gradient: const LinearGradient(
                    //         colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                    //       ),
                    //       onTap: () => showLogoutConfirmDialog(context, ref),
                    //     ),
                    //   ),
                    // ],

                    // App Version Footer
                    const SizedBox(height: 24),
                    Center(
                      child: Text(
                        'RBX Rewards v1.2.0 \nCreated by Mimo Apps\n© 2024-2026 All Rights Reserved',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: const Color(0xFF64748B).withValues(alpha: 0.8),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: RbxBottomNav(
        currentIndex: 3,
        onTap: widget.onNavTap,
      ),
    );
  }
}

// ─── Career / Quick Stat Card (Original Brand UI) ────────────────────────────

class _CareerStatCard extends StatelessWidget {
  final Widget icon;
  final String value;
  final String title;
  final VoidCallback? onTap;
  final bool isCompact;

  const _CareerStatCard({
    required this.icon,
    required this.value,
    required this.title,
    this.onTap,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      height: isCompact ? 80 : 88,
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 6 : 10,
        vertical: isCompact ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              SizedBox(width: isCompact ? 4 : 6),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: isCompact ? 14 : 16,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              maxLines: 1,
              style: TextStyle(
                fontSize: isCompact ? 10 : 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF868A9F),
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: card);
    }
    return card;
  }
}

// ─── Profile Menu Tile Widget (Original Brand UI with AppColors.primary) ──────

class _ProfileMenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool hasDivider;

  const _ProfileMenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
    required this.hasDivider,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: Color(0xFF94A3B8),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (hasDivider)
          const Divider(
            height: 1,
            color: AppColors.divider,
            indent: 16,
            endIndent: 16,
          ),
      ],
    );
  }
}
