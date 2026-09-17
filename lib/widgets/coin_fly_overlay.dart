import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../business/sound_service.dart';
import '../theme/app_theme.dart';
import 'app_header.dart';

/// Production-ready Flying Coin Particle Animation with Bezier flight paths.
/// Spawns from any dialog or claim button and flies directly to the AppHeader balance badge.
class CoinFlyOverlay extends StatefulWidget {
  final Offset fromPosition;
  final int coinCount;
  final VoidCallback? onComplete;

  const CoinFlyOverlay({
    super.key,
    required this.fromPosition,
    this.coinCount = 10,
    this.onComplete,
  });

  /// Spawns the flying coin animation globally in the root overlay.
  static void spawn(
    BuildContext context, {
    required Offset fromPosition,
    int coinCount = 10,
    VoidCallback? onComplete,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      onComplete?.call();
      return;
    }

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => CoinFlyOverlay(
        fromPosition: fromPosition,
        coinCount: coinCount,
        onComplete: () {
          try {
            if (entry.mounted) {
              entry.remove();
            }
          } catch (_) {}
          onComplete?.call();
        },
      ),
    );

    overlay.insert(entry);
  }

  @override
  State<CoinFlyOverlay> createState() => _CoinFlyOverlayState();
}

class _CoinFlyOverlayState extends State<CoinFlyOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_CoinParticle> _particles = [];
  final math.Random _random = math.Random();
  Offset? _targetPosition;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // Staggered coin initialization
    final count = widget.coinCount.clamp(6, 16);
    for (int i = 0; i < count; i++) {
      final angle = _random.nextDouble() * 2 * math.pi;
      final distance = 40.0 + _random.nextDouble() * 25.0;
      final burstX = math.cos(angle) * distance;
      final burstY = math.sin(angle) * distance;
      
      // Delay stagger between 0.0 and 0.22
      final delay = (i / count) * 0.22;
      // Flight duration takes remainder of time
      final flightDuration = 0.65 + _random.nextDouble() * 0.12;

      _particles.add(
        _CoinParticle(
          burstOffset: Offset(burstX, burstY),
          startDelay: delay,
          flightDuration: flightDuration,
          rotationSpeed: (_random.nextDouble() - 0.5) * 12.0,
          scaleModifier: 0.85 + _random.nextDouble() * 0.3,
          curveOffsetMultiplier: (_random.nextBool() ? 1.0 : -1.0) * (40.0 + _random.nextDouble() * 40.0),
        ),
      );
    }

    _controller.addListener(_onTick);
    _controller.forward().then((_) {
      _finishAnimation();
    });
  }

  void _finishAnimation() {
    if (!_completed) {
      _completed = true;
      widget.onComplete?.call();
    }
  }

  void _onTick() {
    final progress = _controller.value;
    for (final p in _particles) {
      if (!p.hasArrived) {
        final localProgress = ((progress - p.startDelay) / p.flightDuration).clamp(0.0, 1.0);
        if (localProgress >= 1.0 && !p.hasArrived) {
          p.hasArrived = true;
          _onParticleArrival();
        }
      }
    }
  }

  void _onParticleArrival() {
    SoundService.instance.playCoin();
    HapticFeedback.lightImpact();
    RbxAppHeader.pulseBadge();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Offset _resolveTarget(BuildContext context) {
    if (_targetPosition != null) return _targetPosition!;

    try {
      final keyContext = RbxAppHeader.balanceBadgeKey?.currentContext;
      if (keyContext != null && keyContext.mounted) {
        final renderBox = keyContext.findRenderObject() as RenderBox?;
        if (renderBox != null && renderBox.hasSize) {
          final pos = renderBox.localToGlobal(
            Offset(renderBox.size.width / 2, renderBox.size.height / 2),
          );
          _targetPosition = pos;
          return pos;
        }
      }
    } catch (_) {}

    final media = MediaQuery.of(context);
    final fallback = Offset(media.size.width - 76, media.padding.top + 33);
    _targetPosition = fallback;
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final target = _resolveTarget(context);
    final start = widget.fromPosition;

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final progress = _controller.value;

          return Stack(
            children: _particles.map((p) {
              if (progress < p.startDelay) {
                return const SizedBox.shrink();
              }

              final localProgress =
                  ((progress - p.startDelay) / p.flightDuration).clamp(0.0, 1.0);

              if (localProgress >= 1.0) {
                return const SizedBox.shrink();
              }

              // Phase 1: Radial burst (0.0 to 0.25 local)
              // Phase 2: Curved flight along Bezier arc (0.25 to 1.0 local)
              final Offset currentPos;
              final double scale;

              final burstPos = start + p.burstOffset;

              if (localProgress < 0.25) {
                final burstT = Curves.easeOutCubic.transform(localProgress / 0.25);
                currentPos = Offset.lerp(start, burstPos, burstT)!;
                scale = burstT * p.scaleModifier;
              } else {
                final flightT =
                    Curves.easeInOutQuad.transform((localProgress - 0.25) / 0.75);

                // Quadratic Bezier arc
                final p0 = burstPos;
                final p2 = target;
                final mid = Offset((p0.dx + p2.dx) / 2, (p0.dy + p2.dy) / 2);
                final p1 = Offset(mid.dx + p.curveOffsetMultiplier, mid.dy - 60);

                final oneMinusT = 1.0 - flightT;
                final bx = oneMinusT * oneMinusT * p0.dx +
                    2 * oneMinusT * flightT * p1.dx +
                    flightT * flightT * p2.dx;
                final by = oneMinusT * oneMinusT * p0.dy +
                    2 * oneMinusT * flightT * p1.dy +
                    flightT * flightT * p2.dy;

                currentPos = Offset(bx, by);
                scale = (1.0 - (flightT * 0.3)) * p.scaleModifier;
              }

              final rotation = localProgress * p.rotationSpeed;

              return Positioned(
                left: currentPos.dx - 12,
                top: currentPos.dy - 12,
                child: Transform.rotate(
                  angle: rotation,
                  child: Transform.scale(
                    scale: scale.clamp(0.0, 1.3),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x66FFB800),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Image.asset(
                        AppAssets.goldCoin,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.monetization_on_rounded,
                          color: Color(0xFFFFB800),
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _CoinParticle {
  final Offset burstOffset;
  final double startDelay;
  final double flightDuration;
  final double rotationSpeed;
  final double scaleModifier;
  final double curveOffsetMultiplier;
  bool hasArrived = false;

  _CoinParticle({
    required this.burstOffset,
    required this.startDelay,
    required this.flightDuration,
    required this.rotationSpeed,
    required this.scaleModifier,
    required this.curveOffsetMultiplier,
  });
}
