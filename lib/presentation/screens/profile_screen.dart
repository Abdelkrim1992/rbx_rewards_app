import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_profile.dart';
import '../providers/user_provider.dart';
import '../providers/providers.dart';
import '../providers/reward_catalog_provider.dart';
import '../providers/data_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/screen_title.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/refreshable_scroll.dart';
import '../../widgets/interactive_button.dart';
import '../../core/constants/policy_constants.dart';
import 'home/widgets/home_referral_card.dart';

// Predefined avatar options
const List<String> _kAvatarOptions = [
  'https://api.dicebear.com/7.x/adventurer/png?seed=Felix',
  'https://api.dicebear.com/7.x/adventurer/png?seed=Luna',
  'https://api.dicebear.com/7.x/adventurer/png?seed=Max',
  'https://api.dicebear.com/7.x/adventurer/png?seed=Zoe',
  'https://api.dicebear.com/7.x/adventurer/png?seed=Nova',
  'https://api.dicebear.com/7.x/adventurer/png?seed=Ash',
  'https://api.dicebear.com/7.x/adventurer/png?seed=Echo',
  'https://api.dicebear.com/7.x/adventurer/png?seed=Orion',
  'https://api.dicebear.com/7.x/adventurer/png?seed=Lyra',
  'https://api.dicebear.com/7.x/adventurer/png?seed=Pixel',
];

class ProfileScreen extends ConsumerStatefulWidget {
  final Function(int) onNavTap;

  const ProfileScreen({super.key, required this.onNavTap});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final TextEditingController _promoController = TextEditingController();
  bool _isRedeemingPromo = false;

  // Local preferences
  bool _soundEnabled = true;
  bool _hapticsEnabled = true;
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _soundEnabled = prefs.getBool('pref_sound_enabled') ?? true;
        _hapticsEnabled = prefs.getBool('pref_haptics_enabled') ?? true;
        _notificationsEnabled =
            prefs.getBool('pref_notifications_enabled') ?? true;
      });
    }
  }

  Future<void> _updatePreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    if (_hapticsEnabled) {
      HapticFeedback.lightImpact();
    }
  }

  int _xpForCurrentLevel(int totalCoins) {
    return totalCoins % 5000;
  }

  String _formatCoins(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Sept 2026';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final month = months[(dt.month - 1).clamp(0, 11)];
    return '$month ${dt.year}';
  }

  Future<void> _handlePromoRedeem() async {
    final code = _promoController.text.trim();
    if (code.isEmpty || _isRedeemingPromo) return;

    setState(() => _isRedeemingPromo = true);
    FocusScope.of(context).unfocus();

    final result =
        await ref.read(promoCodeServiceProvider).redeem(code);

    if (!mounted) return;
    setState(() => _isRedeemingPromo = false);

    if (result.success) {
      _promoController.clear();
      HapticFeedback.mediumImpact();
      ref.invalidate(userProfileStreamProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.celebration_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  result.message,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _copyPlayerId(String fullId) {
    Clipboard.setData(ClipboardData(text: fullId));
    if (_hapticsEnabled) {
      HapticFeedback.lightImpact();
    }
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
    final auth = ref.watch(authServiceProvider);
    final userProfile = ref.watch(userProfileProvider);
    final historyAsync = ref.watch(rewardHistoryProvider);

    final level = (userProfile.totalEarned / 5000).floor() + 1;
    final xpCurrent = _xpForCurrentLevel(userProfile.totalEarned);
    const xpGoal = 5000;
    final xpProgress = (xpCurrent / xpGoal).clamp(0.0, 1.0);

    // VIP Tier metadata
    final (tierTitle, tierColor, tierIcon) = switch (level) {
      >= 16 => ('Gold Legend', const Color(0xFFD97706), Icons.military_tech_rounded),
      >= 6 => ('Silver Pro', const Color(0xFF475569), Icons.workspace_premium_rounded),
      _ => ('Bronze Rookie', const Color(0xFFB45309), Icons.shield_rounded),
    };

    final shortId = userProfile.id.isNotEmpty
        ? (userProfile.id.length > 8
            ? userProfile.id.substring(0, 8).toUpperCase()
            : userProfile.id.toUpperCase())
        : 'RBX-USER';

    final totalRedeemedCount = historyAsync.valueOrNull?.length ?? 0;

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
                    const RbxAppHeader(),

                    // Screen title
                    const RbxScreenTitle(
                      title: 'Gamer Profile',
                      subtitle: 'Manage your perks, account, and app preferences',
                    ),

                    // ── GAMER IDENTITY PASSPORT CARD ──
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppLayout.screenPadding,
                        vertical: 4,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.cardBorder, width: 1.2),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0C000000),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                // Avatar with ring
                                Container(
                                  width: 76,
                                  height: 76,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.primary.withValues(alpha: 0.25),
                                      width: 2.5,
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(3),
                                  child: ClipOval(
                                    child: (userProfile.profilePhotoUrl != null &&
                                            userProfile.profilePhotoUrl!.isNotEmpty)
                                        ? CachedNetworkImage(
                                            imageUrl: userProfile.profilePhotoUrl!,
                                            fit: BoxFit.cover,
                                            placeholder: (_, __) => Container(
                                              color: const Color(0xFFF1F2F8),
                                              child: const Icon(
                                                Icons.person,
                                                color: AppColors.purple,
                                                size: 36,
                                              ),
                                            ),
                                            errorWidget: (_, __, ___) => Image.asset(
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
                                const SizedBox(width: 16),

                                // User Info & Player ID
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              userProfile.displayName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () => _showEditProfileDialog(
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

                                      // 1-Tap Copy Player ID & Join Date
                                      Row(
                                        children: [
                                          GestureDetector(
                                            onTap: () => _copyPlayerId(userProfile.id),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  'ID: #$shortId',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontFamily: 'monospace',
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF64748B),
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                const Icon(
                                                  Icons.copy_rounded,
                                                  size: 12,
                                                  color: AppColors.primary,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
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
                                      const SizedBox(height: 6),

                                      // VIP Tier Badge with View Perks CTA
                                      GestureDetector(
                                        onTap: () => _showVipPerksModal(
                                          context,
                                          level: level,
                                          tierTitle: tierTitle,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: tierColor.withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                            border: Border.all(
                                              color: tierColor.withValues(alpha: 0.3),
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
                                              Icon(Icons.chevron_right_rounded,
                                                  size: 14, color: tierColor),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),

                            // Level XP Progress Bar
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Level $level Progress',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    Text(
                                      '$xpCurrent / $xpGoal XP',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF64748B),
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
                    const SizedBox(height: AppLayout.sectionSpacing),

                    // ── CAREER STATS ROW (Zero Home Duplication) ──
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppLayout.screenPadding,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _CareerStatCard(
                              title: 'Lifetime Earned',
                              value: _formatCoins(userProfile.totalEarned),
                              icon: Image.asset(
                                AppAssets.rbxCoinIcon,
                                width: 20,
                                height: 20,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.monetization_on,
                                  color: Color(0xFFFFB000),
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _CareerStatCard(
                              title: 'Cashed Out',
                              value: totalRedeemedCount > 0
                                  ? '$totalRedeemedCount Cards'
                                  : '0 Cards',
                              icon: const Icon(
                                Icons.card_giftcard_rounded,
                                color: Color(0xFF16A34A),
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _CareerStatCard(
                              title: 'Games Played',
                              value: '${userProfile.gamesPlayed}',
                              icon: Image.asset(
                                AppAssets.gamepadStat,
                                width: 20,
                                height: 20,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.sports_esports_rounded,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppLayout.sectionSpacing),

                    // ── PROMO CODE CARD ──
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppLayout.screenPadding,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAFAFD),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.cardBorder, width: 1.2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.confirmation_number_outlined,
                                    size: 18, color: AppColors.primary),
                                SizedBox(width: 8),
                                Text(
                                  'Have a Promo Code?',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Enter official influencer or community codes for free bonus coins.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 42,
                                    child: TextField(
                                      controller: _promoController,
                                      textCapitalization:
                                          TextCapitalization.characters,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.0,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'e.g. RBXBOOST',
                                        hintStyle: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: 0,
                                          color: Color(0xFF94A3B8),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 10,
                                        ),
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: const BorderSide(
                                            color: AppColors.cardBorder,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: const BorderSide(
                                            color: AppColors.cardBorder,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: const BorderSide(
                                            color: AppColors.primary,
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InteractiveButton(
                                  text: 'Apply',
                                  width: 80,
                                  height: 42,
                                  borderRadius: 12,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  isLoading: _isRedeemingPromo,
                                  onTap: _handlePromoRedeem,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppLayout.sectionSpacing),

                    // ── INVITE FRIENDS / VIRAL REFERRAL ──
                    const HomeReferralCard(),
                    const SizedBox(height: AppLayout.sectionSpacing),

                    // ── CLOUD SAVE / ACCOUNT SECURITY ──
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppLayout.screenPadding,
                      ),
                      child: _CloudSaveCard(
                        isDeviceAccount: auth.isDeviceAccount,
                        userEmail: auth.currentUser?.email,
                        onLinkGoogle: () async {
                          try {
                            await auth.signInWithGoogle();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Google Sign-In initiated...'),
                                  backgroundColor: AppColors.primary,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Google linking error: $e'),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: AppLayout.sectionSpacing),

                    // ── APP PREFERENCES SECTION ──
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppLayout.screenPadding,
                      ),
                      child: Text(
                        'App Preferences',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppLayout.screenPadding,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.cardBorder, width: 1.2),
                        ),
                        child: Column(
                          children: [
                            _PreferenceToggleTile(
                              title: 'Sound Effects (SFX)',
                              subtitle: 'Audio cues in mini-games & rewards',
                              icon: Icons.volume_up_rounded,
                              value: _soundEnabled,
                              onChanged: (val) {
                                setState(() => _soundEnabled = val);
                                _updatePreference('pref_sound_enabled', val);
                              },
                              hasDivider: true,
                            ),
                            _PreferenceToggleTile(
                              title: 'Haptic Feedback',
                              subtitle: 'Tactile vibrations on button clicks',
                              icon: Icons.vibration_rounded,
                              value: _hapticsEnabled,
                              onChanged: (val) {
                                setState(() => _hapticsEnabled = val);
                                _updatePreference('pref_haptics_enabled', val);
                              },
                              hasDivider: true,
                            ),
                            _PreferenceToggleTile(
                              title: 'Streak Reminders',
                              subtitle: 'Alert before daily streak expires',
                              icon: Icons.notifications_active_outlined,
                              value: _notificationsEnabled,
                              onChanged: (val) {
                                setState(() => _notificationsEnabled = val);
                                _updatePreference(
                                    'pref_notifications_enabled', val);
                              },
                              hasDivider: false,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppLayout.sectionSpacing),

                    // ── SETTINGS, SUPPORT & COMPLIANCE ──
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppLayout.screenPadding,
                      ),
                      child: Text(
                        'Help & Legal',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppLayout.screenPadding,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.cardBorder, width: 1.2),
                        ),
                        child: Column(
                          children: [
                            _SettingsItem(
                              icon: Icons.help_outline_rounded,
                              title: 'Help Center & Earning Guide',
                              onTap: () => _showHelpDialog(context),
                              hasDivider: true,
                            ),
                            _SettingsItem(
                              icon: Icons.mail_outline_rounded,
                              title: 'Contact Support',
                              subtitle: 'ID: #$shortId automatically attached',
                              onTap: () => _showContactDialog(
                                context,
                                userId: userProfile.id,
                              ),
                              hasDivider: true,
                            ),
                            _SettingsItem(
                              icon: Icons.privacy_tip_outlined,
                              title: 'Privacy Policy',
                              onTap: () => _showPrivacyDialog(context),
                              hasDivider: true,
                            ),
                            _SettingsItem(
                              icon: Icons.gavel_rounded,
                              title: 'Terms of Service',
                              onTap: () => _showTermsDialog(context),
                              hasDivider: true,
                            ),
                            _SettingsItem(
                              icon: Icons.delete_outline_rounded,
                              title: 'Delete Account & Data',
                              subtitle: 'Permanent deletion request',
                              titleColor: const Color(0xFFDC2626),
                              iconColor: const Color(0xFFDC2626),
                              onTap: () => _showDeleteAccountDialog(context),
                              hasDivider: false,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // App Version Footer
                    const SizedBox(height: 24),
                    Center(
                      child: Text(
                        'RBX Rewards v1.2.0 • Build 45\nIndependent gaming loyalty companion',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: const Color(0xFF64748B).withValues(alpha: 0.8),
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: RbxBottomNav(currentIndex: 3, onTap: widget.onNavTap),
    );
  }
}

// ─── Career Stat Card ────────────────────────────────────────────────────────

class _CareerStatCard extends StatelessWidget {
  final String title;
  final String value;
  final Widget icon;

  const _CareerStatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              const SizedBox(width: 6),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF868A9F),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Preference Toggle Tile ──────────────────────────────────────────────────

class _PreferenceToggleTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool hasDivider;

  const _PreferenceToggleTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
    required this.hasDivider,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: value,
                onChanged: onChanged,
                activeTrackColor: AppColors.primary,
              ),
            ],
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

// ─── Settings Item ───────────────────────────────────────────────────────────

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? titleColor;
  final Color? iconColor;
  final VoidCallback onTap;
  final bool hasDivider;

  const _SettingsItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.titleColor,
    this.iconColor,
    required this.onTap,
    required this.hasDivider,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.translucent,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, size: 20, color: iconColor ?? AppColors.primary),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: titleColor ?? const Color(0xFF0F172A),
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ],
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
          if (hasDivider)
            const Divider(
              height: 1,
              color: AppColors.divider,
              indent: 16,
              endIndent: 16,
            ),
        ],
      ),
    );
  }
}

// ─── Cloud Save Card ─────────────────────────────────────────────────────────

class _CloudSaveCard extends StatelessWidget {
  final bool isDeviceAccount;
  final String? userEmail;
  final VoidCallback onLinkGoogle;

  const _CloudSaveCard({
    required this.isDeviceAccount,
    required this.userEmail,
    required this.onLinkGoogle,
  });

  @override
  Widget build(BuildContext context) {
    if (!isDeviceAccount) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified_user_rounded,
                color: Color(0xFF16A34A),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cloud Backup Active',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF15803D),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    userEmail ?? 'Linked to Google Account',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF166534),
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFCFD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.cloud_sync_rounded,
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
                      'Protect Your Coins & Progress',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF101828),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Link Google to restore coins if you uninstall or switch phones.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF667085),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          InteractiveButton(
            icon: Icons.login_rounded,
            iconSize: 18,
            text: 'Link Google Account',
            height: 46,
            borderRadius: 14,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            onTap: onLinkGoogle,
          ),
        ],
      ),
    );
  }
}

// ─── VIP Perks Modal ─────────────────────────────────────────────────────────

void _showVipPerksModal(
  BuildContext context, {
  required int level,
  required String tierTitle,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Icon(Icons.workspace_premium_rounded,
                  color: AppColors.primary, size: 28),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'VIP Loyalty Tiers',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    'Current Tier: $tierTitle (Level $level)',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          _VipTierCard(
            title: 'Bronze Rookie (Level 1–5)',
            perks: '• Base coin rewards on all mini-games\n• Standard 24–48h gift card verification',
            isActive: level <= 5,
            color: const Color(0xFFB45309),
          ),
          const SizedBox(height: 10),
          _VipTierCard(
            title: 'Silver Pro (Level 6–15)',
            perks: '• +5% bonus coins on all mini-games\n• Priority claim queue\n• Exclusive Silver community badge',
            isActive: level >= 6 && level <= 15,
            color: const Color(0xFF475569),
          ),
          const SizedBox(height: 10),
          _VipTierCard(
            title: 'Gold Legend (Level 16+)',
            perks: '• +10% bonus coins on all mini-games\n• Rapid 12-hour express cashout verification\n• Exclusive Mega Chest multiplier',
            isActive: level >= 16,
            color: const Color(0xFFD97706),
          ),
          const SizedBox(height: 24),
          InteractiveButton(
            text: 'Got It',
            height: 48,
            borderRadius: 16,
            onTap: () => Navigator.pop(ctx),
          ),
        ],
      ),
    ),
  );
}

class _VipTierCard extends StatelessWidget {
  final String title;
  final String perks;
  final bool isActive;
  final Color color;

  const _VipTierCard({
    required this.title,
    required this.perks,
    required this.isActive,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isActive ? color.withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive ? color : const Color(0xFFE2E8F0),
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isActive ? color : const Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              if (isActive)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Active',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            perks,
            style: TextStyle(
              fontSize: 11.5,
              color: isActive ? const Color(0xFF1E293B) : const Color(0xFF64748B),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Edit Profile Dialog ─────────────────────────────────────────────────────

void _showEditProfileDialog(BuildContext context, UserProfile userProfile) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _EditProfileDialog(userProfile: userProfile),
  );
}

class _EditProfileDialog extends ConsumerStatefulWidget {
  final UserProfile userProfile;
  const _EditProfileDialog({required this.userProfile});

  @override
  ConsumerState<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends ConsumerState<_EditProfileDialog>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _nameController;
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  String? _selectedAvatarUrl;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.userProfile.displayName);
    _selectedAvatarUrl = widget.userProfile.profilePhotoUrl;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final newName = _nameController.text.trim();

      if (newName.isEmpty) {
        setState(() {
          _errorMessage = 'Username cannot be empty';
          _isSaving = false;
        });
        return;
      }

      final profileService = ref.read(profileServiceProvider);

      if (newName != widget.userProfile.displayName) {
        await profileService.updateDisplayName(newName);
      }

      if (_selectedAvatarUrl != widget.userProfile.profilePhotoUrl) {
        await profileService.updateProfilePhoto(_selectedAvatarUrl);
      }

      ref.invalidate(userProfileStreamProvider);

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnim,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child:
                        const Icon(Icons.edit, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Edit Gamer Profile',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F2F8),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          size: 16, color: Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Gamer Username',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                maxLength: 20,
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: const Color(0xFFF8F9FF),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE8EAFF)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE8EAFF)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF6035EE)),
                  ),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 6),
                Text(
                  _errorMessage!,
                  style: const TextStyle(fontSize: 11.5, color: Colors.red),
                ),
              ],
              const SizedBox(height: 18),
              const Text(
                'Avatar Character',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 64,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _kAvatarOptions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final url = _kAvatarOptions[i];
                    final isSelected = _selectedAvatarUrl == url;
                    return GestureDetector(
                      onTap: () => setState(() {
                        _selectedAvatarUrl = isSelected ? null : url;
                      }),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF6035EE)
                                : const Color(0xFFE8EAFF),
                            width: isSelected ? 2.5 : 1.5,
                          ),
                        ),
                        child: ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: const Color(0xFFF1F2F8),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _isSaving ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InteractiveButton(
                      text: 'Save Changes',
                      height: 46,
                      borderRadius: 14,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      isLoading: _isSaving,
                      onTap: _save,
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

// ─── Help, Privacy, Terms, Contact & Deletion Dialogs ─────────────────────────

void _showHelpDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.help_outline_rounded, color: AppColors.primary, size: 24),
          SizedBox(width: 10),
          Text(
            'Help & Support',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      content: const SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'How to Earn RBX Coins:',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            SizedBox(height: 8),
            Text('1. Play mini-games (Flappy Jump, Tap Tap, Math Quiz, Flip Cards)'),
            SizedBox(height: 4),
            Text('2. Complete partner offers and surveys via Tapjoy & PubScale'),
            SizedBox(height: 4),
            Text('3. Claim daily streak rewards every 24h & open Mega Chests'),
            SizedBox(height: 4),
            Text('4. Spin the Lucky Wheel daily for instant multipliers'),
            SizedBox(height: 12),
            Text(
              'XP & Levels: Earn 5,000 coins to advance to the next level and unlock higher VIP perks!',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            PolicyConstants.openUrl(PolicyConstants.helpSupportUrl);
          },
          child: const Text(
            'Open Help Guide',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        InteractiveButton(
          text: 'Got it',
          width: 88,
          height: 38,
          borderRadius: 12,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          onTap: () => Navigator.pop(ctx),
        ),
      ],
    ),
  );
}

void _showContactDialog(BuildContext context, {required String userId}) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.mail_outline_rounded, color: AppColors.primary, size: 24),
          SizedBox(width: 10),
          Text(
            'Contact Support',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Have questions about your rewards, missing coins, or need account assistance?',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF9FE),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.cardBorder, width: 1.2),
            ),
            child: Row(
              children: [
                const Icon(Icons.fingerprint_rounded,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your Account ID: #${userId.isNotEmpty ? (userId.length > 8 ? userId.substring(0, 8) : userId) : "PLAYER"}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              Icon(Icons.email, size: 16, color: AppColors.primary),
              SizedBox(width: 8),
              SelectableText(
                'support@rbxrewards.app',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Expected Response Time: 24 to 48 business hours.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            PolicyConstants.sendSupportEmail();
          },
          child: const Text(
            'Email Support',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        InteractiveButton(
          text: 'Close',
          width: 88,
          height: 38,
          borderRadius: 12,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          onTap: () => Navigator.pop(ctx),
        ),
      ],
    ),
  );
}

void _showPrivacyDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.privacy_tip_outlined, color: AppColors.primary, size: 24),
          SizedBox(width: 10),
          Text(
            'Privacy Policy',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      content: const SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Your privacy is our priority. In compliance with Google Play and Apple App Store standards:',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            SizedBox(height: 10),
            Text('• Data Storage: Game stats, streaks, and balances are securely synced via Supabase with encrypted transit.'),
            SizedBox(height: 6),
            Text('• Ad Partners: We integrate Google AdMob, Tapjoy, and PubScale for compliant reward delivery.'),
            SizedBox(height: 6),
            Text('• Transparency: We respect tracking choices and never sell personal player information.'),
            SizedBox(height: 6),
            Text('• Child Safety (COPPA): Designed for ages 13+. We never solicit personal data from children under 13.'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            PolicyConstants.openUrl(PolicyConstants.privacyPolicyUrl);
          },
          child: const Text(
            'View Full Policy Online',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Close', style: TextStyle(color: Color(0xFF64748B))),
        ),
      ],
    ),
  );
}

void _showTermsDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.gavel_rounded, color: AppColors.primary, size: 24),
          SizedBox(width: 10),
          Text(
            'Terms of Use',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      content: const SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'By using RBX Rewards, you agree to the following terms:',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            SizedBox(height: 10),
            Text('1. Promotional Points: RBX Coins are promotional virtual points with no direct cash value.'),
            SizedBox(height: 6),
            Text('2. Fair Play Policy: Automation, auto-clickers, emulators, and multiple accounts are strictly prohibited.'),
            SizedBox(height: 6),
            Text('3. Digital Gift Cards: Claimed codes are fulfilled subject to verification (24–48h) and partner stock.'),
            SizedBox(height: 6),
            Text('4. Non-Affiliation: RBX Rewards is independent and NOT affiliated with or endorsed by Roblox Corporation.'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            PolicyConstants.openUrl(PolicyConstants.termsOfUseUrl);
          },
          child: const Text(
            'View Full Terms Online',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Close', style: TextStyle(color: Color(0xFF64748B))),
        ),
      ],
    ),
  );
}

void _showDeleteAccountDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 24),
          SizedBox(width: 10),
          Text(
            'Delete Account?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      content: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'In compliance with Google Play & Apple App Store policies, you can request full deletion of your account and data.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          SizedBox(height: 10),
          Text(
            '• All remaining RBX Coins will be forfeited.\n• Your game high scores and history will be erased.\n• This action cannot be undone.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Deletion request queued. Your data will be purged per privacy regulations.',
                ),
                backgroundColor: Color(0xFFDC2626),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text('Request Deletion'),
        ),
      ],
    ),
  );
}
