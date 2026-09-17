import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../business/sound_service.dart';
import '../../business/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/interactive_button.dart';
import 'profile/profile_dialogs.dart';

/// Production-ready Settings Screen following Tier-1 Rewards UX standards (Mistplay/Fetch).
/// Houses all client preferences, account cloud linking, legal compliance, and account actions.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _hapticsEnabled = true;
  String _selectedLanguage = 'English';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _notificationsEnabled =
            prefs.getBool('pref_notifications_enabled') ?? true;
        _soundEnabled = prefs.getBool('pref_sound_enabled') ?? true;
        _hapticsEnabled = prefs.getBool('pref_haptics_enabled') ?? true;
        _selectedLanguage = prefs.getString('pref_language') ?? 'English';
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

  void _showLanguagePicker() {
    final languages = ['English', 'Spanish', 'Portuguese', 'French', 'German'];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (ctx) {
        final screenHeight = MediaQuery.sizeOf(ctx).height;
        return Stack(
          children: [
            // Tap outside to dismiss
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (Navigator.of(ctx).canPop()) {
                    Navigator.of(ctx).pop();
                  }
                },
              ),
            ),

            // Sheet card
            Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {}, // Prevent taps inside sheet from dismissing
                  child: Container(
                    width: double.infinity,
                    constraints: BoxConstraints(maxHeight: screenHeight * 0.75),
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: SafeArea(
                      top: false,
                      bottom: true,
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
                            const SizedBox(height: 16),
                            const Text(
                              'Select Language',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...languages.map((lang) {
                              final isSelected = lang == _selectedLanguage;
                              return ListTile(
                                title: Text(
                                  lang,
                                  style: TextStyle(
                                    fontWeight:
                                        isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected
                                        ? AppColors.primary
                                        : const Color(0xFF0F172A),
                                  ),
                                ),
                                trailing: isSelected
                                    ? const Icon(Icons.check_circle_rounded,
                                        color: AppColors.primary)
                                    : null,
                                onTap: () async {
                                  setState(() => _selectedLanguage = lang);
                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.setString('pref_language', lang);
                                  if (ctx.mounted) Navigator.pop(ctx);
                                },
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Icon(
              Icons.arrow_back_rounded,
              color: Color(0xFF0F172A),
              size: 18,
            ),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.cardBorder, height: 1),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(
              18, 16, 18, AppLayout.sectionSpacing),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // ── PREFERENCES GROUP ──
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'PREFERENCES',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder, width: 1.2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x06000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _SettingsSwitchTile(
                    icon: Icons.notifications_none_rounded,
                    title: 'Notifications',
                    subtitle: 'Daily streak reminders & reward alerts',
                    value: _notificationsEnabled,
                    onChanged: (val) {
                      setState(() => _notificationsEnabled = val);
                      _updatePreference('pref_notifications_enabled', val);
                      NotificationService.instance.setNotificationsEnabled(val);
                      if (val) {
                        NotificationService.instance.requestPermissions();
                      }
                    },
                    hasDivider: true,
                  ),
                  _SettingsSwitchTile(
                    icon: Icons.volume_up_rounded,
                    title: 'Sound Effects (SFX)',
                    subtitle: 'Mini-games & claim audio cues',
                    value: _soundEnabled,
                    onChanged: (val) {
                      setState(() => _soundEnabled = val);
                      _updatePreference('pref_sound_enabled', val);
                      SoundService.instance.setSoundEnabled(val);
                    },
                    hasDivider: true,
                  ),
                  _SettingsSwitchTile(
                    icon: Icons.vibration_rounded,
                    title: 'Haptic Feedback',
                    subtitle: 'Tactile vibration on tap & wins',
                    value: _hapticsEnabled,
                    onChanged: (val) {
                      setState(() => _hapticsEnabled = val);
                      _updatePreference('pref_haptics_enabled', val);
                    },
                    hasDivider: true,
                  ),
                  _SettingsNavigationTile(
                    icon: Icons.language_rounded,
                    title: 'Language',
                    trailingText: _selectedLanguage,
                    onTap: _showLanguagePicker,
                    hasDivider: false,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── ACCOUNT & SECURITY GROUP ──
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'ACCOUNT & SECURITY',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder, width: 1.2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x06000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _SettingsNavigationTile(
                    icon: Icons.delete_outline_rounded,
                    iconColor: const Color(0xFFDC2626),
                    title: 'Delete Account & Data',
                    subtitle: 'Permanent deletion (Apple Guideline 5.1.1v)',
                    onTap: () => showDeleteAccountDialog(context, ref),
                    hasDivider: false,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── LEGAL & SUPPORT GROUP ──
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'LEGAL & SUPPORT',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder, width: 1.2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x06000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _SettingsNavigationTile(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy Policy',
                    onTap: () => showPrivacyDialog(context),
                    hasDivider: true,
                  ),
                  _SettingsNavigationTile(
                    icon: Icons.description_outlined,
                    title: 'Terms of Service',
                    onTap: () => showTermsDialog(context),
                    hasDivider: true,
                  ),
                  _SettingsNavigationTile(
                    icon: Icons.help_outline_rounded,
                    title: 'Help & Support',
                    onTap: () => showHelpDialog(context),
                    hasDivider: true,
                  ),
                  _SettingsNavigationTile(
                    icon: Icons.info_outline_rounded,
                    title: 'About RBX Rewards',
                    trailingText: 'v1.0.4',
                    onTap: () => showAboutDialogCustom(context),
                    hasDivider: false,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── LOGOUT BUTTON ──
            InteractiveButton(
              icon: Icons.logout_rounded,
              iconSize: 18,
              text: 'Logout',
              height: 50,
              borderRadius: 14,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              gradient: const LinearGradient(
                colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
              ),
              onTap: () => showLogoutConfirmDialog(context, ref),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    ),
  );
}
}

// ─── Settings Tile Widgets ────────────────────────────────────────────────────

class _SettingsSwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool hasDivider;

  const _SettingsSwitchTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    required this.hasDivider,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Switch.adaptive(
                value: value,
                onChanged: onChanged,
                activeTrackColor: AppColors.primary,
                activeThumbColor: Colors.white,
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

class _SettingsNavigationTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final String? trailingText;
  final VoidCallback onTap;
  final bool hasDivider;

  const _SettingsNavigationTile({
    required this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    this.trailingText,
    required this.onTap,
    required this.hasDivider,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = iconColor ?? AppColors.primary;
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: effectiveColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      color: effectiveColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: iconColor ?? const Color(0xFF0F172A),
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailingText != null)
                    Text(
                      trailingText!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
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
