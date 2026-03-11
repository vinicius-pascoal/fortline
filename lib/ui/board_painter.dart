import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/colors.dart';
import '../core/models.dart';
import '../core/effects.dart';
import '../core/maps.dart';

class BoardPainter extends CustomPainter {
  final MapDef map;
  final List<GridTower> towers;
  final List<Enemy> enemies;
  final List<Projectile> projectiles;
  final List<Particle> particles;
  final List<ImpactFlash> flashes;
  final List<LaserBeam> lasers;
  final PathData pathData;
  final int? pendingRow;
  final int? pendingCol;
  final double animTime; // increases each frame for shimmer etc.

  const BoardPainter({
    required this.map,
    required this.towers,
    required this.enemies,
    required this.projectiles,
    required this.particles,
    required this.flashes,
    required this.lasers,
    required this.pathData,
    this.pendingRow,
    this.pendingCol,
    this.animTime = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cw = size.width / map.cols;
    final ch = size.height / map.rows;

    _drawBackground(canvas, size);
    _drawPath(canvas, cw, ch);
    _drawGrid(canvas, size, cw, ch);
    _drawPendingCell(canvas, cw, ch);
    drawParticles(canvas, particles, cw, ch);
    drawFlashes(canvas, flashes, cw, ch);
    drawLasers(canvas, lasers, cw, ch);
    _drawTowers(canvas, cw, ch);
    _drawEnemies(canvas, cw, ch);
    _drawProjectiles(canvas, cw, ch);
    _drawBorder(canvas, size);
  }

  // ─── Background ─────────────────────────────────────────────────────────────
  void _drawBackground(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)),
      Paint()..color = map.boardColor,
    );
  }

  // ─── Path ───────────────────────────────────────────────────────────────────
  void _drawPath(Canvas canvas, double cw, double ch) {
    // glow under path
    final glowPaint = Paint()
      ..color = map.themeColor.withAlpha(30)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    for (final cell in map.pathCells) {
      final r = cell.y;
      final c = cell.x;
      canvas.drawRect(Rect.fromLTWH(c * cw, r * ch, cw, ch), glowPaint);
    }

    final pathPaint = Paint()..color = map.pathColor;
    for (final cell in map.pathCells) {
      final r = cell.y;
      final c = cell.x;
      canvas.drawRect(
        Rect.fromLTWH(c * cw, r * ch, cw, ch).deflate(1),
        pathPaint,
      );
    }

    // animated rune arrows along path
    _drawPathArrows(canvas, cw, ch);
  }

  void _drawPathArrows(Canvas canvas, double cw, double ch) {
    final total = pathData.totalLength;
    const spacing = 1.5;
    double d = (animTime * 0.6) % spacing;
    final arrowPaint = Paint()
      ..color = map.themeColor.withAlpha(120)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    while (d < total - 0.1) {
      final p0 = pathData.resolve(d);
      final p1 = pathData.resolve(math.min(d + 0.2, total));
      final dir = p1 - p0;
      final len = dir.distance;
      if (len < 0.01) {
        d += spacing;
        continue;
      }
      final n = dir / len;
      final center = Offset(p0.dx * cw, p0.dy * ch);
      final perp = Offset(-n.dy, n.dx);
      final ahead = Offset(n.dx * cw * 0.22, n.dy * ch * 0.22);
      final left = Offset(
        -perp.dx * cw * 0.12 - n.dx * cw * 0.12,
        -perp.dy * ch * 0.12 - n.dy * ch * 0.12,
      );
      final right = Offset(
        perp.dx * cw * 0.12 - n.dx * cw * 0.12,
        perp.dy * ch * 0.12 - n.dy * ch * 0.12,
      );
      final path = Path()
        ..moveTo(center.dx + ahead.dx, center.dy + ahead.dy)
        ..lineTo(center.dx + left.dx, center.dy + left.dy)
        ..moveTo(center.dx + ahead.dx, center.dy + ahead.dy)
        ..lineTo(center.dx + right.dx, center.dy + right.dy);
      canvas.drawPath(path, arrowPaint);
      d += spacing;
    }
  }

  // ─── Grid ───────────────────────────────────────────────────────────────────
  void _drawGrid(Canvas canvas, Size size, double cw, double ch) {
    final paint = Paint()
      ..color = RuneColors.gridLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    for (int r = 0; r <= map.rows; r++) {
      canvas.drawLine(Offset(0, r * ch), Offset(size.width, r * ch), paint);
    }
    for (int c = 0; c <= map.cols; c++) {
      canvas.drawLine(Offset(c * cw, 0), Offset(c * cw, size.height), paint);
    }
  }

  // ─── Pending cell highlight ──────────────────────────────────────────────────
  void _drawPendingCell(Canvas canvas, double cw, double ch) {
    if (pendingRow == null || pendingCol == null) return;
    final rect = Rect.fromLTWH(
      pendingCol! * cw,
      pendingRow! * ch,
      cw,
      ch,
    ).deflate(1);
    canvas.drawRect(rect, Paint()..color = RuneColors.accent.withAlpha(60));
    canvas.drawRect(
      rect,
      Paint()
        ..color = RuneColors.accent.withAlpha(200)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  // ─── Towers ──────────────────────────────────────────────────────────────────
  void _drawTowers(Canvas canvas, double cw, double ch) {
    for (final tower in towers) {
      _drawTower(canvas, tower, cw, ch);
    }
  }

  void _drawTower(Canvas canvas, GridTower tower, double cw, double ch) {
    final center = Offset((tower.col + 0.5) * cw, (tower.row + 0.5) * ch);
    final baseR = math.min(cw, ch) * 0.28;
    final col = tower.color;

    // animated pulse for laser tower
    if (tower.type == TowerType.laser) {
      final pulse = 0.08 + 0.05 * math.sin(animTime * 6);
      canvas.drawCircle(
        center,
        baseR * (1.8 + pulse),
        Paint()
          ..color = col.withAlpha(25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }

    // halo rúnico
    canvas.drawCircle(
      center,
      baseR * 1.55,
      Paint()
        ..color = col.withAlpha(30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // decoração octogonal rúnica
    _drawRuneOctagon(canvas, center, baseR * 1.35, col.withAlpha(50));

    // base
    canvas.drawCircle(center, baseR, Paint()..color = col.withAlpha(220));

    // núcleo
    canvas.drawCircle(
      center,
      baseR * 0.48,
      Paint()..color = RuneColors.towerCore,
    );

    // label
    final tp = TextPainter(
      text: TextSpan(
        text: tower.label,
        style: TextStyle(
          color: col,
          fontSize: baseR * 0.9,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );

    // level badge
    final lvlPainter = TextPainter(
      text: TextSpan(
        text: '${tower.level}',
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    lvlPainter.paint(
      canvas,
      Offset(center.dx - lvlPainter.width / 2, center.dy + baseR * 0.85),
    );
  }

  void _drawRuneOctagon(Canvas canvas, Offset center, double r, Color color) {
    final path = Path();
    for (int i = 0; i < 8; i++) {
      final angle = (i / 8) * math.pi * 2 - math.pi / 8;
      final pt = Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  // ─── Enemies ─────────────────────────────────────────────────────────────────
  void _drawEnemies(Canvas canvas, double cw, double ch) {
    for (final enemy in enemies) {
      if (!enemy.alive) continue;
      _drawEnemy(canvas, enemy, cw, ch);
    }
  }

  void _drawEnemy(Canvas canvas, Enemy enemy, double cw, double ch) {
    final gp = pathData.resolve(enemy.distance);
    final center = Offset(gp.dx * cw, gp.dy * ch);
    final isTank = enemy.type == EnemyType.tank;
    final radius = math.min(cw, ch) * (isTank ? 0.30 : 0.20);
    final col = enemy.color;

    // slow aura
    if (enemy.slowTimer > 0) {
      canvas.drawCircle(
        center,
        radius * 1.7,
        Paint()
          ..color = RuneColors.projSlow.withAlpha(60)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }

    // flying aura
    if (enemy.flying) {
      canvas.drawCircle(
        center,
        radius * 1.6,
        Paint()
          ..color = RuneColors.enemyFlying.withAlpha(45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    // regen shimmer
    if (enemy.type == EnemyType.regen) {
      final shimmer = 0.3 + 0.3 * math.sin(animTime * 5);
      canvas.drawCircle(
        center,
        radius * (1.4 + shimmer * 0.1),
        Paint()
          ..color = RuneColors.enemyRegen.withAlpha((shimmer * 80).round())
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    // body
    canvas.drawCircle(center, radius, Paint()..color = col);

    // inner glow
    canvas.drawCircle(
      center,
      radius * 0.45,
      Paint()..color = Colors.white.withAlpha(140),
    );

    // tank extra ring
    if (isTank) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = col
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }

    // HP bar
    final hpPct = (enemy.hp / enemy.maxHp).clamp(0.0, 1.0);
    final barW = cw * 0.76;
    final barH = 4.5;
    final barBg = Rect.fromCenter(
      center: Offset(center.dx, center.dy - radius - 9),
      width: barW,
      height: barH,
    );
    final barFill = Rect.fromLTWH(
      barBg.left,
      barBg.top,
      barBg.width * hpPct,
      barH,
    );
    final hpCol = hpPct > 0.5 ? RuneColors.hpBar : RuneColors.hpBarLow;

    canvas.drawRRect(
      RRect.fromRectAndRadius(barBg, const Radius.circular(3)),
      Paint()..color = Colors.black54,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(barFill, const Radius.circular(3)),
      Paint()..color = hpCol,
    );
  }

  // ─── Projectiles ─────────────────────────────────────────────────────────────
  void _drawProjectiles(Canvas canvas, double cw, double ch) {
    for (final proj in projectiles) {
      if (proj.dead) continue;
      final center = Offset(proj.position.dx * cw, proj.position.dy * ch);
      final isSplash = proj.kind == ProjectileKind.splash;
      final r = isSplash ? 5.5 : 4.0;

      // glow
      canvas.drawCircle(
        center,
        r * 1.5,
        Paint()
          ..color = proj.color.withAlpha(80)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      // body
      canvas.drawCircle(center, r, Paint()..color = proj.color);
      // core
      canvas.drawCircle(
        center,
        r * 0.45,
        Paint()..color = Colors.white.withAlpha(220),
      );
    }
  }

  // ─── Border ──────────────────────────────────────────────────────────────────
  void _drawBorder(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = RuneColors.accent.withAlpha(45),
    );
  }

  @override
  bool shouldRepaint(covariant BoardPainter old) => true;
}
