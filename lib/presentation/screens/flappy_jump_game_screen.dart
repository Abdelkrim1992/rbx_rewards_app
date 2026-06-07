import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flame/game.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/coin_provider.dart';
import '../providers/providers.dart';
import '../providers/ad_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/game_prefs.dart';
import '../../widgets/ad_reward_dialog.dart';
import '../../widgets/quit_confirmation_dialog.dart';
import '../../models/ad_models.dart';

// --- Vector 3D Helper ---
class Vector3D {
  double x, y, z;
  Vector3D(this.x, this.y, this.z);

  Vector3D copy() => Vector3D(x, y, z);
}

// --- Parallax 3D Island ---
class ParallaxIsland {
  late Vector3D pos;
  late double size;
  late Color color;
  late List<Vector3D> vertices;

  ParallaxIsland({
    required double x,
    required double y,
    required double z,
    required this.size,
    required this.color,
  }) {
    pos = Vector3D(x, y, z);

    // Generate a simple crystalline 3D polyhedral floating rock shape
    final rnd = math.Random((x + y + z).toInt());
    vertices = [];

    // Top face vertices
    vertices.add(Vector3D(-size * 0.6, -size * 0.3, -size * 0.5));
    vertices.add(Vector3D(size * 0.6, -size * 0.3, -size * 0.5));
    vertices.add(Vector3D(size * 0.8, -size * 0.2, size * 0.5));
    vertices.add(Vector3D(-size * 0.8, -size * 0.2, size * 0.5));

    // Bottom point
    vertices.add(Vector3D(rnd.nextDouble() * 20 - 10, size * 0.8, 0));
  }
}

// --- Obstacle 3D Pillar ---
class Pillar3D {
  double worldX;
  double gapCenterY;
  double gapHeight;
  double width;
  double depth;
  bool passed = false;

  Pillar3D({
    required this.worldX,
    required this.gapCenterY,
    required this.gapHeight,
    this.width = 64.0,
    this.depth = 64.0,
  });
}

// --- Floating 3D Coin ---
class Coin3D {
  double worldX;
  double worldY;
  double rotY = 0.0;
  bool collected = false;

  Coin3D({
    required this.worldX,
    required this.worldY,
  });
}

// --- Particle Effects ---
class FlameParticle {
  double x, y, vx, vy;
  double size;
  double age = 0.0;
  double lifeTime;
  Color color;
  bool isStar;

  FlameParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.lifeTime,
    required this.color,
    this.isStar = false,
  });
}

// --- Dynamic Floating Score text ---
class GameFloatingText {
  double x, y, vy;
  String text;
  Color color;
  double fontSize;
  double age = 0.0;
  double lifeTime;

  GameFloatingText({
    required this.x,
    required this.y,
    required this.vy,
    required this.text,
    required this.color,
    required this.fontSize,
    required this.lifeTime,
  });
}

// --- Flame Game Subclass ---
class FlappyJumpGame extends FlameGame {
  // Game state
  bool hasStarted = false;
  bool isGameOver = false;
  int score = 0;
  int coinsEarned = 0;
  int combo = 0;
  int maxCombo = 0;

  // Game settings & metrics
  double gameSpeed = 220.0;
  double targetSpeed = 220.0;
  double maxSpeed = 380.0;
  double elapsedSecs = 0.0;

  // Player 3D properties
  late Vector3D playerPos;
  double playerRadius = 18.0;
  double velocityY = 0.0;
  double gravity = 1000.0;
  double jumpVelocity = -340.0;
  double wingFlapAngle = 0.0;
  double wingFlapSpeed = 0.0;
  double playerTilt = 0.0;

  // Camera properties
  late Vector3D cameraPos;
  double cameraFov = 260.0;
  double cameraShake = 0.0;

  // Entity Collections
  final List<Pillar3D> pillars = [];
  final List<Coin3D> coins = [];
  final List<ParallaxIsland> islands = [];
  final List<FlameParticle> particles = [];
  final List<GameFloatingText> floatingTexts = [];

  // State variables for generating terrain
  double nextPillarX = 400.0;
  final double pillarSpacing = 320.0;
  final math.Random random = math.Random();

  // Haptic feedback & sound toggle (visual toggle, sounds synthetic)
  bool isMuted = false;

  // Callbacks to UI
  VoidCallback? onStateChanged;

  FlappyJumpGame() {
    // Enable game-loop-based updates
    paused = false;
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();
    _resetGameEntities();
  }

  void _resetGameEntities() {
    score = 0;
    coinsEarned = 0;
    combo = 0;
    maxCombo = 0;
    gameSpeed = 220.0;
    targetSpeed = 220.0;
    elapsedSecs = 0.0;

    // Player starts at middle-left of the screen
    playerPos = Vector3D(-90.0, 0.0, 0.0);
    velocityY = 0.0;
    playerTilt = 0.0;

    // Camera center tracking
    cameraPos = Vector3D(0.0, 0.0, -250.0);
    cameraShake = 0.0;

    pillars.clear();
    coins.clear();
    islands.clear();
    particles.clear();
    floatingTexts.clear();

    nextPillarX = 300.0;

    // Generate background floating islands at multiple depths
    for (int i = 0; i < 7; i++) {
      islands.add(ParallaxIsland(
        x: (random.nextDouble() - 0.5) * 600 + (i * 200),
        y: random.nextDouble() * 200 - 150,
        z: random.nextDouble() * 400 + 300,
        size: random.nextDouble() * 40 + 35,
        color: random.nextBool()
            ? const Color(0xFF6E3AFF).withOpacity(0.18)
            : const Color(0xFFFF52A2).withOpacity(0.15),
      ));
    }

    // Pre-generate initial pillars
    for (int i = 0; i < 4; i++) {
      _spawnPillar();
    }
  }

  void _spawnPillar() {
    // Dynamic difficulty: gaps get smaller as score increases
    double minGap = 135.0;
    double maxGap = 180.0;
    double gapHeight = (maxGap - (score * 1.5)).clamp(minGap, maxGap);

    // Random height centered around middle screen
    double maxVerticalRange = 140.0;
    double gapCenterY = (random.nextDouble() - 0.5) * maxVerticalRange;

    pillars.add(Pillar3D(
      worldX: nextPillarX,
      gapCenterY: gapCenterY,
      gapHeight: gapHeight,
    ));

    // 60% chance to spawn a coin in the center of the gap
    if (random.nextDouble() < 0.6) {
      coins.add(Coin3D(
        worldX: nextPillarX,
        worldY: gapCenterY,
      ));
    }

    nextPillarX += pillarSpacing;
  }

  void startGame() {
    _resetGameEntities();
    hasStarted = true;
    isGameOver = false;
    paused = false;
    onStateChanged?.call();

    if (!isMuted) {
      HapticFeedback.mediumImpact();
    }
  }

  void resetGame() {
    startGame();
  }

  void pauseGame() {
    paused = true;
    onStateChanged?.call();
  }

  void resumeGame() {
    paused = false;
    onStateChanged?.call();
  }

  void jump() {
    if (!hasStarted) {
      startGame();
      return;
    }
    if (isGameOver || paused) return;

    velocityY = jumpVelocity;
    wingFlapSpeed = 12.0; // Trigger rapid flapping

    if (!isMuted) {
      HapticFeedback.lightImpact();
    }

    // Spawn jump puff particles behind player
    final screenPos = _projectPoint(playerPos);
    for (int i = 0; i < 4; i++) {
      final angle = math.pi + (random.nextDouble() - 0.5) * 1.0;
      final speed = random.nextDouble() * 60 + 30;
      particles.add(FlameParticle(
        x: screenPos.dx - 10,
        y: screenPos.dy + 5,
        vx: math.cos(angle) * speed - gameSpeed * 0.2,
        vy: math.sin(angle) * speed + 20,
        size: random.nextDouble() * 5 + 3,
        lifeTime: 0.4,
        color: const Color(0xFF8C62F8).withOpacity(0.6),
      ));
    }
  }

  void _triggerGameOver() {
    isGameOver = true;
    cameraShake = 15.0; // Big screen shake
    velocityY = 0.0; // Stop player immediately
    gameSpeed = 0.0; // Stop background speed immediately

    if (!isMuted) {
      HapticFeedback.vibrate();
    }

    // High scores and stats are tracked server-side via game_sessions/game_stats

    // Spawn explosion particles
    final screenPos = _projectPoint(playerPos);
    for (int i = 0; i < 20; i++) {
      final angle = random.nextDouble() * 2 * math.pi;
      final speed = random.nextDouble() * 220 + 80;
      particles.add(FlameParticle(
        x: screenPos.dx,
        y: screenPos.dy,
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed,
        size: random.nextDouble() * 8 + 4,
        lifeTime: 0.8,
        color: random.nextBool()
            ? const Color(0xFFFF52A2)
            : const Color(0xFFFFCC44),
      ));
    }

    onStateChanged?.call();
  }

  @override
  void update(double dt) {
    super.update(dt);
    elapsedSecs += dt;

    // Always update explosion particles and camera shake decay even if the game is over
    for (int i = particles.length - 1; i >= 0; i--) {
      final p = particles[i];
      p.age += dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      if (p.age >= p.lifeTime) {
        particles.removeAt(i);
      }
    }

    for (int i = floatingTexts.length - 1; i >= 0; i--) {
      final ft = floatingTexts[i];
      ft.age += dt;
      ft.y += ft.vy * dt;
      if (ft.age >= ft.lifeTime) {
        floatingTexts.removeAt(i);
      }
    }

    if (cameraShake > 0) {
      cameraShake -= dt * 35.0;
      if (cameraShake < 0) cameraShake = 0.0;
    }

    if (!hasStarted || isGameOver || paused) return;

    // 1. Difficulty progression
    targetSpeed = (220.0 + (score * 4.0)).clamp(220.0, maxSpeed);
    gameSpeed += (targetSpeed - gameSpeed) * 0.05;

    // 2. Physics of player
    velocityY += gravity * dt;
    playerPos.y += velocityY * dt;

    // Limit bounds - ceiling and floor collision
    double ceilingY = -280.0;
    double floorY = 280.0;
    if (playerPos.y - playerRadius < ceilingY) {
      playerPos.y = ceilingY + playerRadius;
      velocityY = 0.0;
    }
    if (playerPos.y + playerRadius > floorY) {
      playerPos.y = floorY -
          playerRadius; // Make sure the bird stops precisely at the floor!
      _triggerGameOver();
      return;
    }

    // Calculate player tilt based on velocity
    playerTilt = (velocityY * 0.0018).clamp(-0.4, 0.4);

    // Wing flapping
    if (wingFlapSpeed > 0) {
      wingFlapAngle = math.sin(elapsedSecs * 35) * 0.6;
      wingFlapSpeed -= dt * 10.0;
    } else {
      wingFlapAngle += (0.0 - wingFlapAngle) * 0.1;
    }

    // 3. Move obstacles & coins
    // Continuous Collision Detection & Score Check
    for (int i = pillars.length - 1; i >= 0; i--) {
      final pillar = pillars[i];
      pillar.worldX -= gameSpeed * dt;

      // Continuous Collision check
      double halfW = pillar.width / 2;
      bool horizontalHit =
          (playerPos.x + playerRadius > pillar.worldX - halfW) &&
              (playerPos.x - playerRadius < pillar.worldX + halfW);
      if (horizontalHit) {
        double gapHalfH = pillar.gapHeight / 2;
        bool verticalHit =
            (playerPos.y - playerRadius < pillar.gapCenterY - gapHalfH) ||
                (playerPos.y + playerRadius > pillar.gapCenterY + gapHalfH);
        if (verticalHit) {
          _triggerGameOver();
          return;
        }
      }

      // Check pass / score
      if (!pillar.passed && pillar.worldX < playerPos.x) {
        pillar.passed = true;

        // Success! Passed successfully
        score++;
        combo++;
        if (combo > maxCombo) maxCombo = combo;

        String multiplierMsg = "";
        Color scoreColor = Colors.white;

        if (combo >= 20) {
          multiplierMsg = "⚡ CRITICAL x3!";
          scoreColor = const Color(0xFFFFCC44);
          if (!isMuted) HapticFeedback.heavyImpact();
        } else if (combo >= 10) {
          multiplierMsg = "🔥 COMBO x2!";
          scoreColor = const Color(0xFF00FFCC);
          if (!isMuted) HapticFeedback.mediumImpact();
        } else {
          if (!isMuted) HapticFeedback.selectionClick();
        }

        coinsEarned = (score ~/ 2).clamp(0, 15); // max 15 base coins
        // Display floating texts
        final playerScreen = _projectPoint(playerPos);
        floatingTexts.add(GameFloatingText(
          x: playerScreen.dx + 20,
          y: playerScreen.dy - 20,
          vy: -120,
          text: "+1",
          color: Colors.white,
          fontSize: 22,
          lifeTime: 0.7,
        ));

        if (multiplierMsg.isNotEmpty) {
          floatingTexts.add(GameFloatingText(
            x: playerScreen.dx - 20,
            y: playerScreen.dy - 40,
            vy: -150,
            text: multiplierMsg,
            color: scoreColor,
            fontSize: 16,
            lifeTime: 1.0,
          ));
        }

        onStateChanged?.call();
      }

      // Delete old pillars
      if (pillar.worldX < -350.0) {
        pillars.removeAt(i);
        _spawnPillar();
      }
    }

    // 4. Update and check coin collections
    for (int i = coins.length - 1; i >= 0; i--) {
      final coin = coins[i];
      coin.worldX -= gameSpeed * dt;
      coin.rotY += dt * 3.2; // spin 3D coin

      // Check collision with player
      double dx = coin.worldX - playerPos.x;
      double dy = coin.worldY - playerPos.y;
      double dist = math.sqrt(dx * dx + dy * dy);

      if (!coin.collected && dist < playerRadius + 14.0) {
        coin.collected = true;
        score += 2; // Increases score too!
        coinsEarned = (score ~/ 2).clamp(0, 15); // max 15 base coins
        combo++;
        if (combo > maxCombo) maxCombo = combo;

        if (!isMuted) {
          HapticFeedback.lightImpact();
        }

        final screenPos =
            _projectPoint(Vector3D(coin.worldX, coin.worldY, 0.0));

        // Spawn shiny coins particles
        for (int k = 0; k < 8; k++) {
          final angle = random.nextDouble() * 2 * math.pi;
          final speed = random.nextDouble() * 120 + 60;
          particles.add(FlameParticle(
            x: screenPos.dx,
            y: screenPos.dy,
            vx: math.cos(angle) * speed - gameSpeed * 0.2,
            vy: math.sin(angle) * speed,
            size: random.nextDouble() * 5 + 3,
            lifeTime: 0.5,
            color: const Color(0xFFFFCC44),
            isStar: true,
          ));
        }

        // Floating coin text
        floatingTexts.add(GameFloatingText(
          x: screenPos.dx,
          y: screenPos.dy - 10,
          vy: -140,
          text: "+2 RBX",
          color: const Color(0xFFFFCC44),
          fontSize: 18,
          lifeTime: 0.8,
        ));

        coins.removeAt(i);
        onStateChanged?.call();
      } else if (coin.worldX < -300.0) {
        coins.removeAt(i);
      }
    }

    // 5. Parallax islands drifting scrolling
    for (final island in islands) {
      island.pos.x -= gameSpeed * dt;

      if (island.pos.x < -400.0) {
        island.pos.x = 600.0 + random.nextDouble() * 150.0;
        island.pos.y = random.nextDouble() * 200 - 150;
      }
    }

    // 9. Trail particles behind player
    if (random.nextDouble() < 0.35) {
      final pScreen = _projectPoint(playerPos);
      particles.add(FlameParticle(
        x: pScreen.dx - 12,
        y: pScreen.dy + (random.nextDouble() - 0.5) * 14.0,
        vx: -gameSpeed * 0.4 - random.nextDouble() * 30,
        vy: (random.nextDouble() - 0.5) * 20,
        size: random.nextDouble() * 5 + 2.5,
        lifeTime: 0.6,
        color: combo >= 20
            ? const Color(0xFFFFCC44)
            : (combo >= 10 ? const Color(0xFF00FFCC) : const Color(0xFF8C62F8)),
      ));
    }
  }

  // --- 3D Projection Math ---
  Offset _projectPoint(Vector3D point) {
    // Perspective projection formula
    final cx = size.x / 2;
    final cy = size.y / 2;

    // Transform coordinate relative to camera
    double rx = point.x - cameraPos.x;
    double ry = point.y - cameraPos.y;
    double rz = point.z - cameraPos.z;

    if (rz <= 0.1) rz = 0.1;

    final scale = cameraFov / rz;

    double screenX = cx + rx * scale;
    double screenY = cy + ry * scale;

    // Apply camera shake if any
    if (cameraShake > 0) {
      final shakeX = (random.nextDouble() - 0.5) * cameraShake;
      final shakeY = (random.nextDouble() - 0.5) * cameraShake;
      screenX += shakeX;
      screenY += shakeY;
    }

    return Offset(screenX, screenY);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    // 1. Draw beautiful Dark Synthwave background sky gradient
    final Rect backgroundRect = Rect.fromLTWH(0, 0, size.x, size.y);
    final Paint backgroundPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF0C0D26), // Deep Space Blue
          Color(0xFF19163D), // Synthwave Violet
          Color(0xFF331652), // Pinky Purple
        ],
      ).createShader(backgroundRect);
    canvas.drawRect(backgroundRect, backgroundPaint);

    // 2. Draw subtle 3D Grid floor and ceiling converging at a horizon
    _draw3DGrid(canvas);

    // 3. Render 3D Parallax Floating Islands (drawn behind obstacles)
    for (final island in islands) {
      _draw3DIsland(canvas, island);
    }

    // 4. Render 3D Obstacle Pillars
    for (final pillar in pillars) {
      _draw3DPillar(canvas, pillar);
    }

    // 5. Render 3D Coins
    for (final coin in coins) {
      _draw3DCoins(canvas, coin);
    }

    // 6. Draw Player (3D ball with gradients, visor, and wings)
    if (hasStarted) {
      _drawPlayer(canvas);
    }

    // 7. Render Particles
    for (final p in particles) {
      final paint = Paint()..color = p.color;
      if (p.isStar) {
        _drawStar(canvas, Offset(p.x, p.y), p.size, paint);
      } else {
        canvas.drawCircle(Offset(p.x, p.y), p.size, paint);
      }
    }

    // 8. Render Floating Texts
    for (final ft in floatingTexts) {
      final double opacity = (1.0 - (ft.age / ft.lifeTime)).clamp(0.0, 1.0);
      final textPainter = TextPainter(
        text: TextSpan(
          text: ft.text,
          style: GoogleFonts.outfit(
            fontSize: ft.fontSize,
            fontWeight: FontWeight.w900,
            color: ft.color.withOpacity(opacity),
            shadows: [
              Shadow(
                color: ft.color.withOpacity(0.5 * opacity),
                blurRadius: 10,
              ),
              const Shadow(
                color: Colors.black45,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas,
          Offset(ft.x - textPainter.width / 2, ft.y - textPainter.height / 2));
    }
  }

  void _draw3DGrid(Canvas canvas) {
    final gridPaint = Paint()
      ..color = const Color(0xFF6E3AFF).withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final cx = size.x / 2;
    final cy = size.y / 2;

    // Horizon line
    canvas.drawLine(Offset(0, cy), Offset(size.x, cy), gridPaint);

    // Perspective Grid floor
    double gridZSpeed = (elapsedSecs * gameSpeed * 0.4) % 100.0;

    // Draw horizontal grid lines in depth
    for (int zIndex = 0; zIndex < 10; zIndex++) {
      double z = 400.0 - zIndex * 40.0 - gridZSpeed;
      if (z <= 10.0) continue;

      final screenYFloor = cy + 180.0 * (cameraFov / z);
      final screenYCeil = cy - 180.0 * (cameraFov / z);

      canvas.drawLine(
          Offset(0, screenYFloor), Offset(size.x, screenYFloor), gridPaint);
      canvas.drawLine(
          Offset(0, screenYCeil), Offset(size.x, screenYCeil), gridPaint);
    }

    // Draw vanishing lines
    for (int i = -6; i <= 6; i++) {
      double xOffset = i * 80.0;
      // Line on the floor
      final start = Offset(cx + xOffset * 0.1, cy);
      final end = Offset(cx + xOffset * 5.0, size.y);
      canvas.drawLine(start, end, gridPaint);

      // Line on the ceiling
      final startCeil = Offset(cx + xOffset * 0.1, cy);
      final endCeil = Offset(cx + xOffset * 5.0, 0);
      canvas.drawLine(startCeil, endCeil, gridPaint);
    }
  }

  void _draw3DIsland(Canvas canvas, ParallaxIsland island) {
    // Project base position
    final projBase = _projectPoint(island.pos);

    // Compute vertices coordinates and project them
    List<Offset> projVerts = [];
    for (final v in island.vertices) {
      final worldV =
          Vector3D(island.pos.x + v.x, island.pos.y + v.y, island.pos.z + v.z);
      projVerts.add(_projectPoint(worldV));
    }

    // Check if the island is inside screen boundaries
    if (projBase.dx < -150 || projBase.dx > size.x + 150) return;

    final fillPaint = Paint()
      ..color = island.color
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = island.color.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw crystalline floating rock faces
    // Face 1: Front top
    final path1 = Path()
      ..moveTo(projVerts[0].dx, projVerts[0].dy)
      ..lineTo(projVerts[1].dx, projVerts[1].dy)
      ..lineTo(projVerts[2].dx, projVerts[2].dy)
      ..lineTo(projVerts[3].dx, projVerts[3].dy)
      ..close();
    canvas.drawPath(path1, fillPaint);
    canvas.drawPath(path1, strokePaint);

    // Face 2: Left bottom slope
    final path2 = Path()
      ..moveTo(projVerts[0].dx, projVerts[0].dy)
      ..lineTo(projVerts[3].dx, projVerts[3].dy)
      ..lineTo(projVerts[4].dx, projVerts[4].dy)
      ..close();
    canvas.drawPath(path2, fillPaint);
    canvas.drawPath(path2, strokePaint);

    // Face 3: Right bottom slope
    final path3 = Path()
      ..moveTo(projVerts[1].dx, projVerts[1].dy)
      ..lineTo(projVerts[2].dx, projVerts[2].dy)
      ..lineTo(projVerts[4].dx, projVerts[4].dy)
      ..close();
    canvas.drawPath(path3, fillPaint);
    canvas.drawPath(path3, strokePaint);
  }

  void _draw3DPillar(Canvas canvas, Pillar3D pillar) {
    // Generate 3D Box for Upper Pillar (from ceiling to gapTop)
    double gapHalf = pillar.gapHeight / 2;
    double ceilingY = -280.0;
    double floorY = 280.0;

    _draw3DBox(
      canvas,
      x: pillar.worldX,
      yStart: ceilingY,
      yEnd: pillar.gapCenterY - gapHalf,
      w: pillar.width,
      d: pillar.depth,
      isTopPillar: true,
    );

    // Generate 3D Box for Lower Pillar (from gapBottom to floor)
    _draw3DBox(
      canvas,
      x: pillar.worldX,
      yStart: pillar.gapCenterY + gapHalf,
      yEnd: floorY,
      w: pillar.width,
      d: pillar.depth,
      isTopPillar: false,
    );
  }

  void _draw3DBox(
    Canvas canvas, {
    required double x,
    required double yStart,
    required double yEnd,
    required double w,
    required double d,
    required bool isTopPillar,
  }) {
    // Define 8 vertices of the 3D pillar box
    List<Vector3D> verts = [
      Vector3D(x - w / 2, yStart, -d / 2), // 0: top-left-front
      Vector3D(x + w / 2, yStart, -d / 2), // 1: top-right-front
      Vector3D(x + w / 2, yEnd, -d / 2), // 2: bot-right-front
      Vector3D(x - w / 2, yEnd, -d / 2), // 3: bot-left-front

      Vector3D(x - w / 2, yStart, d / 2), // 4: top-left-back
      Vector3D(x + w / 2, yStart, d / 2), // 5: top-right-back
      Vector3D(x + w / 2, yEnd, d / 2), // 6: bot-right-back
      Vector3D(x - w / 2, yEnd, d / 2), // 7: bot-left-back
    ];

    // Project all 8 vertices
    List<Offset> proj = verts.map((v) => _projectPoint(v)).toList();

    // Backface culling / screen boundary checks
    bool anyOnScreen = proj.any((pt) => pt.dx >= -100 && pt.dx <= size.x + 100);
    if (!anyOnScreen) return;

    // Colors & Shader Design
    // Neon glow styles
    const neonMagenta = Color(0xFFFF007F);
    const neonPurple = Color(0xFF6E3AFF);
    const neonDark = Color(0xFF1D0E3D);
    const neonCyan = Color(0xFF00FFCC);

    final frontPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [neonPurple, neonMagenta],
      ).createShader(Rect.fromPoints(proj[0], proj[2]));

    final sidePaint = Paint()
      ..color = const Color(0xFF26105E).withOpacity(0.95)
      ..style = PaintingStyle.fill;

    final energyFacePaint = Paint()
      ..shader = const RadialGradient(
        colors: [neonCyan, neonPurple],
      ).createShader(Rect.fromPoints(proj[3], proj[6]));

    final borderPaint = Paint()
      ..color = neonCyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final energyBorderPaint = Paint()
      ..color = neonCyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Determine perspective side visibility relative to camera center
    double pillarCameraDeltaX =
        x - playerPos.x; // We are tracking player horizontal position
    bool showRightFace =
        pillarCameraDeltaX < 0; // If behind us, show right face
    bool showLeftFace = pillarCameraDeltaX > 0; // If in front, show left face

    // 1. Draw side faces
    if (showLeftFace) {
      // Left side face [4, 0, 3, 7]
      final pathLeft = Path()
        ..moveTo(proj[4].dx, proj[4].dy)
        ..lineTo(proj[0].dx, proj[0].dy)
        ..lineTo(proj[3].dx, proj[3].dy)
        ..lineTo(proj[7].dx, proj[7].dy)
        ..close();
      canvas.drawPath(pathLeft, sidePaint);
      canvas.drawPath(pathLeft, borderPaint);
    } else if (showRightFace) {
      // Right side face [1, 5, 6, 2]
      final pathRight = Path()
        ..moveTo(proj[1].dx, proj[1].dy)
        ..lineTo(proj[5].dx, proj[5].dy)
        ..lineTo(proj[6].dx, proj[6].dy)
        ..lineTo(proj[2].dx, proj[2].dy)
        ..close();
      canvas.drawPath(pathRight, sidePaint);
      canvas.drawPath(pathRight, borderPaint);
    }

    // 2. Draw top or bottom face (the cap facing the gap)
    if (isTopPillar) {
      // Bottom face cap [3, 2, 6, 7] - faces the gap, drawn glowing neon
      final pathCap = Path()
        ..moveTo(proj[3].dx, proj[3].dy)
        ..lineTo(proj[2].dx, proj[2].dy)
        ..lineTo(proj[6].dx, proj[6].dy)
        ..lineTo(proj[7].dx, proj[7].dy)
        ..close();
      canvas.drawPath(pathCap, energyFacePaint);
      canvas.drawPath(pathCap, energyBorderPaint);
    } else {
      // Top face cap [4, 5, 1, 0] - faces the gap, drawn glowing neon
      final pathCap = Path()
        ..moveTo(proj[4].dx, proj[4].dy)
        ..lineTo(proj[5].dx, proj[5].dy)
        ..lineTo(proj[1].dx, proj[1].dy)
        ..lineTo(proj[0].dx, proj[0].dy)
        ..close();
      canvas.drawPath(pathCap, energyFacePaint);
      canvas.drawPath(pathCap, energyBorderPaint);
    }

    // 3. Draw main front face [0, 1, 2, 3]
    final pathFront = Path()
      ..moveTo(proj[0].dx, proj[0].dy)
      ..lineTo(proj[1].dx, proj[1].dy)
      ..lineTo(proj[2].dx, proj[2].dy)
      ..lineTo(proj[3].dx, proj[3].dy)
      ..close();
    canvas.drawPath(pathFront, frontPaint);
    canvas.drawPath(pathFront, borderPaint);
  }

  void _draw3DCoins(Canvas canvas, Coin3D coin) {
    // Draw spinning gold coins in 3D perspective projection
    double radius = 13.0;

    // Create base vertices for flat hexagon
    List<Vector3D> verts = [];
    for (int i = 0; i < 6; i++) {
      double angle = i * math.pi / 3;
      verts.add(
          Vector3D(math.cos(angle) * radius, math.sin(angle) * radius, 0.0));
    }

    // Rotate coin vertices around local Y axis (rotY)
    List<Vector3D> rotatedVerts = [];
    for (var v in verts) {
      double rotX = v.x * math.cos(coin.rotY);
      double rotZ = v.x * math.sin(coin.rotY);
      rotatedVerts.add(Vector3D(coin.worldX + rotX, coin.worldY + v.y, rotZ));
    }

    // Project vertices
    List<Offset> proj = rotatedVerts.map((v) => _projectPoint(v)).toList();

    // If fully off-screen, skip
    bool anyOnScreen = proj.any((pt) => pt.dx >= -20 && pt.dx <= size.x + 20);
    if (!anyOnScreen) return;

    // Render gold faces and neon outline
    const goldTop = Color(0xFFFFDE6B);
    const goldBase = Color(0xFFF5C842);
    const neonCyan = Color(0xFF00FFCC);

    final path = Path()..moveTo(proj[0].dx, proj[0].dy);
    for (int i = 1; i < proj.length; i++) {
      path.lineTo(proj[i].dx, proj[i].dy);
    }
    path.close();

    final goldPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [goldTop, goldBase],
      ).createShader(Rect.fromPoints(proj[0], proj[3]));

    final strokePaint = Paint()
      ..color = const Color(0xFFFF9E00)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final outerGlow = Paint()
      ..color = neonCyan.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    // Draw
    canvas.drawPath(path, outerGlow);
    canvas.drawPath(path, goldPaint);
    canvas.drawPath(path, strokePaint);

    // Inner small square hole
    List<Vector3D> holeVerts = [];
    double innerRad = radius * 0.35;
    for (int i = 0; i < 4; i++) {
      double angle = i * math.pi / 2 + math.pi / 4;
      holeVerts.add(Vector3D(
          math.cos(angle) * innerRad, math.sin(angle) * innerRad, 0.0));
    }

    List<Offset> projHole = holeVerts.map((v) {
      double rx = v.x * math.cos(coin.rotY);
      double rz = v.x * math.sin(coin.rotY);
      return _projectPoint(Vector3D(coin.worldX + rx, coin.worldY + v.y, rz));
    }).toList();

    final holePath = Path()..moveTo(projHole[0].dx, projHole[0].dy);
    for (int i = 1; i < projHole.length; i++) {
      holePath.lineTo(projHole[i].dx, projHole[i].dy);
    }
    holePath.close();

    canvas.drawPath(holePath, Paint()..color = const Color(0xFFC48B02));
  }

  void _drawPlayer(Canvas canvas) {
    // Project player position
    final center = _projectPoint(playerPos);

    // Draw 3D shadow on floor
    final shadowZPos = Vector3D(playerPos.x, 260.0, 0.0);
    final shadowCenter = _projectPoint(shadowZPos);
    double shadowSize = playerRadius * (cameraFov / (0.0 - cameraPos.z)) * 0.9;

    canvas.drawOval(
      Rect.fromCenter(
        center: shadowCenter,
        width: shadowSize * 1.5,
        height: shadowSize * 0.3,
      ),
      Paint()..color = Colors.black.withOpacity(0.35),
    );

    // Save state to rotate visor/wings
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(playerTilt); // Tilt player based on gravity direction

    // Wing flapping offsets
    double flap = wingFlapAngle;

    // Draw Left and Right Wings
    final wingPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF00FFCC), Color(0xFF6E3AFF)],
      ).createShader(const Rect.fromLTWH(-35, -20, 70, 40));

    final wingStroke = Paint()
      ..color = const Color(0xFF00FFCC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Left Wing
    canvas.save();
    canvas.translate(-playerRadius * 0.8, -playerRadius * 0.2);
    canvas.rotate(-flap - 0.2);
    final leftWingPath = Path()
      ..moveTo(0, 0)
      ..cubicTo(-24, -12, -26, 4, -4, 8)
      ..close();
    canvas.drawPath(leftWingPath, wingPaint);
    canvas.drawPath(leftWingPath, wingStroke);
    canvas.restore();

    // Right Wing
    canvas.save();
    canvas.translate(playerRadius * 0.8, -playerRadius * 0.2);
    canvas.rotate(flap + 0.2);
    final rightWingPath = Path()
      ..moveTo(0, 0)
      ..cubicTo(24, -12, 26, 4, 4, 8)
      ..close();
    canvas.drawPath(rightWingPath, wingPaint);
    canvas.drawPath(rightWingPath, wingStroke);
    canvas.restore();

    // Draw Robot Main Body Sphere (radial gradient for 3D look)
    final bodyPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        colors: [
          isGameOver ? const Color(0xFFFF52A2) : const Color(0xFF8C62F8),
          isGameOver ? const Color(0xFF990E49) : const Color(0xFF4C1D95),
        ],
      ).createShader(
          Rect.fromCircle(center: Offset.zero, radius: playerRadius));

    final bodyOutline = Paint()
      ..color = isGameOver ? const Color(0xFFFF007F) : const Color(0xFF00FFCC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final neonGlow = Paint()
      ..color = isGameOver
          ? const Color(0xFFFF007F).withOpacity(0.4)
          : const Color(0xFF00FFCC).withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);

    canvas.drawCircle(Offset.zero, playerRadius, neonGlow);
    canvas.drawCircle(Offset.zero, playerRadius, bodyPaint);
    canvas.drawCircle(Offset.zero, playerRadius, bodyOutline);

    // Draw Cute Robot Visor Face
    final visorPaint = Paint()
      ..color = const Color(0xFF0B0A1A)
      ..style = PaintingStyle.fill;

    final visorOutline = Paint()
      ..color = const Color(0xFF00FFCC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final visorRect = Rect.fromCenter(
      center: const Offset(5.0, -1.0),
      width: playerRadius * 1.1,
      height: playerRadius * 0.55,
    );
    canvas.drawRRect(
        RRect.fromRectAndRadius(visorRect, const Radius.circular(5)),
        visorPaint);
    canvas.drawRRect(
        RRect.fromRectAndRadius(visorRect, const Radius.circular(5)),
        visorOutline);

    // Eyes: Smiley, shocked, or dizzy depending on state
    final eyePaint = Paint()
      ..color = const Color(0xFF00FFCC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    if (isGameOver) {
      // Dizzy cross eyes 'XX'
      canvas.drawLine(const Offset(1, -3), const Offset(4, -1), eyePaint);
      canvas.drawLine(const Offset(4, -3), const Offset(1, -1), eyePaint);

      canvas.drawLine(const Offset(7, -3), const Offset(10, -1), eyePaint);
      canvas.drawLine(const Offset(10, -3), const Offset(7, -1), eyePaint);
    } else if (velocityY < -150) {
      // Shocked eyes (O_O)
      canvas.drawCircle(
          const Offset(3.5, -2), 1.8, Paint()..color = const Color(0xFF00FFCC));
      canvas.drawCircle(
          const Offset(7.5, -2), 1.8, Paint()..color = const Color(0xFF00FFCC));
    } else {
      // Happy smiley curves (^^)
      final eyePath1 = Path()
        ..moveTo(2, -1)
        ..quadraticBezierTo(3.5, -3.5, 5, -1);
      final eyePath2 = Path()
        ..moveTo(6, -1)
        ..quadraticBezierTo(7.5, -3.5, 9, -1);
      canvas.drawPath(eyePath1, eyePaint);
      canvas.drawPath(eyePath2, eyePaint);
    }

    // Floating bunny-like antenna/ears
    canvas.restore();
  }

  void _drawStar(Canvas canvas, Offset offset, double size, Paint paint) {
    final path = Path();
    final double innerRadius = size * 0.4;

    for (int i = 0; i < 10; i++) {
      double r = (i % 2 == 0) ? size : innerRadius;
      double angle = i * math.pi / 5 - math.pi / 2;
      double x = offset.dx + math.cos(angle) * r;
      double y = offset.dy + math.sin(angle) * r;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }
}

// --- Main Flutter Game Screen ---
class FlappyJumpGameScreen extends ConsumerStatefulWidget {
  const FlappyJumpGameScreen({super.key});

  @override
  ConsumerState<FlappyJumpGameScreen> createState() => _FlappyJumpGameScreenState();
}

class _FlappyJumpGameScreenState extends ConsumerState<FlappyJumpGameScreen>
    with SingleTickerProviderStateMixin {
  late FlappyJumpGame _game;

  // Game data state
  int _coins = 0;
  int _displayedCoins = 0;
  final int _highScore = 0;
  String? _sessionId;
  DateTime? _gameStartTime;

  // Confetti / Coin claim animation state
  bool _showCoinClaimAnimation = false;
  bool _hasClaimedReward = false;
  bool _adWatched = false;
  bool _handledGameOver = false;
  int _originalCoinsEarned = 0;
  late AnimationController _claimAnimController;
  final List<_GameClaimCoin> _flyingCoins = [];
  final math.Random _random = math.Random();
  static int _claimCount = 0;

  @override
  void initState() {
    super.initState();

    _game = FlappyJumpGame();
    _game.onStateChanged = () async {
      if (_game.isGameOver && !_handledGameOver && mounted) {
        _handledGameOver = true;
        _claimCount++;
        if (_claimCount % 3 == 0) {
          await ref.read(adProvider.notifier).showInterstitialAfterClaim(AdPlacement.dailyReward);
        }
      }
      if (mounted) setState(() {});
    };

    _loadLocalData();

    // Setup coin flight claim animation
    _claimAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )
      ..addListener(() {
        _updateFlyingCoins();
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() {
            _showCoinClaimAnimation = false;
            _displayedCoins = _coins;
          });
        }
      });
  }

  Future<void> _loadLocalData() async {
    final currentCoins = ref.read(coinProvider);
    setState(() {
      _coins = currentCoins;
      _displayedCoins = currentCoins;
    });
  }

  @override
  void dispose() {
    _claimAnimController.dispose();
    super.dispose();
  }

  void _triggerClaimCoins() async {
    if (_hasClaimedReward ||
        _showCoinClaimAnimation ||
        _game.coinsEarned <= 0) {
      return;
    }

    _showCoinClaimAnimation = true;

    final currentCoins = ref.read(coinProvider);
    final duration = _gameStartTime != null
        ? DateTime.now().difference(_gameStartTime!).inSeconds
        : 1;

    final finalScore = _originalCoinsEarned > 0
        ? _originalCoinsEarned * (_adWatched ? 2 : 1)
        : _game.coinsEarned;

    try {
      final result = await ref.read(gameServiceProvider).submitGameResult(
        gameName: 'flappy_jump',
        score: finalScore,
        durationSeconds: duration.clamp(1, 3600),
        sessionId: _sessionId ?? ref.read(gameServiceProvider).generateSessionId(),
        originalScore:
            _originalCoinsEarned > 0 ? _originalCoinsEarned : _game.coinsEarned,
        multiplier: _adWatched ? 2 : 1,
      );
      if (!mounted) return;
      if (result.success || result.queued) {
        final earned = result.coinsEarned > 0 ? result.coinsEarned : finalScore;
        ref.read(coinProvider.notifier).updateBalance(ref.read(coinProvider) + earned);
      } else {
        setState(() {
          _showCoinClaimAnimation = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.error ?? 'Failed to save game reward',
            ),
          ),
        );
        return;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _showCoinClaimAnimation = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save game reward')),
      );
      debugPrint('Failed to submit game result: $e');
      return;
    }

    if (!mounted) {
      return;
    }

    _prepareFlyingCoins();

    final newTotal = currentCoins + _game.coinsEarned;

    setState(() {
      _coins = newTotal;
      _displayedCoins = currentCoins;
      _hasClaimedReward = true;
    });

    if (!_game.isMuted) {
      HapticFeedback.mediumImpact();
    }

    _claimAnimController.forward(from: 0);
  }

  void _prepareFlyingCoins() {
    final size = MediaQuery.of(context).size;
    final start = Offset(size.width / 2, size.height / 2 + 150);
    final end = Offset(size.width / 2 + 110, size.height / 2 - 8);
    final coinCount = _game.coinsEarned.clamp(6, 16).toInt();

    _flyingCoins.clear();
    for (int i = 0; i < coinCount; i++) {
      final spreadX = (_random.nextDouble() - 0.5) * 120;
      final spreadY = (_random.nextDouble() - 0.5) * 40;
      final control = Offset(
        size.width / 2 + spreadX,
        size.height / 2 - 150 + spreadY,
      );
      _flyingCoins.add(_GameClaimCoin(
        start: Offset(
          start.dx + (_random.nextDouble() - 0.5) * 80,
          start.dy + (_random.nextDouble() - 0.5) * 24,
        ),
        end: Offset(
          end.dx + (_random.nextDouble() - 0.5) * 24,
          end.dy + (_random.nextDouble() - 0.5) * 18,
        ),
        control: control,
        delay: i * 0.025,
      ));
    }
  }

  void _startGame() {
    _sessionId = ref.read(gameServiceProvider).generateSessionId();
    _gameStartTime = DateTime.now();
    _game.startGame();
  }

  void _playAgainFromGameOver() {
    _claimAnimController.reset();
    _flyingCoins.clear();
    setState(() {
      _showCoinClaimAnimation = false;
      _hasClaimedReward = false;
      _adWatched = false;
      _handledGameOver = false;
      _originalCoinsEarned = 0;
      _displayedCoins = _coins;
    });
    _startGame();
  }

  void _updateFlyingCoins() {
    if (!mounted) return;

    final dt = _claimAnimController.value;
    setState(() {
      if (_showCoinClaimAnimation) {
        final eased = Curves.easeOutCubic.transform(dt);
        _displayedCoins =
            (_coins - (_game.coinsEarned * (1.0 - eased))).round();
      }

      for (var coin in _flyingCoins) {
        if (dt > coin.delay) {
          // Bezier curve progress
          double t = (dt - coin.delay) * 2.0; // speed up individual travel
          if (t > 1.0) t = 1.0;

          double mt = 1.0 - t;

          // Quadratic Bezier Formula
          coin.currentX = mt * mt * coin.start.dx +
              2 * mt * t * coin.control.dx +
              t * t * coin.end.dx;
          coin.currentY = mt * mt * coin.start.dy +
              2 * mt * t * coin.control.dy +
              t * t * coin.end.dy;
          coin.progress = t;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _game.hasStarted && !_game.isGameOver;
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
        backgroundColor: const Color(0xFF0C0D26),
        body: Stack(
          children: [
            // 1. Interactive Flame Game Widget with custom Tap detection
            GestureDetector(
              onTap: _game.jump,
              behavior: HitTestBehavior.opaque,
              child: GameWidget(game: _game),
            ),

            // 2. HUD Game overlay (always visible once playing)
            if (_game.hasStarted && !_game.isGameOver) _buildHudOverlay(),

            // 3. Menu overlay (shown before game starts)
            if (!_game.hasStarted) _buildMenuOverlay(),

            // 4. Pause screen overlay
            if (_game.paused) _buildPauseOverlay(),

            // 5. Game Over screen overlay
            if (_game.isGameOver) _buildGameOverOverlay(),

            // 6. Flying Coins Claim animation layer
            if (_showCoinClaimAnimation)
              IgnorePointer(
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _GameCoinClaimPainter(_flyingCoins),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --- HUD Overlay Screen ---
  Widget _buildHudOverlay() {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + 10,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Pause Button
          GestureDetector(
            onTap: _game.pauseGame,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: const Icon(Icons.pause, color: Colors.white, size: 22),
            ),
          ),

          // Center: Active Score
          Column(
            children: [
              Text(
                'SCORE',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white60,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                '${_game.score}',
                style: GoogleFonts.outfit(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  shadows: [
                    const Shadow(
                      color: Color(0xFF00FFCC),
                      blurRadius: 15,
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Right: Active Coins
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              children: [
                Image.asset(
                  AppAssets.goldRbxCoin,
                  width: 18,
                  height: 18,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.monetization_on,
                    color: Color(0xFFFFCC44),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${_game.coinsEarned}',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFFFCC44),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Menu Overlay Screen ---
  Widget _buildMenuOverlay() {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black.withOpacity(0.4),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () async {
                      final shouldLeave = await showQuitConfirmationDialog(
                        context,
                        title: 'Quit Game?',
                        message: 'Are you sure you want to go back?',
                      );
                      if (shouldLeave && context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),

                  // Coins counter
                  Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      children: [
                        Image.asset(
                          AppAssets.goldRbxCoin,
                          width: 20,
                          height: 20,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.monetization_on,
                            color: Color(0xFFFFCC44),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$_coins',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(flex: 2),

            // Title (Cool Neon Glowing Title)
            Column(
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF00FFCC), Color(0xFFFF52A2)],
                  ).createShader(bounds),
                  child: Text(
                    'FLAPPY JUMP',
                    style: GoogleFonts.outfit(
                      fontSize: 46,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -1,
                    ),
                  ),
                ),
                Text(
                  '3D HYPERCASUAL ACTION',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF8C62F8),
                    letterSpacing: 3,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Animated Character preview placeholder representation
            Container(
              height: 110,
              width: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6E3AFF).withOpacity(0.2),
                border: Border.all(
                    color: const Color(0xFF00FFCC).withOpacity(0.4), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6E3AFF).withOpacity(0.3),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Spinning outer ring
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFF52A2).withOpacity(0.5),
                        width: 1.5,
                        style: BorderStyle.solid,
                      ),
                    ),
                  ),
                  // The player character representation
                  const Icon(Icons.rocket_launch,
                      color: Color(0xFF00FFCC), size: 44),
                ],
              ),
            ),

            const Spacer(flex: 2),

            // Stats (High Score display)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.emoji_events,
                      color: Color(0xFFFFCC44), size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'BEST SCORE: ',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white60,
                    ),
                  ),
                  Text(
                    '$_highScore',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Play Button
            GestureDetector(
              onTap: _startGame,
              child: Container(
                width: double.infinity,
                height: 58,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8C62F8), Color(0xFF6035EE)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6035EE).withOpacity(0.5),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                  border: Border.all(color: Colors.white30),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.play_arrow,
                          color: Colors.white, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'TAP TO PLAY',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // --- Pause Screen Overlay ---
  Widget _buildPauseOverlay() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black.withOpacity(0.65),
      child: Center(
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF19163D),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: const Color(0xFF6E3AFF).withOpacity(0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6E3AFF).withOpacity(0.2),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'PAUSED',
                style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 32),

              // Resume Button
              _buildPauseActionBtn(
                onTap: _game.resumeGame,
                text: 'RESUME GAME',
                isPrimary: true,
                icon: Icons.play_arrow,
              ),
              const SizedBox(height: 12),

              // Restart Button
              _buildPauseActionBtn(
                onTap: _startGame,
                text: 'RESTART',
                isPrimary: false,
                icon: Icons.refresh,
              ),
              const SizedBox(height: 12),

              // Exit Button
              _buildPauseActionBtn(
                onTap: () async {
                  final shouldLeave = await showQuitConfirmationDialog(
                    context,
                    title: 'Quit Game?',
                    message:
                        'Are you sure you want to exit? You will lose unclaimed progress.',
                  );
                  if (shouldLeave && context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                text: 'QUIT',
                isPrimary: false,
                icon: Icons.exit_to_app,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPauseActionBtn({
    required VoidCallback onTap,
    required String text,
    required bool isPrimary,
    required IconData icon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          gradient: isPrimary
              ? const LinearGradient(
                  colors: [Color(0xFF8C62F8), Color(0xFF6035EE)])
              : null,
          color: isPrimary ? null : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isPrimary ? Colors.white30 : Colors.white12,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              text,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Game Over Overlay Screen ---
  Widget _buildGameOverOverlay() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black.withOpacity(0.7),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Game Over header
            Text(
              'GAME OVER',
              style: GoogleFonts.outfit(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                color: const Color(0xFFFF52A2),
                letterSpacing: -0.5,
                shadows: [
                  const Shadow(
                    color: Color(0xFFFF52A2),
                    blurRadius: 15,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Stats Panel
            Container(
              width: 320,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF19163D),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: const Color(0xFFFF52A2).withOpacity(0.4),
                    width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF52A2).withOpacity(0.15),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Score Row
                  _buildStatRow(
                      'SCORE', '${_game.score}', const Color(0xFF00FFCC)),
                  const Divider(color: Colors.white12, height: 24),

                  _buildCoinStatRow('RBX BALANCE', _displayedCoins,
                      highlight: _showCoinClaimAnimation),
                  const Divider(color: Colors.white12, height: 24),

                  // Max Combo Row
                  _buildStatRow('MAX COMBO', 'x${_game.maxCombo}',
                      const Color(0xFF8C62F8)),
                  const Divider(color: Colors.white12, height: 24),

                  // Coins Earned
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'EARNED',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white60,
                        ),
                      ),
                      Row(
                        children: [
                          Image.asset(
                            AppAssets.goldRbxCoin,
                            width: 22,
                            height: 22,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.monetization_on,
                              color: Color(0xFFFFCC44),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '+${_game.coinsEarned} RBX',
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFFFFCC44),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Buttons Row
            if (!_showCoinClaimAnimation)
              SizedBox(
                width: 320,
                child: Column(
                  children: [
                    // Watch Ad for 2x (shown before claiming)
                    if (_game.coinsEarned > 0 &&
                        !_hasClaimedReward &&
                        !_adWatched &&
                        ref.watch(adProvider.notifier).canShowOptionalAd)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GestureDetector(
                          onTap: () async {
                            final adNotifier = ref.read(adProvider.notifier);
                            await adNotifier.showInterstitialAfterClaim(AdPlacement.dailyReward);
                            adNotifier.recordOptionalAdWatched();
                            if (!mounted) return;
                            setState(() {
                              _originalCoinsEarned = _game.coinsEarned;
                              _game.coinsEarned = (_game.coinsEarned * 2).clamp(0, 30); // 2x capped at 30
                              _adWatched = true;
                            });
                          },
                          child: Container(
                            width: double.infinity,
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF8C00), Color(0xFFFF8C00)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xFFFFCC44).withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.play_circle,
                                      color: Colors.white, size: 20),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Watch Ad for 2x Coins',
                                    style: GoogleFonts.outfit(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Claim button (Always first if earned > 0)
                    if (_game.coinsEarned > 0 && !_hasClaimedReward)
                      GestureDetector(
                        onTap: _triggerClaimCoins,
                        child: Container(
                          width: double.infinity,
                          height: 54,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFCC44), Color(0xFFFFCC44)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF9E00).withOpacity(0.4),
                                blurRadius: 15,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            border: Border.all(color: Colors.white30),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.bolt,
                                    color: Color(0xFF0F172A), size: 20),
                                const SizedBox(width: 6),
                                Text(
                                  'CLAIM REWARD',
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF0F172A),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (_game.coinsEarned > 0 && _hasClaimedReward)
                      Container(
                        width: double.infinity,
                        height: 54,
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF00FFCC).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color:
                                const Color(0xFF00FFCC).withValues(alpha: 0.45),
                          ),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle,
                                  color: Color(0xFF00FFCC), size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'REWARD CLAIMED',
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF00FFCC),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        // Play Again
                        Expanded(
                          child: GestureDetector(
                            onTap: _playAgainFromGameOver,
                            child: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                color: const Color(0xFF6E3AFF),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Center(
                                child: Text(
                                  'PLAY AGAIN',
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Quit Button
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.of(context).pop(
                                _hasClaimedReward ? _game.coinsEarned : null),
                            child: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Center(
                                child: Text(
                                  'QUIT',
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white70,
                                  ),
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
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white60,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildCoinStatRow(String label, int value, {bool highlight = false}) {
    final pulse = highlight
        ? 1.0 + math.sin(_claimAnimController.value * math.pi) * 0.08
        : 1.0;

    return Transform.scale(
      scale: pulse,
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white60,
            ),
          ),
          Row(
            children: [
              Image.asset(
                AppAssets.goldRbxCoin,
                width: 22,
                height: 22,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.monetization_on,
                  color: Color(0xFFFFCC44),
                  size: 22,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$value RBX',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFFFCC44),
                  shadows: highlight
                      ? [
                          const Shadow(
                            color: Color(0xFFFFCC44),
                            blurRadius: 12,
                          ),
                        ]
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- Bezier Claim Coin ---
class _GameClaimCoin {
  final Offset start;
  final Offset end;
  final Offset control;
  final double delay;
  double currentX = 0.0;
  double currentY = 0.0;
  double progress = 0.0;

  _GameClaimCoin({
    required this.start,
    required this.end,
    required this.control,
    required this.delay,
  });
}

// --- Claim Coin custom Painter ---
class _GameCoinClaimPainter extends CustomPainter {
  final List<_GameClaimCoin> coins;
  _GameCoinClaimPainter(this.coins);

  @override
  void paint(Canvas canvas, Size size) {
    const goldTop = Color(0xFFFFDE6B);
    const goldBase = Color(0xFFF5C842);
    const goldStroke = Color(0xFFFF9E00);

    for (var coin in coins) {
      if (coin.progress <= 0.0 || coin.progress >= 1.0) continue;

      canvas.save();
      canvas.translate(coin.currentX, coin.currentY);

      // Spinning scale rotation illusion
      double scaleX = math.cos(coin.progress * 10 * math.pi);
      canvas.scale(scaleX.abs(), 1.0);

      const double coinRad = 16.0;
      final path = Path()
        ..addOval(Rect.fromCircle(center: Offset.zero, radius: coinRad));

      final paint = Paint()
        ..shader = const LinearGradient(
          colors: [goldTop, goldBase],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: coinRad));

      canvas.drawPath(path, paint);
      canvas.drawPath(
        path,
        Paint()
          ..color = goldStroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );

      // Core 'R' or Star shape inside the flying coin
      canvas.drawCircle(
          Offset.zero, coinRad * 0.4, Paint()..color = const Color(0xFFC48B02));

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
