import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Full-screen animated welcome bonus overlay.
///
/// Shows a coin burst animation with floating confetti particles
/// followed by a "Claim My 50 Coins!" button.
/// Call [WelcomeBonusOverlay.show] to display it as an overlay entry.
class WelcomeBonusOverlay extends StatefulWidget {
  /// Called immediately when the user taps "Claim" (before dismiss animation begins).
  final VoidCallback? onClaimStart;

  /// Called after the user taps "Claim" and the dismiss animation completes.
  final VoidCallback onClaimed;

  const WelcomeBonusOverlay({
    super.key,
    required this.onClaimed,
    this.onClaimStart,
  });

  /// Inserts the overlay into the nearest [Overlay] and returns the entry.
  /// Remove the entry or call [onClaimed] to dismiss.
  static OverlayEntry show(
    BuildContext context, {
    required VoidCallback onClaimed,
    VoidCallback? onClaimStart,
  }) {
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => WelcomeBonusOverlay(
        onClaimStart: onClaimStart,
        onClaimed: () {
          entry.remove();
          onClaimed();
        },
      ),
    );
    Overlay.of(context).insert(entry);
    return entry;
  }

  @override
  State<WelcomeBonusOverlay> createState() => _WelcomeBonusOverlayState();
}

class _WelcomeBonusOverlayState extends State<WelcomeBonusOverlay>
    with TickerProviderStateMixin {
  // Background fade-in / fade-out
  late final AnimationController _bgCtrl;
  late final Animation<double> _bgOpacity;

  // Coin entrance: scale bounce
  late final AnimationController _coinCtrl;
  late final Animation<double> _coinScale;
  late final Animation<double> _coinRotate;

  // Continuous idle coin perspective flip
  late final AnimationController _spinCtrl;

  // "+50 RBX Coins" text slide-up
  late final AnimationController _textCtrl;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _textOpacity;

  // Claim button slide-up
  late final AnimationController _btnCtrl;
  late final Animation<double> _btnOpacity;
  late final Animation<Offset> _btnSlide;

  // Confetti burst
  late final AnimationController _particleCtrl;
  final List<_Particle> _particles = [];

  // Dismiss: quick scale pop then fade
  late final AnimationController _dismissCtrl;
  late final Animation<double> _dismissScale;

  bool _isClaiming = false;

  @override
  void initState() {
    super.initState();
    _buildParticles();
    _setupAnimations();
    _runEntrance();
  }

  // ── Particle generation ───────────────────────────────────────────────────

  void _buildParticles() {
    final rng = math.Random(7);
    const colors = [
      Color(0xFF5637E6),
      Color(0xFFFFD700),
      Color(0xFFFF6B6B),
      Color(0xFF4ECDC4),
      Color(0xFFFFE66D),
      Color(0xFFA855F7),
      Color(0xFF22D3EE),
      Color(0xFFFF9F43),
    ];
    for (int i = 0; i < 30; i++) {
      _particles.add(_Particle(
        color: colors[rng.nextInt(colors.length)],
        angle: rng.nextDouble() * math.pi * 2,
        distance: 130 + rng.nextDouble() * 190,
        size: 6 + rng.nextDouble() * 9,
        shape: rng.nextBool() ? _Shape.circle : _Shape.rect,
        rotateSpeed: (rng.nextDouble() - 0.5) * 7,
        delay: rng.nextDouble() * 0.25,
      ));
    }
  }

  // ── Animation setup ───────────────────────────────────────────────────────

  void _setupAnimations() {
    _bgCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _bgOpacity = CurvedAnimation(parent: _bgCtrl, curve: Curves.easeOut);

    _coinCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 780));
    _coinScale = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 1.18)
              .chain(CurveTween(curve: Curves.easeOutBack)),
          weight: 60),
      TweenSequenceItem(
          tween: Tween(begin: 1.18, end: 0.94)
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 20),
      TweenSequenceItem(
          tween: Tween(begin: 0.94, end: 1.0)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 20),
    ]).animate(_coinCtrl);
    _coinRotate = Tween<double>(begin: -0.12, end: 0.0).animate(
      CurvedAnimation(parent: _coinCtrl, curve: Curves.easeOutBack),
    );

    _spinCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..repeat();

    _textCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 480));
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.45), end: Offset.zero)
        .animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOutCubic));
    _textOpacity = CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut);

    _btnCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 430));
    _btnOpacity = CurvedAnimation(parent: _btnCtrl, curve: Curves.easeOut);
    _btnSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(CurvedAnimation(parent: _btnCtrl, curve: Curves.easeOutCubic));

    _particleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 950));

    _dismissCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    _dismissScale = Tween<double>(begin: 1.0, end: 1.07).animate(
      CurvedAnimation(parent: _dismissCtrl, curve: Curves.easeInCubic),
    );
  }

  // ── Entrance sequence ─────────────────────────────────────────────────────

  Future<void> _runEntrance() async {
    await Future.delayed(const Duration(milliseconds: 60));
    if (!mounted) return;
    _bgCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    _coinCtrl.forward();
    _particleCtrl.forward();
    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 520));
    if (!mounted) return;
    _textCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    _btnCtrl.forward();
    HapticFeedback.lightImpact();
  }

  // ── Claim handler ─────────────────────────────────────────────────────────

  Future<void> _handleClaim() async {
    if (_isClaiming) return;
    setState(() => _isClaiming = true);
    HapticFeedback.heavyImpact();
    widget.onClaimStart?.call();
    await _dismissCtrl.forward();
    if (!mounted) return;
    await _bgCtrl.reverse();
    if (!mounted) return;
    widget.onClaimed();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _coinCtrl.dispose();
    _spinCtrl.dispose();
    _textCtrl.dispose();
    _btnCtrl.dispose();
    _particleCtrl.dispose();
    _dismissCtrl.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // Confetti bursts from centre of coin which sits ~38% down the screen
    final coinCentre = Offset(size.width / 2, size.height * 0.35);

    return FadeTransition(
      opacity: _bgOpacity,
      child: Material(
        color: Colors.black.withValues(alpha: 0.80),
        child: ScaleTransition(
          scale: _dismissScale,
          child: SizedBox.expand(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // ── Confetti ────────────────────────────────────────────────
                _ParticleField(
                  particles: _particles,
                  animation: _particleCtrl,
                  center: coinCentre,
                ),

                // ── Main content ─────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Coin
                      _GlowingCoin(
                        coinScale: _coinScale,
                        coinRotate: _coinRotate,
                        spinCtrl: _spinCtrl,
                      ),

                      const SizedBox(height: 30),

                      // +50 text block
                      SlideTransition(
                        position: _textSlide,
                        child: FadeTransition(
                          opacity: _textOpacity,
                          child: Column(
                            children: [
                              ShaderMask(
                                shaderCallback: (bounds) =>
                                    const LinearGradient(
                                  colors: [
                                    Color(0xFFFFD700),
                                    Color(0xFFFFA500),
                                  ],
                                ).createShader(bounds),
                                child: const Text(
                                  '+50',
                                  style: TextStyle(
                                    fontSize: 80,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: -3,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'RBX Coins',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.4,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.22),
                                    width: 1.2,
                                  ),
                                ),
                                child: const Text(
                                  '🎁  Welcome Bonus — Just for you!',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    letterSpacing: 0.1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 44),

                      // Claim button
                      SlideTransition(
                        position: _btnSlide,
                        child: FadeTransition(
                          opacity: _btnOpacity,
                          child: _ClaimButton(
                            isClaiming: _isClaiming,
                            onTap: _handleClaim,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Glowing spinning coin
// ─────────────────────────────────────────────────────────────────────────────

class _GlowingCoin extends StatelessWidget {
  final Animation<double> coinScale;
  final Animation<double> coinRotate;
  final AnimationController spinCtrl;

  const _GlowingCoin({
    required this.coinScale,
    required this.coinRotate,
    required this.spinCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: coinScale,
      child: RotationTransition(
        turns: coinRotate,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer glow
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFFD700).withValues(alpha: 0.30),
                    const Color(0xFFFFD700).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
            // Inner ring
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.18),
                  width: 1.5,
                ),
              ),
            ),
            // Perspective-flip idle spin
            AnimatedBuilder(
              animation: spinCtrl,
              builder: (_, child) {
                final scaleX =
                    math.cos(spinCtrl.value * math.pi * 2).abs();
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..scaleByDouble(scaleX, 1.0, 1.0, 1.0),
                  child: child,
                );
              },
              child: Image.asset(
                AppAssets.goldRbxCoin,
                width: 110,
                height: 110,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.monetization_on_rounded,
                  size: 110,
                  color: Color(0xFFFFD700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Claim button — same style as onboarding _PrimaryActionButton
// ─────────────────────────────────────────────────────────────────────────────

class _ClaimButton extends StatefulWidget {
  final bool isClaiming;
  final VoidCallback onTap;

  const _ClaimButton({required this.isClaiming, required this.onTap});

  @override
  State<_ClaimButton> createState() => _ClaimButtonState();
}

class _ClaimButtonState extends State<_ClaimButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 120),
    lowerBound: 0.0,
    upperBound: 0.03,
  );

  void _onTapDown(TapDownDetails _) {
    if (widget.isClaiming) return;
    HapticFeedback.lightImpact();
    _controller.forward();
  }

  void _onTapUp(TapUpDetails _) => _controller.reverse();
  void _onTapCancel() => _controller.reverse();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.isClaiming ? null : widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Transform.scale(
          scale: 1 - _controller.value,
          child: child,
        ),
        child: Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x3D5637E6),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.isClaiming)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              else ...[
                Flexible(
                  child: Text(
                    '🎉  Claim My 50 Coins!',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Confetti particle system
// ─────────────────────────────────────────────────────────────────────────────


enum _Shape { circle, rect }

class _Particle {
  final Color color;
  final double angle;
  final double distance;
  final double size;
  final _Shape shape;
  final double rotateSpeed;
  final double delay;

  const _Particle({
    required this.color,
    required this.angle,
    required this.distance,
    required this.size,
    required this.shape,
    required this.rotateSpeed,
    required this.delay,
  });
}

class _ParticleField extends StatelessWidget {
  final List<_Particle> particles;
  final Animation<double> animation;
  final Offset center;

  const _ParticleField({
    required this.particles,
    required this.animation,
    required this.center,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) => CustomPaint(
        size: Size.infinite,
        painter: _ParticlePainter(
          particles: particles,
          progress: animation.value,
          center: center,
        ),
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  final Offset center;

  const _ParticlePainter({
    required this.particles,
    required this.progress,
    required this.center,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final rawT = (progress - p.delay) / (1.0 - p.delay);
      final t = rawT.clamp(0.0, 1.0);
      if (t <= 0) continue;

      final eased = Curves.easeOutCubic.transform(t);
      // Arc: arc up slightly before falling with gravity simulation
      final dx = math.cos(p.angle) * p.distance * eased;
      final dy = math.sin(p.angle) * p.distance * eased +
          (60 * eased * eased); // gravity pull down

      // Fade out after 70% of animation
      final opacity = t < 0.65 ? 1.0 : (1.0 - (t - 0.65) / 0.35);

      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity.clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;

      final pos = Offset(center.dx + dx, center.dy + dy);

      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(p.rotateSpeed * t * math.pi);

      if (p.shape == _Shape.circle) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: p.size,
              height: p.size * 0.5,
            ),
            const Radius.circular(2),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.progress != progress;
}
