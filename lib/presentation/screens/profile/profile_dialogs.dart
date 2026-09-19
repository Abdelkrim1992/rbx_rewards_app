import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/policy_constants.dart';
import '../../../models/user_profile.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/interactive_button.dart';
import '../../providers/coin_provider.dart';
import '../../providers/data_providers.dart';
import '../../providers/providers.dart';
import '../../providers/user_provider.dart';

// Predefined avatar options
const List<String> kAvatarOptions = [
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

// ─── VIP Perks Modal ─────────────────────────────────────────────────────────

void showVipPerksModal(
  BuildContext context, {
  required int level,
  required String tierTitle,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
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
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.workspace_premium_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'VIP Loyalty Tiers',
                          style: TextStyle(
                            fontSize: 17,
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
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _VipTierCard(
                title: 'Bronze Rookie (Level 1–5)',
                tierIcon: Icons.shield_rounded,
                perks: const [
                  'Base coin rewards on all mini-games',
                  'Standard 24–48h gift card verification',
                ],
                isActive: level <= 5,
                color: const Color(0xFFB45309),
              ),
              const SizedBox(height: 8),
              _VipTierCard(
                title: 'Silver Pro (Level 6–15)',
                tierIcon: Icons.workspace_premium_rounded,
                perks: const [
                  '+5% bonus coins on all mini-games',
                  'Priority claim queue',
                  'Exclusive Silver community badge',
                ],
                isActive: level >= 6 && level <= 15,
                color: const Color(0xFF475569),
              ),
              const SizedBox(height: 8),
              _VipTierCard(
                title: 'Gold Legend (Level 16+)',
                tierIcon: Icons.military_tech_rounded,
                perks: const [
                  '+10% bonus coins on all mini-games',
                  'Rapid 12-hour express cashout verification',
                  'Exclusive Mega Chest multiplier',
                ],
                isActive: level >= 16,
                color: const Color(0xFFD97706),
              ),
              const SizedBox(height: 16),
              InteractiveButton(
                text: 'Got It',
                height: 46,
                borderRadius: 14,
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _VipTierCard extends StatelessWidget {
  final String title;
  final IconData tierIcon;
  final List<String> perks;
  final bool isActive;
  final Color color;

  const _VipTierCard({
    required this.title,
    required this.tierIcon,
    required this.perks,
    required this.isActive,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isActive ? color.withValues(alpha: 0.07) : const Color(0xFFF8FAFC),
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
              Icon(tierIcon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isActive ? color : const Color(0xFF0F172A),
                  ),
                ),
              ),
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
          ...perks.map(
            (perk) => Padding(
              padding: const EdgeInsets.only(bottom: 2.5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: isActive ? color : const Color(0xFF94A3B8),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      perk,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isActive
                            ? const Color(0xFF1E293B)
                            : const Color(0xFF64748B),
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Edit Profile Dialog ─────────────────────────────────────────────────────

void showEditProfileDialog(BuildContext context, UserProfile userProfile) {
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
                  itemCount: kAvatarOptions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final url = kAvatarOptions[i];
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

void showHelpDialog(BuildContext context) {
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

void showContactDialog(BuildContext context, {required String userId}) {
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

void showPrivacyDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.privacy_tip_outlined, color: AppColors.primary, size: 24),
          SizedBox(width: 10),
          Text(
            'Privacy Policy & Safety',
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
              'Your privacy is our top priority. In compliance with Google Play and Apple App Store standards:',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            SizedBox(height: 10),
            Text(
                '• Data Security: Game stats, streaks, and balances are securely synced via Supabase with encrypted TLS transit.'),
            SizedBox(height: 6),
            Text(
                '• Ad Compliance: We integrate Google AdMob, Tapjoy, and PubScale strictly following official guidelines.'),
            SizedBox(height: 6),
            Text(
                '• Privacy Choices: We respect tracking choices and never sell player data to third parties.'),
            SizedBox(height: 6),
            Text(
                '• Child Safety (COPPA): Designed for ages 13+. We never solicit personal data from children under 13.'),
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

void showTermsDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.gavel_rounded, color: AppColors.primary, size: 24),
          SizedBox(width: 10),
          Text(
            'Terms of Service',
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
            Text(
                '1. Promotional Points: RBX Coins are virtual game points with no real-world financial balance.'),
            SizedBox(height: 6),
            Text(
                '2. Fair Play Policy: Automation, bot scripts, emulators, and multiple fake accounts are strictly prohibited.'),
            SizedBox(height: 6),
            Text(
                '3. Digital Gift Cards: Codes are fulfilled subject to verification (24–48h) and partner stock.'),
            SizedBox(height: 6),
            Text(
                '4. Non-Affiliation: RBX Rewards is independent and NOT affiliated with or endorsed by Roblox Corporation.'),
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

void showAboutDialogCustom(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 24),
          SizedBox(width: 10),
          Text(
            'About RBX Rewards',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      content: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'RBX Rewards — Play & Earn',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 4),
          Text(
            'Version 1.0.4 (Build 12)',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          SizedBox(height: 12),
          Text(
            'Play exciting mini-games, complete daily challenges, and earn points redeemable for digital gift cards.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          SizedBox(height: 10),
          Text(
            '© 2026 RBX Rewards. All rights reserved.',
            style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('OK', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}

void showLogoutConfirmDialog(BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 24),
          SizedBox(width: 10),
          Text(
            'Logout',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      content: const Text(
        'Are you sure you want to sign out? Your cloud progress will remain safe and restored when you log back in.',
        style: TextStyle(fontSize: 13, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
        ),
        InteractiveButton(
          text: 'Sign Out',
          width: 96,
          height: 38,
          borderRadius: 12,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          gradient: const LinearGradient(
            colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
          ),
          onTap: () async {
            final rootNav = Navigator.of(context, rootNavigator: true);
            Navigator.pop(ctx);

            try {
              await ref.read(authServiceProvider).signOut();
            } catch (e) {
              debugPrint('Sign-out notice: $e');
            }

            // Invalidate and reset user state to prevent stale data leakage between accounts
            ref.read(coinProvider.notifier).forceReset();
            ref.read(dailyCapServiceProvider).resetAllEarnings();
            ref.invalidate(userProfileStreamProvider);
            ref.invalidate(userProfileProvider);
            ref.invalidate(rewardHistoryProvider);

            await ref.read(onboardingCompletedProvider.notifier).setCompleted(false);

            // Pop any pushed screens (e.g. SettingsScreen) back to root so Onboarding is front and center
            rootNav.popUntil((route) => route.isFirst);
          },
        ),
      ],
    ),
  );
}

void showDeleteAccountDialog(BuildContext context, WidgetRef ref) {
  final confirmController = TextEditingController();
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      bool isDeleting = false;
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final isConfirmed =
              confirmController.text.trim().toUpperCase() == 'DELETE ACCOUNT';

          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFDC2626), size: 24),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Delete Account Permanently',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'In compliance with Apple App Store Guideline 5.1.1(v) & privacy regulations, you can permanently delete your account and all associated data.',
                    style: TextStyle(fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '• All RBX Coins and progress will be deleted from servers.\n• Local cache, preferences, and data will be wiped.\n• You will NOT be able to restore this account.\n• If you return, a completely fresh new account will be created.',
                    style: TextStyle(
                        fontSize: 12, color: Color(0xFF64748B), height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Type DELETE ACCOUNT to confirm:',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: confirmController,
                    autofocus: false,
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (_) => setDialogState(() {}),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      hintText: 'DELETE ACCOUNT',
                      hintStyle: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isConfirmed
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFCBD5E1),
                          width: isConfirmed ? 1.5 : 1.0,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isConfirmed
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFDC2626),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isDeleting ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel',
                    style: TextStyle(color: Color(0xFF64748B))),
              ),
              ElevatedButton(
                onPressed: (isConfirmed && !isDeleting)
                    ? () async {
                        final rootNav = Navigator.of(context, rootNavigator: true);
                        setDialogState(() => isDeleting = true);
                        try {
                          final auth = ref.read(authServiceProvider);
                          await auth.deleteAccount();

                          try {
                            await ref.read(hiveRepositoryProvider).clearAll();
                          } catch (_) {}

                          try {
                            await ref.read(secureRepositoryProvider).clearAll();
                          } catch (_) {}

                          try {
                            ref.read(coinProvider.notifier).forceReset();
                          } catch (_) {}
                          try {
                            ref.read(dailyCapServiceProvider).resetAllEarnings();
                          } catch (_) {}

                          try {
                            ref.invalidate(userProfileStreamProvider);
                          } catch (_) {}
                          try {
                            ref.invalidate(userProfileProvider);
                          } catch (_) {}
                          try {
                            ref.invalidate(rewardHistoryProvider);
                          } catch (_) {}

                          try {
                            await ref
                                .read(onboardingCompletedProvider.notifier)
                                .setCompleted(false);
                          } catch (_) {}

                          // Return directly to the root Onboarding screen, closing all dialogs and pushed settings screens
                          rootNav.popUntil((route) => route.isFirst);
                        } catch (e) {
                          debugPrint('Account deletion error: $e');
                          try {
                            await ref.read(hiveRepositoryProvider).clearAll();
                          } catch (_) {}
                          try {
                            await ref.read(secureRepositoryProvider).clearAll();
                          } catch (_) {}
                          try {
                            ref.read(coinProvider.notifier).forceReset();
                          } catch (_) {}
                          try {
                            ref.read(dailyCapServiceProvider).resetAllEarnings();
                          } catch (_) {}
                          try {
                            ref.invalidate(userProfileStreamProvider);
                          } catch (_) {}
                          try {
                            ref.invalidate(userProfileProvider);
                          } catch (_) {}
                          try {
                            ref.invalidate(rewardHistoryProvider);
                          } catch (_) {}
                          try {
                            await ref
                                .read(onboardingCompletedProvider.notifier)
                                .setCompleted(false);
                          } catch (_) {}

                          rootNav.popUntil((route) => route.isFirst);
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  disabledBackgroundColor: const Color(0xFFE2E8F0),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: const Color(0xFF94A3B8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: isDeleting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Permanently Delete'),
              ),
            ],
          );
        },
      );
    },
  );
}

// ─── My Rewards Bottom Sheet ─────────────────────────────────────────────────

void showMyRewardsBottomSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => Consumer(
      builder: (context, ref, _) {
        final historyAsync = ref.watch(rewardHistoryProvider);

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
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
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.card_giftcard_rounded,
                      color: AppColors.primary, size: 24),
                  SizedBox(width: 10),
                  Text(
                    'My Claimed Rewards',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Track the status and codes of your redeemed gift cards.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: historyAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                  error: (e, _) => Center(
                    child: Text('Unable to load rewards: $e',
                        style: const TextStyle(color: Colors.red)),
                  ),
                  data: (list) {
                    if (list.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF1F2F8),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.inventory_2_outlined,
                                  size: 36, color: Color(0xFF94A3B8)),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No redeemed rewards yet',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Earn coins and redeem Roblox gift cards in the Rewards tab!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final item = list[i];
                        final title = item['reward_title'] as String? ?? 'Gift Card';
                        final status = item['status'] as String? ?? 'pending';
                        final code = item['claim_code'] as String? ?? '';
                        final isApproved = status == 'approved' || status == 'completed';

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySoft,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.card_giftcard_rounded,
                                    color: AppColors.primary, size: 20),
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
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isApproved && code.isNotEmpty
                                          ? 'Code: $code'
                                          : 'Status: ${status.toUpperCase()}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isApproved
                                            ? const Color(0xFF16A34A)
                                            : const Color(0xFFD97706),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isApproved && code.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.copy_rounded,
                                      size: 18, color: AppColors.primary),
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: code));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Claim code copied!'),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

// ─── Transaction History Bottom Sheet ────────────────────────────────────────

void showTransactionHistoryBottomSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
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
          const SizedBox(height: 16),
          const Row(
            children: [
              Icon(Icons.receipt_long_rounded,
                  color: AppColors.primary, size: 24),
              SizedBox(width: 10),
              Text(
                'Transaction History',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Record of all RBX coin activities on your account.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F2F8),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.history_toggle_off_rounded,
                        size: 36, color: Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No transaction logs found',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'All newly completed games, spins, and offers will be recorded here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
