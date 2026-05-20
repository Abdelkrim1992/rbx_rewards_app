import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/bottom_nav.dart';

class ProfileScreen extends StatelessWidget {
  final Function(int) onNavTap;

  const ProfileScreen({super.key, required this.onNavTap});

  int _calculateLevel(int totalCoins) {
    return (totalCoins / 1000).floor() + 1;
  }

  int _xpForCurrentLevel(int totalCoins) {
    return totalCoins % 1000;
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final level = _calculateLevel(appState.totalCoinsEarned);
    final xpCurrent = _xpForCurrentLevel(appState.totalCoinsEarned);
    final xpGoal = 1000;
    final xpProgress = (xpCurrent / xpGoal).clamp(0.0, 1.0);

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
                    const RbxAppHeader(),
                    // Profile card
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppLayout.screenPadding),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
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
                                              child: Image.network(
                                                AppAssets.profileAvatar,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    Container(
                                                  color:
                                                      const Color(0xFFEEEEEF),
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
                                      const Text(
                                        'Player',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF0F172A),
                                        ),
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
                                      TextSpan(
                                        text: ' / $xpGoal XP',
                                        style: const TextStyle(
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
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppLayout.screenPadding),
                      child: GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1.8,
                        children: [
                          _StatCard(
                            iconUrl: AppAssets.fireStreak,
                            value: '${appState.consecutiveDays}',
                            label: 'Day Streak',
                          ),
                          _StatCard(
                            iconUrl: AppAssets.rbxCoinIcon,
                            value: '${appState.coins}',
                            label: 'Total RBX Coins',
                          ),
                          _StatCard(
                            iconUrl: AppAssets.gamepadStat,
                            value: '${appState.gamesPlayed}',
                            label: 'Games Played',
                          ),
                          _StatCard(
                            iconUrl: AppAssets.adsWatched,
                            value: '${appState.offersCompleted}',
                            label: 'Offers Done',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppLayout.sectionSpacing),

                    // Achievements section
                    const Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: AppLayout.screenPadding),
                      child: _SectionHeader(title: 'Achievements'),
                    ),
                    const SizedBox(height: AppLayout.elementSpacing),
                    _AchievementsList(appState: appState),
                    const SizedBox(height: AppLayout.sectionSpacing),

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
                    const SizedBox(height: AppLayout.elementSpacing),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppLayout.screenPadding),
                      child: Container(
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
            Divider(
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

class _AchievementsList extends StatelessWidget {
  final AppState appState;
  const _AchievementsList({required this.appState});

  @override
  Widget build(BuildContext context) {
    final achievements = [
      _AchievementData(
        icon: Icons.sports_esports,
        title: 'First Steps',
        desc: 'Play your first game',
        isUnlocked: appState.gamesPlayed >= 1,
      ),
      _AchievementData(
        icon: Icons.emoji_events,
        title: 'Game Master',
        desc: 'Play 10 games',
        isUnlocked: appState.gamesPlayed >= 10,
      ),
      _AchievementData(
        icon: Icons.monetization_on,
        title: 'Coin Collector',
        desc: 'Earn 1,000 coins',
        isUnlocked: appState.totalCoinsEarned >= 1000,
      ),
      _AchievementData(
        icon: Icons.diamond,
        title: 'Rich Player',
        desc: 'Earn 10,000 coins',
        isUnlocked: appState.totalCoinsEarned >= 10000,
      ),
      _AchievementData(
        icon: Icons.local_fire_department,
        title: 'Daily Regular',
        desc: '7-day streak',
        isUnlocked: appState.consecutiveDays >= 7,
      ),
      _AchievementData(
        icon: Icons.local_offer,
        title: 'Offer Hunter',
        desc: 'Complete 5 offers',
        isUnlocked: appState.offersCompleted >= 5,
      ),
    ];

    return SizedBox(
      height: 110,
      child: ListView.separated(
        padding:
            const EdgeInsets.symmetric(horizontal: AppLayout.screenPadding),
        scrollDirection: Axis.horizontal,
        itemCount: achievements.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final a = achievements[index];
          return _AchievementChip(data: a);
        },
      ),
    );
  }
}

class _AchievementData {
  final IconData icon;
  final String title;
  final String desc;
  final bool isUnlocked;
  const _AchievementData({
    required this.icon,
    required this.title,
    required this.desc,
    required this.isUnlocked,
  });
}

class _AchievementChip extends StatelessWidget {
  final _AchievementData data;
  const _AchievementChip({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color:
            data.isUnlocked ? const Color(0xFFF3F4FE) : const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: data.isUnlocked
              ? const Color(0xFFD5D7FB)
              : const Color(0xFFF3F4F6),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            data.icon,
            size: 28,
            color: data.isUnlocked
                ? const Color(0xFF5C3EF0)
                : const Color(0xFFCBD5E1),
          ),
          const SizedBox(height: 6),
          Text(
            data.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: data.isUnlocked
                  ? const Color(0xFF0F172A)
                  : const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            data.desc,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              color: data.isUnlocked
                  ? const Color(0xFF64748B)
                  : const Color(0xFFCBD5E1),
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteFriendsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
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
                  'Invite Friends',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Earn +500 RBX per invite!',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              final messenger = ScaffoldMessenger.of(context);
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Invite link copied to clipboard!'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Copy Link',
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
