import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import 'package:scratcher/scratcher.dart';
import '../../models/ad_models.dart';
import 'quizzes_screen.dart';
import '../../widgets/refreshable_scroll.dart';
import '../../widgets/quit_confirmation_dialog.dart';
import '../../core/utils/reward_helper.dart';
import '../providers/coin_provider.dart';

class EarnMoreScreen extends ConsumerStatefulWidget {
  final Function(int)? onNavTap;

  const EarnMoreScreen({super.key, this.onNavTap});

  @override
  ConsumerState<EarnMoreScreen> createState() => _EarnMoreScreenState();
}

class _EarnMoreScreenState extends ConsumerState<EarnMoreScreen> {
  @override
  void initState() {
    super.initState();
  }

  void _showSurveyDialog(BuildContext context) async {
    final coinsEarned = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const SurveyDialog(),
    );

    if (!context.mounted || coinsEarned == null || coinsEarned <= 0) return;

    await showRewardChoice(
      context: context,
      featureName: 'Survey Reward',
      baseReward: coinsEarned,
      quickPlacement: AdPlacement.miniGameCompletion,
      premiumPlacement: AdPlacement.miniGameCompletion,
      onSuccess: (coins) async {
        if (context.mounted) {
          await ref.read(coinProvider.notifier).credit(coins, 'survey');
          try {
            final uid = Supabase.instance.client.auth.currentUser?.id;
            if (uid != null) {
              await Supabase.instance.client.functions.invoke('increment-user-stat', body: {
                'stat_name': 'offers_completed',
              });
            }
          } catch (_) {}
        }
      },
    );
  }

  Future<void> _showScratchDialog(BuildContext context) async {
    // Step 1: Animation plays (scratch card reveal)
    final coinsEarned = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const ScratchRewardDialog(),
    );

    if (!context.mounted || coinsEarned == null || coinsEarned <= 0) return;

    await showRewardChoice(
      context: context,
      featureName: 'Scratch Card Reward',
      baseReward: coinsEarned,
      quickPlacement: AdPlacement.scratchCard,
      premiumPlacement: AdPlacement.doubleReward,
      onSuccess: (coins) async {
        if (context.mounted) {
          await ref.read(coinProvider.notifier).credit(coins, 'scratch');
          try {
            final uid = Supabase.instance.client.auth.currentUser?.id;
            if (uid != null) {
              await Supabase.instance.client.functions.invoke('increment-user-stat', body: {
                'stat_name': 'offers_completed',
              });
            }
          } catch (_) {}
        }
      },
    );
  }

  void _showSuccessSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF00FFCC), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.white),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E1B4B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Nav bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SizedBox(
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new,
                            color: AppColors.purple,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      'Earn More',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF131326),
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            const SizedBox(height: 4),
            Text(
              'More ways to earn points every day!',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF868A9F),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: RefreshableListView(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppLayout.screenPadding),
                children: [
                  // Surveys
                  _EarnRowCard(
                    iconUrl:
                        'https://cdn3d.iconscout.com/3d/premium/thumb/clipboard-survey-9937084-8134762.png',
                    fallbackIcon: Icons.poll,
                    iconBgColor: const Color(0xFFE3F8EB),
                    iconColor: const Color(0xFF00C853),
                    title: 'Surveys',
                    subtitle: 'Answer quick polls & share opinions!',
                    badgeText: 'Up to 40 Coins',
                    onTap: () => _showSurveyDialog(context),
                  ),
                  const SizedBox(height: 16),

                  _EarnRowCard(
                    iconUrl: AppAssets.tapTapGame,
                    fallbackIcon: Icons.auto_awesome,
                    iconBgColor: const Color(0xFFFFE8F0),
                    iconColor: const Color(0xFFE91E63),
                    title: 'Scratch',
                    subtitle: 'Scratch cards and reveal bigger rewards!',
                    badgeText: 'Up to 20 Coins',
                    onTap: () => _showScratchDialog(context),
                  ),
                  const SizedBox(height: 16),

                  // 6. Quizzes
                  _EarnRowCard(
                    iconUrl: AppAssets.quizMasterEarnMore,
                    fallbackIcon: Icons.school,
                    iconBgColor: const Color(0xFFF3EEFD),
                    iconColor: const Color(0xFF8B5CF6),
                    title: 'Quizzes',
                    subtitle: 'Answer quizzes and earn smart!',
                    badgeText: 'Up to 400',
                    onTap: () async {
                      final earned = await Navigator.of(context).push<int>(
                        MaterialPageRoute(
                            builder: (_) => const QuizzesScreen()),
                      );
                      if (earned != null && earned > 0 && context.mounted) {
                        // balance updates via AppState realtime
                      }
                    },
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Survey Simulated Dialog Flow ---
class SurveyDialog extends StatefulWidget {
  const SurveyDialog({super.key});

  @override
  State<SurveyDialog> createState() => _SurveyDialogState();
}

class _SurveyDialogState extends State<SurveyDialog> {
  int _step = 1;
  int? _selectedOption;

  final Map<int, _SurveyQuestion> _questions = {
    1: _SurveyQuestion(
      q: 'Which mini-game is your favorite?',
      opts: [
        'Tap Tap ⚡',
        'Flappy Jump 🐦',
        'Math Quiz 🧠',
        'Treasure Chest 📦'
      ],
    ),
    2: _SurveyQuestion(
      q: 'How satisfied are you with reward earnings?',
      opts: [
        'Very Satisfied 😊',
        'Satisfied 🙂',
        'Neutral 😐',
        'Needs more coins 🪙'
      ],
    ),
    3: _SurveyQuestion(
      q: 'Would you recommend this app to friends?',
      opts: ['Yes, definitely! 🚀', 'Probably', 'Maybe later', 'No'],
    ),
  };

  void _nextStep() {
    if (_selectedOption == null) return;
    HapticFeedback.lightImpact();
    if (_step < 3) {
      setState(() {
        _step++;
        _selectedOption = null;
      });
    } else {
      _claimSurveyReward();
    }
  }

  void _claimSurveyReward() {
    final reward = 30 + Random().nextInt(11); // variable 30–40 base coins
    Navigator.of(context).pop(reward);
  }

  @override
  Widget build(BuildContext context) {
    final isFinished = _step == 4;
    final currentQ = _questions[_step];

    return PopScope(
      canPop: isFinished,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || isFinished) return;
        final shouldLeave = await showQuitConfirmationDialog(
          context,
          title: 'Quit Survey?',
          message: 'Your survey progress will be lost. Are you sure?',
        );
        if (shouldLeave && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Progress
              Row(
                children: [
                  Text(
                    'QUICK POLL',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  if (!isFinished)
                    Text(
                      'Step $_step of 3',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF868A9F),
                      ),
                    ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F1FB),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Color(0xFF868A9F),
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (!isFinished && currentQ != null) ...[
                // Question text
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    currentQ.q,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF131326),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Options
                Column(
                  children: List.generate(currentQ.opts.length, (idx) {
                    final isSel = _selectedOption == idx;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedOption = idx;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: isSel
                              ? const Color(0xFFF3EAFD)
                              : const Color(0xFFFAFAFE),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSel
                                ? AppColors.primary
                                : const Color(0xFFECEBFC),
                            width: 2.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                currentQ.opts[idx],
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isSel
                                      ? AppColors.primary
                                      : const Color(0xFF131326),
                                ),
                              ),
                            ),
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSel
                                      ? AppColors.primary
                                      : const Color(0xFFDCDAF0),
                                  width: 2,
                                ),
                                color: isSel
                                    ? AppColors.primary
                                    : Colors.transparent,
                              ),
                              child: isSel
                                  ? const Icon(Icons.check,
                                      color: Colors.white, size: 12)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),

                // Action button
                _InteractiveCard(
                  onTap: _selectedOption != null ? _nextStep : null,
                  child: Container(
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: _selectedOption != null
                          ? AppColors.primaryGradient
                          : null,
                      color: _selectedOption != null
                          ? null
                          : const Color(0xFFE2E2F5),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: _selectedOption != null
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              )
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _step == 3 ? 'FINISH' : 'NEXT STEP',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _selectedOption != null
                            ? Colors.white
                            : const Color(0xFF868A9F),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                // Complete card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE3F8EB),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.stars,
                    color: Color(0xFF00C853),
                    size: 64,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Poll Complete! 🌟',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF131326),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Thank you for your valuable feedback!',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF868A9F),
                  ),
                ),
                const SizedBox(height: 24),
                _InteractiveCard(
                  onTap: _claimSurveyReward,
                  child: Container(
                    width: double.infinity,
                    height: 54,
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
                    child: Text(
                      'CLAIM REWARD 🪙',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SurveyQuestion {
  final String q;
  final List<String> opts;

  _SurveyQuestion({required this.q, required this.opts});
}

class ScratchRewardDialog extends StatefulWidget {
  const ScratchRewardDialog({super.key});

  @override
  State<ScratchRewardDialog> createState() => _ScratchRewardDialogState();
}

class _ScratchRewardDialogState extends State<ScratchRewardDialog> {
  final int _reward = 10 + Random().nextInt(11); // variable 10–20 base coins
  double _scratchProgress = 0;
  bool _revealed = false;
  bool _claimed = false;
  final scratchKey = GlobalKey<ScratcherState>();

  Future<void> _claimScratchReward() async {
    if (!_revealed || _claimed) return;
    setState(() {
      _claimed = true;
    });
    // Return reward to caller — parent handles two-tier dialog → ad → congratulations
    Navigator.of(context).pop(_reward);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _claimed,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _claimed) return;
        final shouldLeave = await showQuitConfirmationDialog(
          context,
          title: 'Quit Scratch?',
          message: 'Your scratch progress will be lost. Are you sure?',
        );
        if (shouldLeave && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    'SCRATCH CARD',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _revealed
                        ? 'Reward ready'
                        : '${(_scratchProgress * 100).round()}%',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF868A9F),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F1FB),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Color(0xFF868A9F),
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                height: 190,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: const Color(0xFFECEBFC), width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 2,
                      spreadRadius: 0,
                    )
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Scratcher(
                    key: scratchKey,
                    brushSize: 40,
                    threshold: 80,
                    color: const Color(0xFFCBD5E1),
                    image: null,
                    onChange: (value) {
                      setState(() {
                        _scratchProgress = value / 100;
                      });
                    },
                    onThreshold: () async {
                      HapticFeedback.heavyImpact();
                      setState(() {
                        _revealed = true;
                        _scratchProgress = 1.0;
                      });
                      scratchKey.currentState?.reveal(
                        duration: const Duration(milliseconds: 500),
                      );
                      await Future.delayed(const Duration(milliseconds: 600));
                      if (mounted) {
                        Navigator.of(context).pop(_reward);
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFFFF3E3), Color(0xFFFFD56B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            AppAssets.goldRbxCoin,
                            width: 56,
                            height: 56,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.monetization_on,
                              color: Color(0xFFFFB000),
                              size: 56,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '+$_reward RBX',
                            style: GoogleFonts.outfit(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'You revealed a reward!',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF4A4B60),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: _scratchProgress,
                  backgroundColor: const Color(0xFFECEBFC),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// --- Earn Row Card Component ---
class _EarnRowCard extends StatelessWidget {
  final String iconUrl;
  final IconData fallbackIcon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String badgeText;
  final VoidCallback onTap;

  const _EarnRowCard({
    required this.iconUrl,
    required this.fallbackIcon,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFFF3F4F6), width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 2,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left Icon Container
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: iconUrl.startsWith('http')
                    ? Image.network(
                        iconUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          fallbackIcon,
                          size: 32,
                          color: iconColor,
                        ),
                      )
                    : Image.asset(
                        iconUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          fallbackIcon,
                          size: 32,
                          color: iconColor,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 16),

            // Middle Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF131326),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF868A9F),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),

            // Right Elements (Arrow + Badge)
            SizedBox(
              height: 72,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2.0),
                    child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3EAFD), // light purple background
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          badgeText,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Image.asset(
                          AppAssets.goldRbxCoin,
                          width: 12,
                          height: 12,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.monetization_on,
                            size: 12,
                            color: Color(0xFFFFCC44),
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
      ),
    );
  }
}

class _InteractiveCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _InteractiveCard({required this.child, this.onTap});

  @override
  State<_InteractiveCard> createState() => _InteractiveCardState();
}

class _InteractiveCardState extends State<_InteractiveCard> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.97),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        if (widget.onTap != null) widget.onTap!();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: widget.child,
      ),
    );
  }
}

