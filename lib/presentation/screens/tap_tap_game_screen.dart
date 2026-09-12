import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/coin_provider.dart';
import '../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/game_prefs.dart';
import '../../widgets/quit_confirmation_dialog.dart';
import '../../models/ad_models.dart';
import '../../core/utils/game_reward_helper.dart';
import '../../core/utils/reward_helper.dart';

class TapTapGameScreen extends ConsumerStatefulWidget {
  const TapTapGameScreen({super.key});

  @override
  ConsumerState<TapTapGameScreen> createState() => _TapTapGameScreenState();
}

class _TapTapGameScreenState extends ConsumerState<TapTapGameScreen>
    with TickerProviderStateMixin {
  // Game states
  bool _hasStarted = false;
  bool _isGameOver = false;
  bool _isGameFailed = false;
  bool _hasClaimed = false;
  bool _isProcessingPlayAgain = false;
  bool _isProcessingClaim = false;

  bool get _isProcessingAd => _isProcessingPlayAgain || _isProcessingClaim;
  int _score = 0;
  int _coinsEarned = 0;
  int _originalCoinsEarned = 0;
  int _comboCount = 0;
  int _maxCombo = 0;
  double _timerProgress = 1.0;
  int _timeLeftSeconds = 15;
  Ticker? _ticker;
  Duration _lastTickTime = Duration.zero;
  double _timeElapsedSinceLastTap = 0.0;
  String? _sessionId;
  DateTime? _gameStartTime;

  // Screen shake variables
  double _shakeIntensity = 0.0;
  final Random _random = Random();

  // Animation controllers
  late AnimationController _crystalPressController;
  late Animation<double> _crystalScaleAnimation;

  late AnimationController _glowPulseController;

  late AnimationController _endDialogController;
  late Animation<double> _endDialogScale;

  // Particle list
  final List<_TapParticle> _particles = [];
  // Floating texts
  final List<_FloatingText> _floatingTexts = [];

  // Concentric 3D UI states
  final List<_BgElement> _bgElements = [];
  final List<_RippleEffect> _ripples = [];

  double _tiltX = 0.0;
  double _tiltY = 0.0;



  @override
  void initState() {
    super.initState();

    // Initialize 8 floating background elements inspired by the mockup
    for (int i = 0; i < 8; i++) {
      _bgElements.add(
        _BgElement(
          x: _random.nextDouble() * 300 + 20,
          y: _random.nextDouble() * 450 + 120,
          vx: (_random.nextDouble() - 0.5) * 30,
          vy: (_random.nextDouble() - 0.5) * 30,
          size: _random.nextDouble() * 16 + 12,
          rotation: _random.nextDouble() * 2 * pi,
          vRotation: (_random.nextDouble() - 0.5) * 1.0,
          isStar: _random.nextBool(),
        ),
      );
    }

    // Squash & stretch on tap
    _crystalPressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
    _crystalScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.88), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 0.88, end: 1.05), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 30),
    ]).animate(_crystalPressController);

    // Aura pulse
    _glowPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Game Over dialog pop-in
    _endDialogController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _endDialogScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _endDialogController, curve: Curves.elasticOut),
    );
    Future.microtask(() {
      ref.read(adServiceProvider).preloadRewardedInterstitial(AdPlacement.miniGameCompletion);
    });
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _crystalPressController.dispose();
    _glowPulseController.dispose();
    _endDialogController.dispose();
    super.dispose();
  }

  void _startGame() {
    _ticker?.stop();
    _ticker?.dispose();

    setState(() {
      _hasStarted = true;
      _isGameOver = false;
      _isGameFailed = false;
      _hasClaimed = false;
      _isProcessingPlayAgain = false;
      _isProcessingClaim = false;
      _score = 0;
      _coinsEarned = 0;
      _originalCoinsEarned = 0;
      _comboCount = 0;
      _maxCombo = 0;
      _timerProgress = 1.0;
      _timeLeftSeconds = 15;
      _particles.clear();
      _floatingTexts.clear();
    });

    _sessionId = ref.read(gameServiceProvider).generateSessionId();
    _gameStartTime = DateTime.now();
    _lastTickTime = Duration.zero;
    _ticker = createTicker(_onTick);
    _ticker!.start();
  }

  void _onTick(Duration elapsed) {
    if (_lastTickTime == Duration.zero) {
      _lastTickTime = elapsed;
      return;
    }
    final double dt =
        (elapsed.inMilliseconds - _lastTickTime.inMilliseconds) / 1000.0;
    _lastTickTime = elapsed;

    setState(() {
      if (!_isGameOver) {
        // 1. Timer logic
        _timerProgress -= dt / 15.0; // 15 seconds game
        if (_timerProgress <= 0 && !_isGameOver) {
          _timerProgress = 0;
          _isGameOver = true;
          Future.microtask(_endGame);
        }
        _timeLeftSeconds = (15 * _timerProgress).ceil();

        // 2. Combo decay logic
        _timeElapsedSinceLastTap += dt;
        if (_timeElapsedSinceLastTap > 1.2 && _comboCount > 0) {
          _comboCount = 0; // Reset combo if no taps for 1.2s
        }
      }

      // 3. Screen shake decay
      if (_shakeIntensity > 0) {
        _shakeIntensity -= dt * 15.0;
        if (_shakeIntensity < 0) _shakeIntensity = 0;
      }

      // 4. Update particles
      for (int i = _particles.length - 1; i >= 0; i--) {
        final p = _particles[i];
        p.age += dt;
        p.x += p.vx * dt;
        p.y += p.vy * dt;
        p.vy += 250 * dt; // Gravity
        p.rotation += p.vRotation * dt;
        if (p.age >= p.lifeTime) {
          _particles.removeAt(i);
        }
      }

      // 5. Update floating texts
      for (int i = _floatingTexts.length - 1; i >= 0; i--) {
        final ft = _floatingTexts[i];
        ft.age += dt;
        ft.y += ft.vy * dt; // Float up
        if (ft.age >= ft.lifeTime) {
          _floatingTexts.removeAt(i);
        }
      }



      // 7. Update Concentric Tapped Ripples
      for (int i = _ripples.length - 1; i >= 0; i--) {
        final r = _ripples[i];
        r.scale += dt * 2.8; // Snappy expansion
        r.opacity -= dt * 2.2; // Fade out rapidly
        if (r.opacity <= 0) {
          _ripples.removeAt(i);
        }
      }

      // 8. Update Mockup background drifting elements (stars/circles)
      for (final bg in _bgElements) {
        bg.x += bg.vx * dt;
        bg.y += bg.vy * dt;
        bg.rotation += bg.vRotation * dt;

        // Soft bounce boundaries
        if (bg.x < 10 || bg.x > 340) {
          bg.vx = -bg.vx;
          bg.x = bg.x.clamp(10, 340);
        }
        if (bg.y < 80 || bg.y > 640) {
          bg.vy = -bg.vy;
          bg.y = bg.y.clamp(80, 640);
        }
      }
    });
  }

  Future<void> _endGame() async {
    final finalIsFailed = _score < 30;
    
    if (finalIsFailed) {
      setState(() {
        _isGameOver = true;
        _isGameFailed = true;
        _originalCoinsEarned = 0;
        _coinsEarned = 0;
      });
    } else {
      final baseCoins = (_score * 0.5).ceil().clamp(0, 15); // 1 coin per 2 taps, max 15 base
      int totalCoins = baseCoins;
      if (_maxCombo > 10) {
        final comboBonus = (_maxCombo * 0.5).round();
        totalCoins = (baseCoins + comboBonus).clamp(0, 15); // Combo bonus, still capped at 15
      }
      
      setState(() {
        _isGameOver = true;
        _isGameFailed = false;
        _originalCoinsEarned = totalCoins;
        _coinsEarned = totalCoins;
      });
    }

    _endDialogController.reset();
    _endDialogController.forward();
    ref.read(adServiceProvider).preloadRewardedInterstitial(AdPlacement.miniGameCompletion);
  }

  void _handleTap(TapUpDetails details) {
    if (!_hasStarted) {
      _startGame();
      return;
    }
    if (_isGameOver) return;

    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset localPos = box.globalToLocal(details.globalPosition);

    // Calculate displacement from screen center to tilt the target in 3D
    final dx = localPos.dx - box.size.width / 2;
    final dy = localPos.dy - box.size.height / 2;

    setState(() {
      _tiltX = -(dy / (box.size.height / 2)).clamp(-1.0, 1.0) * 0.35;
      _tiltY = (dx / (box.size.width / 2)).clamp(-1.0, 1.0) * 0.35;
      _ripples.add(_RippleEffect()); // Add organic ripple shockwave
    });

    // Reset tilt back to 0.0 after 80ms for a snappy elastic spring-back response
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) {
        setState(() {
          _tiltX = 0.0;
          _tiltY = 0.0;
        });
      }
    });

    // Trigger squash & stretch animation
    _crystalPressController.reset();
    _crystalPressController.forward();

    // Tap calculations
    _timeElapsedSinceLastTap = 0.0;
    _comboCount++;
    if (_comboCount > _maxCombo) {
      _maxCombo = _comboCount;
    }

    // Multiply score based on combo level
    int pointsEarned = 1;
    if (_comboCount >= 30) {
      pointsEarned = 4; // 4x multiplier
      _shakeIntensity = 8.0; // Heavy shake
    } else if (_comboCount >= 15) {
      pointsEarned = 3; // 3x multiplier
      _shakeIntensity = 5.0; // Moderate shake
    } else if (_comboCount >= 5) {
      pointsEarned = 2; // 2x multiplier
      _shakeIntensity = 2.0; // Subtle shake
    }

    setState(() {
      _score += pointsEarned;
    });

    _spawnParticles(localPos);
    _spawnFloatingText(localPos, pointsEarned);
  }

  void _spawnParticles(Offset pos) {
    // Determine color based on combo
    Color particleColor = AppColors.primary;
    if (_comboCount >= 30) {
      particleColor = const Color(0xFFFFCC44); // Gold flame spark
    } else if (_comboCount >= 15) {
      particleColor = Colors.deepOrangeAccent; // Orange hot spark
    } else if (_comboCount >= 5) {
      particleColor = AppColors.purple; // Purple combo spark
    }

    final int count = _random.nextInt(4) + 4;
    for (int i = 0; i < count; i++) {
      final double angle = _random.nextDouble() * 2 * pi;
      final double speed = _random.nextDouble() * 150 + 80;
      _particles.add(
        _TapParticle(
          x: pos.dx,
          y: pos.dy,
          vx: cos(angle) * speed,
          vy: sin(angle) * speed - 60, // upward bias
          rotation: _random.nextDouble() * 2 * pi,
          vRotation: (_random.nextDouble() - 0.5) * 8,
          scale: _random.nextDouble() * 6 + 4,
          lifeTime: _random.nextDouble() * 0.4 + 0.4,
          color: particleColor,
        ),
      );
    }
  }

  void _spawnFloatingText(Offset pos, int score) {
    String text = '+$score';
    Color textColor = AppColors.primaryText;
    double fontSize = 18;

    if (_comboCount >= 30) {
      text = '⚡ CRITICAL +$score!';
      textColor = const Color(0xFFFF9900);
      fontSize = 22;
    } else if (_comboCount >= 15) {
      text = '🔥 COMBO +$score!';
      textColor = Colors.deepOrange;
      fontSize = 20;
    } else if (_comboCount >= 5) {
      text = '⚡ +$score';
      textColor = AppColors.purple;
      fontSize = 18;
    }

    _floatingTexts.add(
      _FloatingText(
        x: pos.dx,
        y: pos.dy,
        text: text,
        color: textColor,
        fontSize: fontSize,
        vy: -150 - _random.nextDouble() * 50,
        lifeTime: 0.8,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 3D Screen shake calculation
    double dx = 0.0;
    double dy = 0.0;
    if (_shakeIntensity > 0 && !_isGameOver) {
      dx = (_random.nextDouble() - 0.5) * _shakeIntensity;
      dy = (_random.nextDouble() - 0.5) * _shakeIntensity;
    }

    // Determine current color scheme based on combo
    Color auraColor = AppColors.primary.withOpacity(0.15);
    Color crystalCoreColor = AppColors.primary;
    String crystalState = 'NORMAL';

    if (_comboCount >= 30) {
      auraColor = const Color(0xFFFFCC44).withOpacity(0.35); // Golden Fire
      crystalCoreColor = const Color(0xFFFF9900);
      crystalState = 'SUPERCHARGED ⚡';
    } else if (_comboCount >= 15) {
      auraColor = Colors.deepOrangeAccent.withOpacity(0.25); // Intense Flame
      crystalCoreColor = Colors.deepOrange;
      crystalState = 'COMBO RUSH 🔥';
    } else if (_comboCount >= 5) {
      auraColor = AppColors.purple.withOpacity(0.20); // Electric Purple
      crystalCoreColor = AppColors.purple;
      crystalState = 'COMBO x$_comboCount';
    }

    final isPlaying = _hasStarted && !_isGameOver;
    return PopScope(
      canPop: !isPlaying,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || !isPlaying) return;
        final shouldLeave = await showQuitConfirmationDialog(
          context,
          title: 'Quit Game?',
          message:
              'Are you sure you want to exit? You will lose unclaimed progress.',
        );
        if (shouldLeave && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // Background soft abstract radial glows
            Positioned(
              top: -150,
              left: -150,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [auraColor.withOpacity(0.1), Colors.transparent],
                  ),
                ),
              ),
            ),

            // Beautiful floating background stars/circles inspired by the mockup
            ..._bgElements.map((bg) {
              return Positioned(
                left: bg.x,
                top: bg.y,
                child: Transform.rotate(
                  angle: bg.rotation,
                  child: Opacity(
                    opacity: 0.12,
                    child: Icon(
                      bg.isStar ? Icons.star : Icons.circle_outlined,
                      size: bg.size,
                      color: const Color(0xFF6E3AFF),
                    ),
                  ),
                ),
              );
            }),

            SafeArea(
              child: Column(
                children: [
                  // Top Header Nav Bar with integrated reactive Timer subtitle
                  // Top Header Nav Bar with integrated reactive Timer subtitle
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
                              onTap: () async {
                                if (isPlaying) {
                                  final shouldLeave =
                                      await showQuitConfirmationDialog(
                                    context,
                                    title: 'Quit Game?',
                                    message:
                                        'Are you sure you want to exit? You will lose unclaimed progress.',
                                  );
                                  if (shouldLeave && context.mounted) {
                                    Navigator.of(context).pop();
                                  }
                                } else {
                                  Navigator.of(context).pop();
                                }
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
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Tap Tap',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF131326),
                                  letterSpacing: -0.5,
                                ),
                              ),
                              // Beautiful reactive subtitle that displays the live timer countdown!
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 150),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _hasStarted && !_isGameOver
                                      ? (_timeLeftSeconds <= 4
                                          ? Colors.red
                                          : AppColors.purple)
                                      : AppColors.purple,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Inter',
                                ),
                                child: Text(
                                  _hasStarted
                                      ? (_isGameOver
                                          ? 'Game Over!'
                                          : 'Time: 00:${_timeLeftSeconds.toString().padLeft(2, '0')}')
                                      : '3D Action Mode',
                                ),
                              ),
                            ],
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Consumer(
                                  builder: (context, ref, child) {
                                    final coinBalance = ref.watch(coinProvider);
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AppColors.primarySoft,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Image.asset(
                                            AppAssets.goldRbxCoin,
                                            width: 18,
                                            height: 18,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            coinBalance.toString(),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primaryText,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 8),
                                // Container(
                                //   height: 38,
                                //   padding: const EdgeInsets.symmetric(horizontal: 14),
                                //   decoration: BoxDecoration(
                                //     color: AppColors.primarySoft,
                                //     borderRadius: BorderRadius.circular(12),
                                //   ),
                                //   child: Row(
                                //     mainAxisSize: MainAxisSize.min,
                                //     children: [
                                //       const Icon(Icons.bolt,
                                //           color: AppColors.purple, size: 20),
                                //       const SizedBox(width: 6),
                                //       Text(
                                //         '$_score',
                                //         style: const TextStyle(
                                //           fontSize: 16,
                                //           fontWeight: FontWeight.w800,
                                //           color: Color(0xFF131326),
                                //         ),
                                //       ),
                                //     ],
                                //   ),
                                // ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Expanded(
                    child: Transform.translate(
                      offset: Offset(dx, dy),
                      child: Center(
                        child: _hasStarted
                            ? (_isGameOver
                                ? _buildGameOverScreen()
                                : _buildGameplay(
                                    auraColor, crystalCoreColor, crystalState))
                            : _buildInstructions(),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Custom Physics Render Overlays (Confetti / Particles)
            IgnorePointer(
              child: CustomPaint(
                size: Size.infinite,
                painter: _OverlaysPainter(_particles, _floatingTexts),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameplay(
      Color auraColor, Color crystalCoreColor, String crystalState) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Current state label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: crystalCoreColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: crystalCoreColor.withOpacity(0.3), width: 1.5),
          ),
          child: Text(
            crystalState,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: crystalCoreColor,
              letterSpacing: 0.5,
            ),
          ),
        ),

        const SizedBox(height: 35),

        // The Concentric Tapping Target inspired by mockup
        GestureDetector(
          onTapUp: _handleTap,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // 1. Concentric Background Rings from mockup
              // Ring 1 (Largest, ultra soft)
              Container(
                width: 290,
                height: 290,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF6E3AFF).withOpacity(0.04),
                ),
              ),
              // Ring 2 (Soft)
              Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF6E3AFF).withOpacity(0.07),
                ),
              ),
              // Ring 3 (Medium)
              Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF6E3AFF).withOpacity(0.14),
                ),
              ),

              // 2. Shockwave Tapped Circles ripples
              ..._ripples.map((ripple) {
                return Opacity(
                  opacity: ripple.opacity.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: ripple.scale,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF6E3AFF).withOpacity(0.45),
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                );
              }),

              // 3. Central Solid Purple TAP Circle with 3D perspective rotation
              Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001) // perspective
                  ..rotateX(_tiltX)
                  ..rotateY(_tiltY)
                  ..scale(_crystalScaleAnimation.value),
                alignment: Alignment.center,
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF7A4BFF),
                        Color(0xFF562EE6),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF562EE6).withOpacity(0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'TAP!',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),

              // 4. Pulsing Tutorial Tapping Hand (Fades out when score increases!)
              if (_score == 0)
                Positioned(
                  right: -25,
                  bottom: -45,
                  child: AnimatedBuilder(
                    animation: _glowPulseController,
                    builder: (context, child) {
                      // Breath-like pulsing scale and slight tilt rotation
                      final pulseVal = _glowPulseController.value;
                      return Transform.translate(
                        offset: Offset(-pulseVal * 8, -pulseVal * 8),
                        child: Transform.rotate(
                          angle: -0.05 + pulseVal * 0.1,
                          child: Transform.scale(
                            scale: 0.9 + pulseVal * 0.1,
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: IgnorePointer(
                      child: SizedBox(
                        width: 130,
                        height: 130,
                        child: CustomPaint(
                          painter: _HandTapPainter(),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 45),

        // Live Combo display
        if (_comboCount > 0)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 1.0, end: 1.2),
            duration: const Duration(milliseconds: 100),
            builder: (context, val, child) {
              return Transform.scale(
                scale: val,
                child: child,
              );
            },
            child: Text(
              '${_comboCount}X COMBO 🔥',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF562EE6),
              ),
            ),
          )
        else
          Text(
            _timeLeftSeconds > 0
                ? '$_timeLeftSeconds SECONDS REMAINING'
                : "TIME'S UP!",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color:
                  _timeLeftSeconds <= 4 ? Colors.red : const Color(0xFF868A9F),
              letterSpacing: 1.0,
            ),
          ),
      ],
    );
  }

  Widget _buildInstructions() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Premium 3D Gaming Banner
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AppColors.dailyCardGradient,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFEFECFF)),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.touch_app,
                  size: 90,
                  color: AppColors.primary,
                ),
                SizedBox(height: 16),
                Text(
                  '3D CRYSTAL RUSH',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF131326),
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Tap the central 3D crystal as fast as you can. Build combos to supercharge your score! You need at least 30 points in 15 seconds to claim your reward.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF4A4B60),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // Features/Rules Row
          const Row(
            children: [
              _InstructionStep(
                icon: Icons.timer,
                title: '15s Timer',
                desc: 'Race against time',
                color: Colors.blue,
              ),
              SizedBox(width: 10),
              _InstructionStep(
                icon: Icons.bolt,
                title: 'Combos',
                desc: 'Tap fast to scale points',
                color: Colors.orange,
              ),
              SizedBox(width: 10),
              _InstructionStep(
                icon: Icons.flag,
                title: 'Target: 30',
                desc: 'Earn 30 pts to win',
                color: Colors.red,
              ),
            ],
          ),

          const SizedBox(height: 40),

          // Big Launch Button
          GestureDetector(
            onTap: _startGame,
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x666035EE),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  'Start 3D Rush!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }



  void _claimCoins() async {
    if (_originalCoinsEarned <= 0 || _hasClaimed || _isProcessingClaim) {
      if (_hasClaimed && mounted) Navigator.of(context).pop();
      return;
    }

    setState(() {
      _isProcessingClaim = true;
    });

    await GamePrefs.incrementGamePlayCount('tap_tap');

    if (!mounted) return;

    await showRewardChoice(
      context: context,
      featureName: 'Tap Tap Reward',
      baseReward: _originalCoinsEarned,
      quickPlacement: AdPlacement.miniGameCompletion,
      premiumPlacement: AdPlacement.doubleReward,
      heroAsset: AppAssets.tapTapGame,
      onSuccess: (coins) async {
        final multiplier = coins > _originalCoinsEarned ? 2 : 1;
        final duration = _gameStartTime != null
            ? DateTime.now().difference(_gameStartTime!).inSeconds
            : 1;

        try {
          final result = await ref.read(gameServiceProvider).submitGameResult(
            gameName: 'tap_tap',
            score: coins,
            durationSeconds: duration.clamp(1, 3600),
            sessionId: _sessionId ?? ref.read(gameServiceProvider).generateSessionId(),
            originalScore: _originalCoinsEarned,
            multiplier: multiplier,
          );
          if (!mounted) return;
          if (result.success || result.queued) {
            final earned = result.coinsEarned > 0 ? result.coinsEarned : coins;
            ref.read(coinProvider.notifier).updateBalance(ref.read(coinProvider) + earned);
            ref.read(dailyCapServiceProvider).addCoins(earned, 'tap_tap');

            if (mounted) {
              setState(() {
                _hasClaimed = true;
                _coinsEarned = earned;
              });
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(result.error ?? 'Failed to save game reward')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to save game reward')),
            );
          }
        }
      },
    );

    if (mounted) {
      setState(() {
        _isProcessingClaim = false;
      });
    }
  }

  Future<void> _autoCreditCoinsOnPlayAgain() async {
    final duration = _gameStartTime != null
        ? DateTime.now().difference(_gameStartTime!).inSeconds
        : 1;
    try {
      final result = await ref.read(gameServiceProvider).submitGameResult(
        gameName: 'tap_tap',
        score: _originalCoinsEarned,
        durationSeconds: duration.clamp(1, 3600),
        sessionId: _sessionId ?? ref.read(gameServiceProvider).generateSessionId(),
        originalScore: _originalCoinsEarned,
        multiplier: 1,
      );
      if (result.success || result.queued) {
        final earned = result.coinsEarned > 0 ? result.coinsEarned : _originalCoinsEarned;
        ref.read(coinProvider.notifier).updateBalance(ref.read(coinProvider) + earned);
        ref.read(dailyCapServiceProvider).addCoins(earned, 'tap_tap');
        if (mounted) {
          setState(() {
            _hasClaimed = true;
            _coinsEarned = earned;
          });
        }
      }
    } catch (_) {}
  }

  void _playAgain() async {
    if (_isProcessingAd) return;
    setState(() {
      _isProcessingPlayAgain = true;
    });

    if (!_hasClaimed && _originalCoinsEarned > 0) {
      await _autoCreditCoinsOnPlayAgain();
    }

    if (!mounted) return;

    await showPlayAgainVideoAd(
      context: context,
      ref: ref,
      onComplete: () {
        if (mounted) {
          setState(() {
            _isProcessingPlayAgain = false;
          });
          _startGame();
        }
      },
    );
  }

  Widget _buildGameOverScreen() {
    final bool didWin = !_isGameFailed;
    
    return Column(
      key: const ValueKey('GAMEOVER'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),

        // Trophy icon with pop animation
        ScaleTransition(
          scale: _endDialogScale,
          child: Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: didWin ? const Color(0xFFFDF6E2) : const Color(0xFFEFECFF),
              shape: BoxShape.circle,
            ),
            child: Icon(
              didWin ? Icons.emoji_events : Icons.replay,
              color: didWin ? const Color(0xFFFFCC44) : const Color(0xFF6E3AFF),
              size: 50,
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Result Header
        Text(
          didWin ? 'Time\'s Up!' : 'Target Failed!',
          style: GoogleFonts.outfit(
            fontSize: 42,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF181C32),
          ),
        ),
        const SizedBox(height: 12),

        // Stats Summary Subtitle
        Text(
          'Score: $_score pts  •  Max Combo: ${_maxCombo}x',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 24),

        // Breakdown Card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFEFECFF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E2F5)),
            ),
            child: Column(
              children: [
                _buildRewardRow('Total Points', '$_score / 30'),
                const SizedBox(height: 8),
                _buildRewardRow('Max Combo', '${_maxCombo}x'),
                const SizedBox(height: 8),
                _buildRewardRow('Base Reward', '+$_originalCoinsEarned RBX'),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(color: Color(0xFFE2E2F5)),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF181C32),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.currency_bitcoin,
                            color: Color(0xFFFFB000), size: 20),
                        const SizedBox(width: 4),
                        Text(
                          '+$_coinsEarned RBX',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF181C32),
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

        const Spacer(),

        // Action Buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              // Play Again
              GestureDetector(
                onTap: _isProcessingAd ? null : _playAgain,
                child: Container(
                  width: double.infinity,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7A4BFF), Color(0xFF562EE6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF562EE6).withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _isProcessingPlayAgain
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            'Play Again',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
              if (didWin && !_hasClaimed) ...[
                const SizedBox(height: 14),

                // Claim Reward
                GestureDetector(
                  onTap: _isProcessingAd ? null : _claimCoins,
                  child: Container(
                    width: double.infinity,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFECFF),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Center(
                      child: _isProcessingClaim
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Color(0xFF562EE6),
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(
                              'Claim Reward',
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF562EE6),
                              ),
                            ),
                    ),
                  ),
                ),
              ] else ...[
                // const SizedBox(height: 14),

                // Exit to Menu
                // GestureDetector(
                //   onTap: () {
                //     setState(() {
                //       _hasStarted = false;
                //       _isGameOver = false;
                //       _score = 0;
                //       _timeLeftSeconds = 15;
                //       _timerProgress = 1.0;
                //       _originalCoinsEarned = 0;
                //       _coinsEarned = 0;
                //     });
                //   },
                //   child: Container(
                //     width: double.infinity,
                //     height: 60,
                //     decoration: BoxDecoration(
                //       color: const Color(0xFFF1F1FB),
                //       borderRadius: BorderRadius.circular(30),
                //     ),
                //     child: Center(
                //       child: Text(
                //         'Exit to Menu',
                //         style: GoogleFonts.outfit(
                //           fontSize: 18,
                //           fontWeight: FontWeight.w900,
                //           color: const Color(0xFF868A9F),
                //         ),
                //       ),
                //     ),
                //   ),
                // ),
              ],
              const SizedBox(height: 30),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRewardRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF6E3AFF),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF131326),
          ),
        ),
      ],
    );
  }
}

class _InstructionStep extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final Color color;

  const _InstructionStep({
    required this.icon,
    required this.title,
    required this.desc,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: AppColors.cardBorder),
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
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF131326),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              desc,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 9,
                color: Color(0xFF868A9F),
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Models for Particle physics & floating texts ───────────────────

class _TapParticle {
  double x;
  double y;
  double vx;
  double vy;
  double rotation;
  double vRotation;
  double scale;
  double age = 0;
  double lifeTime;
  Color color;

  _TapParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.rotation,
    required this.vRotation,
    required this.scale,
    required this.lifeTime,
    required this.color,
  });
}

class _FloatingText {
  double x;
  double y;
  String text;
  Color color;
  double fontSize;
  double vy;
  double age = 0;
  double lifeTime;

  _FloatingText({
    required this.x,
    required this.y,
    required this.text,
    required this.color,
    required this.fontSize,
    required this.vy,
    required this.lifeTime,
  });
}

// ─── Screen Physics Painters ──────────────────────────────────────────

class _OverlaysPainter extends CustomPainter {
  final List<_TapParticle> particles;
  final List<_FloatingText> floatingTexts;

  _OverlaysPainter(this.particles, this.floatingTexts);

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Sparks (Spiky Star / Quad shapes)
    for (final p in particles) {
      final double progress = p.age / p.lifeTime;
      final double currentScale = p.scale * (1.0 - progress);
      if (currentScale <= 0) continue;

      final paint = Paint()
        ..color = p.color.withOpacity(1.0 - progress)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rotation);

      // Draw a spiky diamond spark
      final path = Path()
        ..moveTo(0, -currentScale * 1.5)
        ..lineTo(currentScale * 0.4, -currentScale * 0.4)
        ..lineTo(currentScale * 1.5, 0)
        ..lineTo(currentScale * 0.4, currentScale * 0.4)
        ..moveTo(0, currentScale * 1.5)
        ..lineTo(-currentScale * 0.4, currentScale * 0.4)
        ..lineTo(-currentScale * 1.5, 0)
        ..lineTo(-currentScale * 0.4, -currentScale * 0.4)
        ..close();

      canvas.drawPath(path, paint);
      canvas.restore();
    }

    // 2. Draw Floating Multiplier Scores
    for (final ft in floatingTexts) {
      final double progress = ft.age / ft.lifeTime;
      final double alpha = 1.0 - progress;

      final textPainter = TextPainter(
        text: TextSpan(
          text: ft.text,
          style: TextStyle(
            color: ft.color.withOpacity(alpha),
            fontSize: ft.fontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.2 * alpha),
                offset: const Offset(0, 1.5),
                blurRadius: 3.0,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(ft.x - textPainter.width / 2, ft.y - textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}



// ─── Cartoon Hand Tapping Painter ────────────────────────────────────

class _HandTapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = const Color(0xFF562EE6)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    // A beautiful cartoon cartoon index-pointing hand!
    // Start at bottom of hand
    path.moveTo(size.width * 0.45, size.height * 0.9);
    // Left edge of hand
    path.quadraticBezierTo(
      size.width * 0.25,
      size.height * 0.75,
      size.width * 0.35,
      size.height * 0.6,
    );
    // Index finger going straight up
    path.lineTo(size.width * 0.35, size.height * 0.25);
    path.quadraticBezierTo(
      size.width * 0.4,
      size.height * 0.15,
      size.width * 0.45,
      size.height * 0.25,
    );
    path.lineTo(size.width * 0.45, size.height * 0.45);

    // Middle finger
    path.quadraticBezierTo(
      size.width * 0.55,
      size.height * 0.4,
      size.width * 0.55,
      size.height * 0.48,
    );
    // Ring finger
    path.quadraticBezierTo(
      size.width * 0.65,
      size.height * 0.43,
      size.width * 0.65,
      size.height * 0.51,
    );
    // Pinky finger
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height * 0.48,
      size.width * 0.75,
      size.height * 0.58,
    );

    // Bottom right wrist curving back to start
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height * 0.85,
      size.width * 0.45,
      size.height * 0.9,
    );

    // Draw shadow
    canvas.drawPath(
      path.shift(const Offset(2, 4)),
      Paint()
        ..color = const Color(0x1F000000)
        ..style = PaintingStyle.fill,
    );

    // Draw hand fill
    canvas.drawPath(path, paint);
    // Draw hand outline
    canvas.drawPath(path, strokePaint);

    // Draw crease lines inside the hand for realism
    canvas.drawLine(
      Offset(size.width * 0.45, size.height * 0.55),
      Offset(size.width * 0.45, size.height * 0.75),
      strokePaint..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Tapped Ripple Shockwave Model ───────────────────────────────────

class _RippleEffect {
  double scale = 1.0;
  double opacity = 1.0;
}

// ─── Drifting Background Mockup Drifters Model ────────────────────────

class _BgElement {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  double rotation;
  double vRotation;
  final bool isStar; // true for star, false for hollow circle

  _BgElement({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.rotation,
    required this.vRotation,
    required this.isStar,
  });
}
