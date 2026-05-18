import 'package:flutter/material.dart';
import 'dart:math' as math;

class CoinBurstWidget extends StatefulWidget {
  final bool isTriggered;
  final VoidCallback? onComplete;

  const CoinBurstWidget({
    super.key,
    required this.isTriggered,
    this.onComplete,
  });

  @override
  State<CoinBurstWidget> createState() => _CoinBurstWidgetState();
}

class _CoinBurstWidgetState extends State<CoinBurstWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<CoinParticle> _particles = [];
  final math.Random _rnd = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..addListener(() {
        _updateParticles();
      });
  }

  @override
  void didUpdateWidget(covariant CoinBurstWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTriggered && !oldWidget.isTriggered) {
      _generateParticles();
      _controller.forward(from: 0.0).then((_) {
        widget.onComplete?.call();
      });
    }
  }

  void _generateParticles() {
    _particles.clear();
    // Generate 25 coins
    for (int i = 0; i < 25; i++) {
      final angle =
          -math.pi / 2 + (_rnd.nextDouble() - 0.5) * math.pi; // Upwards cone
      final speed = _rnd.nextDouble() * 15 + 10;

      _particles.add(CoinParticle(
        x: 0,
        y: 0,
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed,
        rotX: _rnd.nextDouble() * math.pi * 2,
        rotY: _rnd.nextDouble() * math.pi * 2,
        rotZ: _rnd.nextDouble() * math.pi * 2,
        vRotX: (_rnd.nextDouble() - 0.5) * 0.4,
        vRotY: (_rnd.nextDouble() - 0.5) * 0.4,
        vRotZ: (_rnd.nextDouble() - 0.5) * 0.4,
        scale: _rnd.nextDouble() * 0.4 + 0.6,
      ));
    }
  }

  void _updateParticles() {
    for (var p in _particles) {
      p.x += p.vx;
      p.y += p.vy;
      p.vy += 0.8; // Gravity

      p.rotX += p.vRotX;
      p.rotY += p.vRotY;
      p.rotZ += p.vRotZ;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isTriggered || _particles.isEmpty) {
      return const SizedBox.shrink();
    }
    return CustomPaint(
      painter:
          CoinBurstPainter(particles: _particles, progress: _controller.value),
      size: Size.infinite,
    );
  }
}

class CoinParticle {
  double x, y;
  double vx, vy;
  double rotX, rotY, rotZ;
  double vRotX, vRotY, vRotZ;
  double scale;

  CoinParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.rotX,
    required this.rotY,
    required this.rotZ,
    required this.vRotX,
    required this.vRotY,
    required this.vRotZ,
    required this.scale,
  });
}

class CoinBurstPainter extends CustomPainter {
  final List<CoinParticle> particles;
  final double progress;

  CoinBurstPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 + 50; // Start slightly lower (at chest mouth)

    // Sort particles by Z so things in back render first
    // We'll estimate Z based on vy and scale, or just let them render in order since they are fast.

    // Fade out near the end
    final opacity = progress > 0.8 ? (1.0 - progress) * 5 : 1.0;
    if (opacity <= 0) return;

    for (var p in particles) {
      canvas.save();
      canvas.translate(cx + p.x, cy + p.y);
      canvas.scale(p.scale);

      _draw3DCoin(canvas, p.rotX, p.rotY, p.rotZ, opacity);

      canvas.restore();
    }
  }

  void _draw3DCoin(
      Canvas canvas, double rx, double ry, double rz, double opacity) {
    // 3D rotation projection
    // We will draw a hexagonal coin with a square hole

    const double radius = 24.0;
    const double thickness = 8.0;

    // Colors
    final goldTop = const Color(0xFFFFDE6B).withOpacity(opacity);
    final goldFace = const Color(0xFFF5C842).withOpacity(opacity);
    final goldDark = const Color(0xFFD4950A).withOpacity(opacity);
    final goldSide = const Color(0xFFC28200).withOpacity(opacity);

    // Create base hexagon vertices
    List<MathVector3> baseVerts = [];
    List<MathVector3> holeVerts = [];

    for (int i = 0; i < 6; i++) {
      double angle = i * math.pi / 3;
      baseVerts.add(
          MathVector3(math.cos(angle) * radius, math.sin(angle) * radius, 0));
    }

    final holeRadius = radius * 0.35;
    for (int i = 0; i < 4; i++) {
      double angle = (i * math.pi / 2) + (math.pi / 4);
      holeVerts.add(MathVector3(
          math.cos(angle) * holeRadius, math.sin(angle) * holeRadius, 0));
    }

    // Function to rotate point
    MathVector3 rotate(MathVector3 v) {
      // Rot X
      double y1 = v.y * math.cos(rx) - v.z * math.sin(rx);
      double z1 = v.y * math.sin(rx) + v.z * math.cos(rx);
      // Rot Y
      double x2 = v.x * math.cos(ry) + z1 * math.sin(ry);
      double z2 = -v.x * math.sin(ry) + z1 * math.cos(ry);
      // Rot Z
      double x3 = x2 * math.cos(rz) - y1 * math.sin(rz);
      double y3 = x2 * math.sin(rz) + y1 * math.cos(rz);

      return MathVector3(x3, y3, z2);
    }

    // Generate rotated top and bottom faces
    List<MathVector3> topOuter = baseVerts
        .map((v) => rotate(MathVector3(v.x, v.y, thickness / 2)))
        .toList();
    List<MathVector3> topInner = holeVerts
        .map((v) => rotate(MathVector3(v.x, v.y, thickness / 2)))
        .toList();

    List<MathVector3> botOuter = baseVerts
        .map((v) => rotate(MathVector3(v.x, v.y, -thickness / 2)))
        .toList();
    List<MathVector3> botInner = holeVerts
        .map((v) => rotate(MathVector3(v.x, v.y, -thickness / 2)))
        .toList();

    // Determine normal of top face to see if it's facing us
    // Normal = cross product of two edge vectors
    MathVector3 edge1 = MathVector3(topOuter[1].x - topOuter[0].x,
        topOuter[1].y - topOuter[0].y, topOuter[1].z - topOuter[0].z);
    MathVector3 edge2 = MathVector3(topOuter[2].x - topOuter[1].x,
        topOuter[2].y - topOuter[1].y, topOuter[2].z - topOuter[1].z);
    double normalZ = edge1.x * edge2.y - edge1.y * edge2.x;

    bool topFacing = normalZ > 0;

    // Helper to draw a quad (for sides)
    void drawQuad(MathVector3 p1, MathVector3 p2, MathVector3 p3,
        MathVector3 p4, Color c) {
      // Check normal of the quad to cull backfaces
      double nx = (p2.x - p1.x) * (p3.y - p2.y) - (p2.y - p1.y) * (p3.x - p2.x);
      if (nx > 0) {
        // Facing away
        return;
      }
      final path = Path()
        ..moveTo(p1.x, p1.y)
        ..lineTo(p2.x, p2.y)
        ..lineTo(p3.x, p3.y)
        ..lineTo(p4.x, p4.y)
        ..close();
      canvas.drawPath(
          path,
          Paint()
            ..color = c
            ..style = PaintingStyle.fill);
      canvas.drawPath(
          path,
          Paint()
            ..color = goldDark
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.5);
    }

    // Helper to draw face
    void drawFace(List<MathVector3> outer, List<MathVector3> inner, Color fill,
        Color highlight) {
      final path = Path();
      path.moveTo(outer[0].x, outer[0].y);
      for (int i = 1; i < outer.length; i++) {
        path.lineTo(outer[i].x, outer[i].y);
      }
      path.close();

      final innerPath = Path();
      innerPath.moveTo(inner[0].x, inner[0].y);
      for (int i = 1; i < inner.length; i++) {
        innerPath.lineTo(inner[i].x, inner[i].y);
      }
      innerPath.close();

      // Combine paths with even/odd to cut the hole
      final fullPath = Path.combine(PathOperation.difference, path, innerPath);

      canvas.drawPath(fullPath, Paint()..color = fill);
      canvas.drawPath(
          path,
          Paint()
            ..color = highlight
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0);
      canvas.drawPath(
          innerPath,
          Paint()
            ..color = goldDark
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0);

      // Draw inner rim (emboss effect)
      final embossPath = Path();
      for (int i = 0; i < outer.length; i++) {
        double px = outer[i].x * 0.8;
        double py = outer[i].y * 0.8;
        if (i == 0)
          embossPath.moveTo(px, py);
        else
          embossPath.lineTo(px, py);
      }
      embossPath.close();
      canvas.drawPath(
          embossPath,
          Paint()
            ..color = highlight
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8);
    }

    // Draw sides
    // Outer sides
    for (int i = 0; i < 6; i++) {
      int next = (i + 1) % 6;
      // Depending on normal, we might draw bot to top or top to bot to get correct winding
      MathVector3 t1 = topOuter[i];
      MathVector3 t2 = topOuter[next];
      MathVector3 b1 = botOuter[i];
      MathVector3 b2 = botOuter[next];

      // Determine shading based on angle
      double shade = 0.7 + 0.3 * math.cos(i * math.pi / 3 + rz);
      Color sideColor = Color.lerp(goldSide, goldTop, shade)!;

      drawQuad(t1, t2, b2, b1, sideColor);
    }

    // Inner hole sides
    for (int i = 0; i < 4; i++) {
      int next = (i + 1) % 4;
      MathVector3 t1 = topInner[i];
      MathVector3 t2 = topInner[next];
      MathVector3 b1 = botInner[i];
      MathVector3 b2 = botInner[next];

      drawQuad(b1, b2, t2, t1, goldDark); // Inner hole is usually darker
    }

    // Draw bottom or top face depending on which is visible
    if (topFacing) {
      drawFace(
          botOuter, botInner, goldSide, goldSide); // Draw bot face just in case
      drawFace(topOuter, topInner, goldFace, goldTop);
    } else {
      drawFace(topOuter, topInner, goldSide, goldSide);
      drawFace(botOuter, botInner, goldFace, goldTop);
    }
  }

  @override
  bool shouldRepaint(covariant CoinBurstPainter oldDelegate) => true;
}

class MathVector3 {
  final double x, y, z;
  MathVector3(this.x, this.y, this.z);
}
