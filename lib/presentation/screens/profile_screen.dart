import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user_profile.dart';
import '../providers/user_provider.dart';
import '../providers/providers.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/screen_title.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/refreshable_scroll.dart';
import '../../core/constants/policy_constants.dart';

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

class ProfileScreen extends ConsumerWidget {
  final Function(int) onNavTap;

  const ProfileScreen({super.key, required this.onNavTap});

  int _xpForCurrentLevel(int totalCoins) {
    return totalCoins % 5000;
  }

  String _formatCoins(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authServiceProvider);
    final userProfile = ref.watch(userProfileProvider);
    final level = (userProfile.totalEarned / 5000).floor() + 1;
    final xpCurrent = _xpForCurrentLevel(userProfile.totalEarned);
    const xpGoal = 5000;
    final xpProgress = (xpCurrent / xpGoal).clamp(0.0, 1.0);

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
                      title: 'My Profile',
                      subtitle: 'Track your progress and manage your account',
                    ),
                    // Profile card
                    Padding(
                      padding: const EdgeInsets.only(
                          left: AppLayout.screenPadding,
                          right: AppLayout.screenPadding,
                          top: 5),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: const Color(0xFFF3F4F6)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1A000000),
                              blurRadius: 2,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                // Avatar with rings
                                Container(
                                  width: 90,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: const Color(0xFFE1E2FC),
                                        width: 1),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(3),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: const Color(0xFFD5D7FB),
                                            width: 1),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(3),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: const Color(0xFFC6C9FA),
                                                width: 1),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(4),
                                            child: ClipOval(
                                              child: (userProfile.profilePhotoUrl !=
                                                        null &&
                                                    userProfile
                                                        .profilePhotoUrl!
                                                        .isNotEmpty)
                                                ? CachedNetworkImage(
                                                    imageUrl: userProfile
                                                        .profilePhotoUrl!,
                                                    fit: BoxFit.cover,
                                                    placeholder: (_, __) =>
                                                        Container(
                                                      color: const Color(
                                                          0xFFEEEEEF),
                                                      child: const Icon(
                                                        Icons.person,
                                                        size: 40,
                                                        color: AppColors.purple,
                                                      ),
                                                    ),
                                                    errorWidget:
                                                        (_, __, ___) =>
                                                            Image.asset(
                                                      AppAssets.profileAvatar,
                                                      fit: BoxFit.cover,
                                                      errorBuilder:
                                                          (_, __, ___) =>
                                                              Container(
                                                        color: const Color(
                                                            0xFFEEEEEF),
                                                        child: const Icon(
                                                          Icons.person,
                                                          size: 40,
                                                          color:
                                                              AppColors.purple,
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                : Image.asset(
                                                    AppAssets.profileAvatar,
                                                    fit: BoxFit.cover,
                                                    errorBuilder:
                                                        (_, __, ___) =>
                                                            Container(
                                                      color: const Color(
                                                          0xFFEEEEEF),
                                                      child: const Icon(
                                                        Icons.person,
                                                        size: 40,
                                                        color: AppColors.purple,
                                                      ),
                                                    ),
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
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
                                              style: const TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.w600,
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
                                                color: const Color(0xFFF3F4FE),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                    color: const Color(
                                                        0xFFD5D7FB)),
                                              ),
                                              child: const Icon(
                                                Icons.edit,
                                                size: 16,
                                                color: Color(0xFF5C3EF0),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.fromLTRB(
                                            6, 4, 12, 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF3F4FE),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CachedNetworkImage(
                                              imageUrl: AppAssets.levelBadge,
                                              width: 21,
                                              height: 21,
                                              placeholder: (_, __) =>
                                                  const SizedBox(
                                                width: 21,
                                                height: 21,
                                              ),
                                              errorWidget: (_, __, ___) =>
                                                  const Icon(
                                                      Icons.military_tech,
                                                      size: 21,
                                                      color: Color(0xFF5C3EF0)),
                                            ),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                'Level $level',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: Color(0xFF5C3EF0),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            // XP bar
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Stack(
                                  children: [
                                    Container(
                                      height: 8,
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
                                        height: 8,
                                        decoration: BoxDecoration(
                                          gradient: AppColors.xpBarGradient,
                                          borderRadius:
                                              BorderRadius.circular(999),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Color(0x806B4BF4),
                                              blurRadius: 8,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '$xpCurrent',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF334155),
                                        ),
                                      ),
                                      const TextSpan(
                                        text: ' / $xpGoal XP',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF334155),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppLayout.sectionSpacing),

                    // Stats cards row
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppLayout.screenPadding),
                      child: Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              title: 'Daily Streak',
                              icon: const Text('🔥', style: TextStyle(fontSize: 20)),
                              valueWidget: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${userProfile.consecutiveDays}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF131326),
                                    ),
                                  ),
                                  // const Text(
                                  //   'Days',
                                  //   style: TextStyle(
                                  //     fontSize: 10,
                                  //     color: Color(0xFF868A9F),
                                  //     fontWeight: FontWeight.w600,
                                  //   ),
                                  // ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _StatCard(
                              title: 'Total Coins',
                              icon: Image.asset(
                                AppAssets.rbxCoinIcon,
                                width: 24,
                                height: 24,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.monetization_on,
                                  color: Color(0xFFFFB000),
                                  size: 24,
                                ),
                              ),
                              valueWidget: Text(
                                _formatCoins(userProfile.totalEarned),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF131326),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _StatCard(
                              title: 'Games Played',
                              icon: Image.asset(
                                AppAssets.gamepadStat,
                                width: 24,
                                height: 24,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.sports_esports_rounded,
                                  color: Color(0xFF1E293B),
                                  size: 24,
                                ),
                              ),
                              valueWidget: Text(
                                '${userProfile.gamesPlayed}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF131326),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Cloud Save / Account Security Card
                    const SizedBox(height: AppLayout.sectionSpacing),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppLayout.screenPadding),
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
                                  backgroundColor: Color(0xFF5C3EF0),
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

                    // Settings & Support
                    const Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: AppLayout.screenPadding),
                      child: _SectionHeader(title: 'Settings & Support'),
                    ),
                    const SizedBox(height: AppLayout.sectionSpacing),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppLayout.screenPadding),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: const Color(0xFFF3F4F6)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1A000000),
                              blurRadius: 2,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _SettingsLink(
                              iconUrl: AppAssets.helpIcon,
                              title: 'Help & Support',
                              hasDivider: true,
                              onTap: () => _showHelpDialog(context),
                            ),
                            _SettingsLink(
                              iconUrl: AppAssets.privacyIcon,
                              title: 'Privacy Policy',
                              hasDivider: true,
                              onTap: () => _showPrivacyDialog(context),
                            ),
                            _SettingsLink(
                              iconUrl: AppAssets.termsIcon,
                              title: 'Terms',
                              hasDivider: true,
                              onTap: () => _showTermsDialog(context),
                            ),
                            _SettingsLink(
                              iconUrl: AppAssets.contactIcon,
                              title: 'Contact Support',
                              hasDivider: false,
                              onTap: () => _showContactDialog(context),
                            ),
                          ],
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
      bottomNavigationBar: RbxBottomNav(currentIndex: 3, onTap: onNavTap),
    );
  }
}

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
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified_user_rounded,
                color: Color(0xFF16A34A),
                size: 24,
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
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF15803D),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    userEmail ?? 'Linked to Google Account',
                    style: const TextStyle(
                      fontSize: 12,
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
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE0DCFA)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A5C3EF0),
            blurRadius: 10,
            offset: Offset(0, 4),
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
                  color: const Color(0xFFF3F1FE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.cloud_sync_rounded,
                  color: Color(0xFF5C3EF0),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Protect Your Robux',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF101828),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Link Google to restore coins if you uninstall or switch phones.',
                      style: TextStyle(
                        fontSize: 12,
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
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton.icon(
              onPressed: onLinkGoogle,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5C3EF0),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.login_rounded, size: 16),
              label: const Text(
                'Link Google Account',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final Widget icon;
  final Widget valueWidget;

  const _StatCard({
    required this.title,
    required this.icon,
    required this.valueWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF868A9F),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: valueWidget,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsLink extends StatelessWidget {
  final String iconUrl;
  final String title;
  final bool hasDivider;
  final VoidCallback? onTap;

  const _SettingsLink({
    required this.iconUrl,
    required this.title,
    required this.hasDivider,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.translucent,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                SizedBox(
                  width: 36,
                  height: 24,
                  child: CachedNetworkImage(
                    imageUrl: iconUrl,
                    fit: BoxFit.contain,
                    placeholder: (_, __) =>
                        const SizedBox(width: 24, height: 24),
                    errorWidget: (_, __, ___) => const Icon(Icons.info_outline,
                        size: 22, color: AppColors.purple),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right,
                    size: 18, color: Color(0xFF94A3B8)),
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

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: Color(0xFF0F172A),
      ),
    );
  }
}


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
    _nameController = TextEditingController(text: widget.userProfile.displayName);
    _selectedAvatarUrl = widget.userProfile.profilePhotoUrl;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
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
      
      // Validate username is not empty
      if (newName.isEmpty) {
        setState(() {
          _errorMessage = 'Username cannot be empty';
          _isSaving = false;
        });
        return;
      }
      
      final profileService = ref.read(profileServiceProvider);

      // Update name if changed
      if (newName != widget.userProfile.displayName) {
        await profileService.updateDisplayName(newName);
      }
      
      // Update photo if changed
      if (_selectedAvatarUrl != widget.userProfile.profilePhotoUrl) {
        await profileService.updateProfilePhoto(_selectedAvatarUrl);
      }
      
      // Force immediate re-fetch of the profile from backend (which hits the freshly invalidated cache)
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
              // Header
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
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
                      'Edit Profile',
                      style: TextStyle(
                        fontSize: 20,
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
              const SizedBox(height: 24),

              // Username field
              const Text(
                'Username',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                maxLength: 20,
                onChanged: (_) {
                  // Clear error when user types
                  if (_errorMessage != null) {
                    setState(() => _errorMessage = null);
                  }
                },
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  hintText: 'Enter your username',
                  hintStyle: const TextStyle(
                    color: Color(0xFFB0B8C8),
                    fontSize: 15,
                  ),
                  counterText: '',
                  filled: true,
                  fillColor: const Color(0xFFF8F9FF),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: Color(0xFFE8EAFF), width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: Color(0xFFE8EAFF), width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: Color(0xFF6035EE), width: 1.5),
                  ),
                  prefixIcon: const Icon(Icons.person_outline,
                      color: Color(0xFF6035EE), size: 20),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 22),

              // Avatar section
              const Text(
                'Profile Photo',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Pick an avatar — optional',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFFB0B8C8),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _kAvatarOptions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) {
                    final url = _kAvatarOptions[i];
                    final isSelected = _selectedAvatarUrl == url;
                    return GestureDetector(
                      onTap: () => setState(() {
                        // Toggle off if already selected
                        _selectedAvatarUrl = isSelected ? null : url;
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF6035EE)
                                : const Color(0xFFE8EAFF),
                            width: isSelected ? 3 : 1.5,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF6035EE)
                                        .withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : [],
                        ),
                        child: ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: const Color(0xFFF1EDFF),
                              child: const Center(
                                child: SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFF6035EE),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: const Color(0xFFF1EDFF),
                              child: const Icon(
                                Icons.person,
                                color: Color(0xFF6035EE),
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 28),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _isSaving ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: Color(0xFFE8EAFF), width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6035EE).withOpacity(0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Save Changes',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
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
      ),
    );
  }
}

void _showHelpDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.help_outline_rounded, color: AppColors.purple, size: 24),
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
              'XP & Levels: Earn 5,000 coins to advance to the next level!',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.purple,
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
          child: const Text('Open Help Guide', style: TextStyle(color: AppColors.purple, fontWeight: FontWeight.w600)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.purple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Got it'),
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
          Icon(Icons.privacy_tip_outlined, color: AppColors.purple, size: 24),
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
              'Your privacy is our priority. In compliance with Google Play and Apple App Store privacy standards:',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            SizedBox(height: 10),
            Text('• Data Storage: Game stats, streaks, and balances are stored locally and securely synced via Supabase.'),
            SizedBox(height: 6),
            Text('• Ad Partners: We integrate Google AdMob, Tapjoy, and PubScale to deliver compliant ads and offerwall rewards.'),
            SizedBox(height: 6),
            Text('• Transparency: We respect Apple ATT tracking choices and never sell personal data.'),
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
          child: const Text('View Full Policy Online', style: TextStyle(color: AppColors.purple, fontWeight: FontWeight.w600)),
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
          Icon(Icons.gavel_rounded, color: AppColors.purple, size: 24),
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
              'By playing RBX Rewards, you agree to the following terms:',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            SizedBox(height: 10),
            Text('1. Promotional Nature: RBX Coins are promotional virtual points with no cash value.'),
            SizedBox(height: 6),
            Text('2. Fair Play: Automation, auto-clickers, emulators, and multiple accounts are strictly prohibited and result in permanent bans.'),
            SizedBox(height: 6),
            Text('3. Digital Rewards: Claimed gift cards are fulfilled subject to verification (24–72h) and inventory availability.'),
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
          child: const Text('View Full Terms Online', style: TextStyle(color: AppColors.purple, fontWeight: FontWeight.w600)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Close', style: TextStyle(color: Color(0xFF64748B))),
        ),
      ],
    ),
  );
}

void _showContactDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.mail_outline_rounded, color: AppColors.purple, size: 24),
          SizedBox(width: 10),
          Text(
            'Contact Support',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      content: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Have questions about your rewards, a bug report, or need account assistance?',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.email, size: 16, color: AppColors.purple),
              SizedBox(width: 8),
              SelectableText(
                'support@rbxrewards.app',
                style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
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
          child: const Text('Email Support', style: TextStyle(color: AppColors.purple, fontWeight: FontWeight.w700)),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            PolicyConstants.openUrl(PolicyConstants.contactSupportUrl);
          },
          child: const Text('Support Portal', style: TextStyle(color: AppColors.purple)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Close', style: TextStyle(color: Color(0xFF64748B))),
        ),
      ],
    ),
  );
}
