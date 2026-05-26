import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/refreshable_scroll.dart';

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

class ProfileScreen extends StatelessWidget {
  final Function(int) onNavTap;

  const ProfileScreen({super.key, required this.onNavTap});

  int _xpForCurrentLevel(int totalCoins) {
    return totalCoins % 5000;
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final level = appState.level;
    final xpCurrent = _xpForCurrentLevel(appState.totalCoinsEarned);
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
                padding: const EdgeInsets.only(top: 12, bottom: 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const RbxAppHeader(),
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
                                              child: appState.profilePhotoUrl !=
                                                      null
                                                  ? Image.network(
                                                      appState.profilePhotoUrl!,
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
                                                    )
                                                  : Image.network(
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
                                              appState.displayName,
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
                                                context, appState),
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
                                            Image.network(
                                              AppAssets.levelBadge,
                                              width: 21,
                                              height: 21,
                                              errorBuilder: (_, __, ___) =>
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

                    // Stats grid
                    // Padding(
                    //   padding: const EdgeInsets.symmetric(
                    //       horizontal: AppLayout.screenPadding),
                    //   child: GridView.count(
                    //     crossAxisCount: 2,
                    //     shrinkWrap: true,
                    //     padding: EdgeInsets.zero,
                    //     physics: const NeverScrollableScrollPhysics(),
                    //     mainAxisSpacing: 8,
                    //     crossAxisSpacing: 8,
                    //     childAspectRatio: 1.8,
                    //     children: [
                    //       // _StatCard(
                    //       //   iconUrl: AppAssets.fireStreak,
                    //       //   value: '${appState.consecutiveDays}',
                    //       //   label: 'Day Streak',
                    //       // ),
                    //       _StatCard(
                    //         iconUrl: AppAssets.rbxCoinIcon,
                    //         value: '${appState.coins}',
                    //         label: 'Total RBX Coins',
                    //       ),
                    //       _StatCard(
                    //         iconUrl: AppAssets.gamepadStat,
                    //         value: '${appState.totalGamesPlayed}',
                    //         label: 'Games Played',
                    //       ),
                    //       // _StatCard(
                    //       //   iconUrl: AppAssets.adsWatched,
                    //       //   value: '${appState.totalOffersCompleted}',
                    //       //   label: 'Offers Done',
                    //       // ),
                    //     ],
                    //   ),
                    // ),
                    // const SizedBox(height: AppLayout.sectionSpacing),

                    // Invite Friends
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppLayout.screenPadding),
                      child: _InviteFriendsCard(),
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
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: RbxBottomNav(currentIndex: 4, onTap: onNavTap),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String iconUrl;
  final String value;
  final String label;

  const _StatCard({
    required this.iconUrl,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
      child: Row(
        children: [
          iconUrl.startsWith('http')
              ? Image.network(
                  iconUrl,
                  width: 32,
                  height: 32,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.star,
                      size: 32, color: AppColors.primary),
                )
              : Image.asset(
                  iconUrl,
                  width: 32,
                  height: 32,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.star,
                      size: 32, color: AppColors.primary),
                ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF64748B),
                    height: 1.1,
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
                  child: Image.network(
                    iconUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(Icons.info_outline,
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

class _InviteFriendsCard extends StatelessWidget {
  // Static mock data for referral system
  final String referralCode = 'RBX-7A2F';
  final int friendsJoined = 3;
  final int coinsEarnedFromReferrals = 500;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 2,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.people, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Refer & Earn',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Earn 10% from friends\' offerwall earnings forever',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Referral Code Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'YOUR CODE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Colors.white.withOpacity(0.7),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      referralCode,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    final messenger = ScaffoldMessenger.of(context);
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Referral code copied!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Copy',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Stats row
          Row(
            children: [
              Expanded(
                child: _ReferralStat(
                  value: '$friendsJoined',
                  label: 'Friends Joined',
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withOpacity(0.2),
              ),
              Expanded(
                child: _ReferralStat(
                  value: '+$coinsEarnedFromReferrals',
                  label: 'RBX Earned',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReferralStat extends StatelessWidget {
  final String value;
  final String label;

  const _ReferralStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

void _showEditProfileDialog(BuildContext context, AppState appState) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _EditProfileDialog(appState: appState),
  );
}

class _EditProfileDialog extends StatefulWidget {
  final AppState appState;
  const _EditProfileDialog({required this.appState});

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _nameController;
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  String? _selectedAvatarUrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.appState.displayName);
    _selectedAvatarUrl = widget.appState.profilePhotoUrl;
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
    setState(() => _isSaving = true);
    final newName = _nameController.text.trim();
    // Update name if changed and not empty
    if (newName.isNotEmpty && newName != widget.appState.displayName) {
      await widget.appState.updateDisplayName(newName);
    }
    // Update photo if changed
    if (_selectedAvatarUrl != widget.appState.profilePhotoUrl) {
      await widget.appState.updateProfilePhoto(_selectedAvatarUrl);
    }
    if (mounted) Navigator.pop(context);
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
                          child: Image.network(
                            url,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
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
    builder: (_) => AlertDialog(
      title: const Text('Help & Support'),
      content: const Text(
        'How to earn RBX:\n\n'
        '1. Play mini-games to earn coins\n'
        '2. Complete offers and surveys\n'
        '3. Claim your daily reward every 24h\n'
        '4. Spin the wheel for bonus coins\n'
        '5. Invite friends for +500 RBX each\n\n'
        'Reach higher levels by earning more coins!',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
}

void _showPrivacyDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Privacy Policy'),
      content: const SingleChildScrollView(
        child: Text(
          'We value your privacy. This app does not collect personal information or require user registration. '
          'All data is stored locally on your device using SharedPreferences. '
          'We do not share your data with third parties. '
          'Coin balances and game progress are kept on-device only.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

void _showTermsDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Terms of Use'),
      content: const SingleChildScrollView(
        child: Text(
          'By using this app, you agree to:\n\n'
          '1. Use the app for entertainment purposes only\n'
          '2. Not exploit or manipulate reward systems\n'
          '3. Accept that rewards are virtual and non-transferable\n'
          '4. Understand that all stats are stored locally on your device\n\n'
          'We reserve the right to update these terms at any time.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

void _showContactDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Contact Support'),
      content: const Text(
        'Need help? Reach out to us at:\n\n'
        'support@rbxrewards.app\n\n'
        'We typically respond within 24-48 hours.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
