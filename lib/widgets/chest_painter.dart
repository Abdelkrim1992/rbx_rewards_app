import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Draws a 3D purple & gold treasure chest matching the game-style reference.
class ChestPainter extends CustomPainter {
  /// 0.0 = closed, 1.0 = fully open
  final double openAmount;

  ChestPainter({this.openAmount = 0.0});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    // ── Colors ──
    const purpleDark = Color(0xFF6B2FA0);
    const purpleMid = Color(0xFF8B45C8);
    const purpleLight = Color(0xFF9F5DD6);
    const goldDark = Color(0xFFD4950A);
    const goldMid = Color(0xFFE8AD1C);
    const goldLight = Color(0xFFF5C842);
    const goldHighlight = Color(0xFFFFDE6B);
    const gemPurple = Color(0xFF5B28A0);
    const gemLight = Color(0xFF8B5DD6);
    const keyholeColor = Color(0xFF2A1040);

    // ── Dimensions ──
    final bodyW = w * 0.82;
    final bodyH = h * 0.38;
    final bodyLeft = cx - bodyW / 2;
    final bodyRight = cx + bodyW / 2;
    final bodyBottom = h * 0.88;
    final bodyTopY = bodyBottom - bodyH;

    final lidH = h * 0.28;
    final bandW = bodyW * 0.08;

    // ════════════════════════════════
    // ═══ SHADOW ═══
    // ════════════════════════════════
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, bodyBottom + 6), width: bodyW * 1.05, height: 20),
      Paint()
        ..color = const Color(0x30000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    // ════════════════════════════════
    // ═══ BODY (Bottom Box) ═══
    // ════════════════════════════════

    // Purple body - main front face
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(bodyLeft, bodyTopY, bodyRight, bodyBottom),
      const Radius.circular(6),
    );
    canvas.drawRRect(
        bodyRect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [purpleLight, purpleMid, purpleDark],
          ).createShader(
              Rect.fromLTRB(bodyLeft, bodyTopY, bodyRight, bodyBottom)));

    // Wood grain texture lines (subtle)
    final grainPaint = Paint()
      ..color = purpleDark.withOpacity(0.2)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < 5; i++) {
      final y = bodyTopY + bodyH * 0.2 + i * bodyH * 0.14;
      canvas.drawLine(
        Offset(bodyLeft + bandW + 8, y),
        Offset(bodyRight - bandW - 8, y),
        grainPaint,
      );
    }

    // ── Gold frame bands (vertical) ──
    // Left vertical band
    _drawGoldBand(
        canvas,
        Rect.fromLTRB(bodyLeft, bodyTopY, bodyLeft + bandW, bodyBottom),
        goldDark,
        goldMid,
        goldLight);
    // Right vertical band
    _drawGoldBand(
        canvas,
        Rect.fromLTRB(bodyRight - bandW, bodyTopY, bodyRight, bodyBottom),
        goldDark,
        goldMid,
        goldLight);
    // Center vertical band
    _drawGoldBand(
        canvas,
        Rect.fromLTRB(cx - bandW * 0.5, bodyTopY, cx + bandW * 0.5, bodyBottom),
        goldDark,
        goldMid,
        goldLight);

    // ── Gold frame bands (horizontal) ──
    final hBandH = bandW * 0.7;
    // Top horizontal band
    _drawGoldBand(
        canvas,
        Rect.fromLTRB(bodyLeft, bodyTopY, bodyRight, bodyTopY + hBandH),
        goldDark,
        goldMid,
        goldLight);
    // Bottom horizontal band
    _drawGoldBand(
        canvas,
        Rect.fromLTRB(bodyLeft, bodyBottom - hBandH, bodyRight, bodyBottom),
        goldDark,
        goldMid,
        goldLight);

    // ── Corner rivets on body ──
    final rivetR = bodyW * 0.025;
    final bodyRivets = [
      Offset(bodyLeft + bandW / 2, bodyTopY + hBandH / 2),
      Offset(bodyRight - bandW / 2, bodyTopY + hBandH / 2),
      Offset(bodyLeft + bandW / 2, bodyBottom - hBandH / 2),
      Offset(bodyRight - bandW / 2, bodyBottom - hBandH / 2),
      Offset(cx, bodyTopY + hBandH / 2),
      Offset(cx, bodyBottom - hBandH / 2),
      // Mid rivets on vertical bands
      Offset(bodyLeft + bandW / 2, bodyTopY + bodyH * 0.5),
      Offset(bodyRight - bandW / 2, bodyTopY + bodyH * 0.5),
    ];
    for (final r in bodyRivets) {
      _drawRivet(canvas, r, rivetR, goldLight, goldDark);
    }

    // ── Side ring (right side) ──
    final ringCx = bodyRight - bandW * 0.3;
    final ringCy = bodyTopY + bodyH * 0.5;
    final ringR = bodyW * 0.05;
    canvas.drawCircle(
        Offset(ringCx, ringCy), ringR + 2, Paint()..color = goldDark);
    canvas.drawCircle(Offset(ringCx, ringCy), ringR, Paint()..color = goldMid);
    canvas.drawCircle(
        Offset(ringCx, ringCy), ringR * 0.55, Paint()..color = purpleMid);

    // ════════════════════════════════
    // ═══ LID (Dome Top) ═══
    // ════════════════════════════════
    canvas.save();

    // Pivot at the back-top of the body
    final pivotY = bodyTopY;
    canvas.translate(cx, pivotY);

    // Opening perspective
    final vertScale = math.max(0.15, 1.0 - openAmount * 0.7);
    final yShift = -openAmount * lidH * 0.6;
    canvas.translate(0, yShift);
    canvas.scale(1.0, vertScale);

    // Lid dome path (purple)
    final lidPath = Path();
    final lLeft = -bodyW / 2;
    final lRight = bodyW / 2;
    lidPath.moveTo(lLeft, 0);
    lidPath.lineTo(lLeft, -lidH * 0.35);
    lidPath.quadraticBezierTo(lLeft, -lidH * 0.95, lLeft * 0.55, -lidH);
    lidPath.quadraticBezierTo(0, -lidH * 1.15, -lLeft * 0.55, -lidH);
    lidPath.quadraticBezierTo(lRight, -lidH * 0.95, lRight, -lidH * 0.35);
    lidPath.lineTo(lRight, 0);
    lidPath.close();

    canvas.drawPath(
        lidPath,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [purpleLight, purpleMid, purpleDark],
          ).createShader(Rect.fromLTRB(lLeft, -lidH * 1.15, lRight, 0)));

    // Lid grain texture
    for (int i = 0; i < 3; i++) {
      final y = -lidH * 0.3 - i * lidH * 0.2;
      canvas.drawLine(
        Offset(lLeft + bandW + 8, y),
        Offset(lRight - bandW - 8, y),
        grainPaint,
      );
    }

    // ── Lid gold bands (arching over dome) ──
    // Left arch band
    _drawLidArch(canvas, lLeft, lRight, lidH, bandW, -bodyW * 0.5, goldDark,
        goldMid, goldLight);
    // Center arch band
    _drawLidArch(
        canvas, lLeft, lRight, lidH, bandW, 0, goldDark, goldMid, goldLight);
    // Right arch band
    _drawLidArch(canvas, lLeft, lRight, lidH, bandW, bodyW * 0.5, goldDark,
        goldMid, goldLight);

    // Lid base horizontal band
    _drawGoldBand(
        canvas,
        Rect.fromLTRB(lLeft, -hBandH * 0.5, lRight, hBandH * 0.5),
        goldDark,
        goldMid,
        goldLight);

    // Lid rivets along base
    for (final rx in [lLeft + bandW / 2, lRight - bandW / 2, 0.0]) {
      _drawRivet(canvas, Offset(rx, 0), rivetR, goldLight, goldDark);
    }

    // ── Purple gem on lid center ──
    final gemSize = bodyW * 0.08;
    final gemCy = -lidH * 0.55;

    // Diamond background (gold)
    final gemBg = Path();
    gemBg.moveTo(0, gemCy - gemSize * 1.3);
    gemBg.lineTo(gemSize * 1.3, gemCy);
    gemBg.lineTo(0, gemCy + gemSize * 1.3);
    gemBg.lineTo(-gemSize * 1.3, gemCy);
    gemBg.close();
    canvas.drawPath(gemBg, Paint()..color = goldMid);
    canvas.drawPath(
        gemBg,
        Paint()
          ..color = goldDark
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);

    // Gem crystal
    final gemPath = Path();
    gemPath.moveTo(0, gemCy - gemSize);
    gemPath.lineTo(gemSize, gemCy);
    gemPath.lineTo(0, gemCy + gemSize);
    gemPath.lineTo(-gemSize, gemCy);
    gemPath.close();
    canvas.drawPath(
        gemPath,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [gemLight, gemPurple],
          ).createShader(Rect.fromCenter(
              center: Offset(0, gemCy),
              width: gemSize * 2,
              height: gemSize * 2)));

    // Gem highlight
    canvas.drawLine(
      Offset(-gemSize * 0.3, gemCy - gemSize * 0.4),
      Offset(gemSize * 0.1, gemCy - gemSize * 0.1),
      Paint()
        ..color = Colors.white.withOpacity(0.5)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );

    canvas.restore();

    // ════════════════════════════════
    // ═══ LOCK (Shield shape) ═══
    // ════════════════════════════════
    if (openAmount < 0.3) {
      final lockCy = bodyTopY + 2;
      final lockW = bodyW * 0.12;
      final lockH2 = bodyH * 0.22;

      // Shield shape
      final shieldPath = Path();
      shieldPath.moveTo(cx - lockW, lockCy - lockH2 * 0.6);
      shieldPath.quadraticBezierTo(
          cx - lockW, lockCy - lockH2, cx, lockCy - lockH2);
      shieldPath.quadraticBezierTo(
          cx + lockW, lockCy - lockH2, cx + lockW, lockCy - lockH2 * 0.6);
      shieldPath.lineTo(cx + lockW, lockCy + lockH2 * 0.3);
      shieldPath.quadraticBezierTo(
          cx + lockW, lockCy + lockH2, cx, lockCy + lockH2 * 1.2);
      shieldPath.quadraticBezierTo(
          cx - lockW, lockCy + lockH2, cx - lockW, lockCy + lockH2 * 0.3);
      shieldPath.close();

      canvas.drawPath(shieldPath, Paint()..color = goldMid);
      canvas.drawPath(
          shieldPath,
          Paint()
            ..color = goldDark
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);

      // Keyhole
      canvas.drawCircle(Offset(cx, lockCy - lockH2 * 0.1), lockW * 0.25,
          Paint()..color = keyholeColor);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(cx, lockCy + lockH2 * 0.25),
              width: lockW * 0.2,
              height: lockH2 * 0.5),
          const Radius.circular(2),
        ),
        Paint()..color = keyholeColor,
      );
    }

    // ════════════════════════════════
    // ═══ SPARKLES when opening ═══
    // ════════════════════════════════
    if (openAmount > 0.2) {
      final sparkAlpha = ((openAmount - 0.2) / 0.8).clamp(0.0, 1.0);
      final sparkPaint = Paint()
        ..color = goldHighlight.withOpacity(sparkAlpha * 0.9);

      final sparkles = [
        Offset(cx - bodyW * 0.35, bodyTopY - lidH * openAmount * 0.4),
        Offset(cx + bodyW * 0.3, bodyTopY - lidH * openAmount * 0.5),
        Offset(cx, bodyTopY - lidH * openAmount * 0.7),
        Offset(cx - bodyW * 0.15, bodyTopY - lidH * openAmount * 0.9),
        Offset(cx + bodyW * 0.2, bodyTopY - lidH * openAmount * 0.3),
      ];
      for (int i = 0; i < sparkles.length; i++) {
        _drawStar(canvas, sparkles[i], 3.0 + (i % 3) * 2.0, sparkPaint);
      }

      // Inner glow
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx, bodyTopY),
            width: bodyW * 0.5,
            height: 14 * openAmount),
        Paint()
          ..color = goldHighlight.withOpacity(sparkAlpha * 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
  }

  void _drawGoldBand(
      Canvas canvas, Rect rect, Color dark, Color mid, Color light) {
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(3));
    canvas.drawRRect(
        rrect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [light, mid, dark],
          ).createShader(rect));
    // Top highlight
    canvas.drawLine(
      Offset(rect.left + 3, rect.top + 1.5),
      Offset(rect.right - 3, rect.top + 1.5),
      Paint()
        ..color = light.withOpacity(0.5)
        ..strokeWidth = 1,
    );
  }

  void _drawLidArch(Canvas canvas, double lLeft, double lRight, double lidH,
      double bandW, double xOff, Color dark, Color mid, Color light) {
    final halfBand = bandW * 0.45;
    final archPath = Path();

    // Simple arch approximation
    final t = ((xOff - lLeft) / (lRight - lLeft)).clamp(0.0, 1.0);
    final archHeight = lidH * (0.35 + 0.65 * math.sin(t * math.pi));

    archPath.moveTo(xOff - halfBand, 0);
    archPath.lineTo(xOff - halfBand, -archHeight * 0.8);
    archPath.quadraticBezierTo(
        xOff, -archHeight * 1.1, xOff + halfBand, -archHeight * 0.8);
    archPath.lineTo(xOff + halfBand, 0);
    archPath.close();

    canvas.drawPath(
        archPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [dark, mid, light, mid, dark],
          ).createShader(
              Rect.fromLTRB(xOff - halfBand, -archHeight, xOff + halfBand, 0)));
  }

  void _drawRivet(
      Canvas canvas, Offset center, double r, Color light, Color dark) {
    canvas.drawCircle(center, r + 1, Paint()..color = dark);
    canvas.drawCircle(
        center,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [light, dark],
            center: const Alignment(-0.3, -0.3),
          ).createShader(Rect.fromCircle(center: center, radius: r)));
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    for (int i = 0; i < 4; i++) {
      final angle = i * math.pi / 2;
      path.moveTo(center.dx, center.dy);
      path.lineTo(center.dx + math.cos(angle) * radius,
          center.dy + math.sin(angle) * radius);
    }
    canvas.drawPath(
        path,
        paint
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke);
    canvas.drawCircle(center, 1.5, Paint()..color = paint.color);
  }

  @override
  bool shouldRepaint(covariant ChestPainter oldDelegate) =>
      oldDelegate.openAmount != openAmount;
}
