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
  final GridTower? selectedTower;

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
    this.selectedTower,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cw = size.width / map.cols;
    final ch = size.height / map.rows;

    _drawBackground(canvas, size);
    _drawTerrain(canvas, size, cw, ch);
    _drawGrid(
      canvas,
      size,
      cw,
      ch,
    ); // grid antes do path: ribbon cobre as linhas
    _drawPath(canvas, cw, ch);
    _drawPendingCell(canvas, cw, ch);
    if (selectedTower != null) _drawRangeRing(canvas, selectedTower!, cw, ch);
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
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(18),
    );
    canvas.drawRRect(rrect, Paint()..color = map.boardColor);
    // vinheta: borda mais escura cria profundidade
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.82,
          colors: [Colors.transparent, Colors.black.withAlpha(95)],
        ).createShader(Offset.zero & size),
    );
  }

  // ─── Terrain (células não construíveis) ──────────────────────────────────────
  void _drawTerrain(Canvas canvas, Size size, double cw, double ch) {
    final pathSet = map.pathCellSet;

    for (int r = 0; r < map.rows; r++) {
      for (int c = 0; c < map.cols; c++) {
        if (pathSet.contains('${r}_$c')) continue;

        final rect = Rect.fromLTWH(c * cw, r * ch, cw, ch);
        if (!map.isBuildable(r, c)) {
          // xadrez sutil: células alternas ligeiramente mais escuras para textura
          final dark = (r + c) % 2 == 0;
          final terrColor = dark
              ? RuneColors.terrain
              : Color.lerp(RuneColors.terrain, map.boardColor, 0.30)!;
          canvas.drawRect(rect, Paint()..color = terrColor);

          // textura de rocha
          final cx = c * cw + cw * 0.5;
          final cy = r * ch + ch * 0.5;
          final dotAlpha = dark ? 255 : 160;
          final dotPaint = Paint()
            ..color = RuneColors.terrainDot.withAlpha(dotAlpha);
          canvas.drawCircle(
            Offset(cx - cw * 0.20, cy - ch * 0.20),
            1.6,
            dotPaint,
          );
          canvas.drawCircle(
            Offset(cx + cw * 0.20, cy + ch * 0.20),
            1.6,
            dotPaint,
          );
          canvas.drawCircle(
            Offset(cx - cw * 0.20, cy + ch * 0.20),
            1.0,
            dotPaint,
          );
          canvas.drawCircle(
            Offset(cx + cw * 0.20, cy - ch * 0.18),
            1.0,
            dotPaint,
          );
          _drawTerrainDecor(canvas, r, c, cx, cy, cw, ch);
        } else {
          // slot construível: glow pulsante temático + marcadores de canto
          final glowA = (15 + 13 * math.sin(animTime * 2.2 + r * 0.7 + c * 1.3))
              .round()
              .clamp(4, 40);
          canvas.drawRect(
            rect,
            Paint()..color = map.themeColor.withAlpha(glowA),
          );

          final slotPaint = Paint()
            ..color = map.themeColor.withAlpha(85)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.1;
          final inset = rect.deflate(math.min(cw, ch) * 0.15);
          final cornerLen = math.min(cw, ch) * 0.22;
          _drawCornerMarks(canvas, inset, cornerLen, slotPaint);
        }
      }
    }
  }

  void _drawCornerMarks(Canvas canvas, Rect rect, double len, Paint paint) {
    canvas.drawLine(rect.topLeft, rect.topLeft + Offset(len, 0), paint);
    canvas.drawLine(rect.topLeft, rect.topLeft + Offset(0, len), paint);
    canvas.drawLine(rect.topRight, rect.topRight + Offset(-len, 0), paint);
    canvas.drawLine(rect.topRight, rect.topRight + Offset(0, len), paint);
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + Offset(len, 0), paint);
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + Offset(0, -len), paint);
    canvas.drawLine(
      rect.bottomRight,
      rect.bottomRight + Offset(-len, 0),
      paint,
    );
    canvas.drawLine(
      rect.bottomRight,
      rect.bottomRight + Offset(0, -len),
      paint,
    );
  }

  // ─── Decorações temáticas de terreno ──────────────────────────────────────────
  void _drawTerrainDecor(
    Canvas canvas,
    int r,
    int c,
    double cx,
    double cy,
    double cw,
    double ch,
  ) {
    final seed = (r * 37 + c * 53 + r * c) % 97;
    if (seed > 58) return; // ~60% das células recebem decoração
    final unit = math.min(cw, ch);
    final radius = unit * (0.30 + (seed % 7) * 0.03);
    if (map.id == 0) {
      _drawTree(canvas, cx, cy, radius);
    } else if (map.id == 1) {
      _drawRuneGlyph(canvas, cx, cy, radius, seed);
    } else {
      _drawLavaCrack(canvas, cx, cy, radius, seed);
    }
  }

  // Floresta: silhueta de árvore
  void _drawTree(Canvas canvas, double cx, double cy, double r) {
    // tronco
    canvas.drawLine(
      Offset(cx, cy + r * 0.20),
      Offset(cx, cy + r * 0.85),
      Paint()
        ..color = const Color(0xFF4E342E).withAlpha(155)
        ..strokeWidth = r * 0.22
        ..strokeCap = StrokeCap.round,
    );
    // copa inferior
    canvas.drawCircle(
      Offset(cx, cy + r * 0.05),
      r * 0.52,
      Paint()..color = map.themeColor.withAlpha(85),
    );
    // copa superior
    canvas.drawCircle(
      Offset(cx, cy - r * 0.28),
      r * 0.38,
      Paint()..color = map.themeColor.withAlpha(130),
    );
  }

  // Ruinas Arcanas: glifo polígono + cruz
  void _drawRuneGlyph(Canvas canvas, double cx, double cy, double r, int seed) {
    final sides = 5 + seed % 3;
    final col = map.themeColor.withAlpha(80 + (seed % 5) * 14);
    final rot = seed * 0.19;
    final path = Path();
    for (int i = 0; i < sides; i++) {
      final a = rot + (i / sides) * math.pi * 2 - math.pi / 2;
      final pt = Offset(cx + r * math.cos(a), cy + r * math.sin(a));
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = col
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
    canvas.drawLine(
      Offset(cx - r * 0.22, cy),
      Offset(cx + r * 0.22, cy),
      Paint()
        ..color = col
        ..strokeWidth = 0.8,
    );
    canvas.drawLine(
      Offset(cx, cy - r * 0.22),
      Offset(cx, cy + r * 0.22),
      Paint()
        ..color = col
        ..strokeWidth = 0.8,
    );
  }

  // Abismo Vulcânico: fendas de lava animadas
  void _drawLavaCrack(Canvas canvas, double cx, double cy, double r, int seed) {
    final glow = 0.45 + 0.55 * math.sin(animTime * 2.2 + seed * 0.37);
    final col = const Color(0xFFFF6D00).withAlpha((50 + glow * 90).round());
    final paint = Paint()
      ..color = col
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    final nLines = 2 + seed % 3;
    for (int i = 0; i < nLines; i++) {
      final baseAngle = seed * 0.22 + i * (math.pi / nLines);
      final midX = cx + r * 0.38 * math.cos(baseAngle + 0.55);
      final midY = cy + r * 0.38 * math.sin(baseAngle + 0.55);
      final endX = cx + r * 0.82 * math.cos(baseAngle - 0.28);
      final endY = cy + r * 0.82 * math.sin(baseAngle - 0.28);
      canvas.drawLine(Offset(cx, cy), Offset(midX, midY), paint);
      canvas.drawLine(Offset(midX, midY), Offset(endX, endY), paint);
    }
  }

  // ─── Path ───────────────────────────────────────────────────────────────────
  void _drawPath(Canvas canvas, double cw, double ch) {
    if (map.pathCells.length < 2) return;

    // Ribbon: linha central com traço arredondado (elimina cantos quadrados)
    final pts = map.pathCells
        .map((p) => Offset((p.x + 0.5) * cw, (p.y + 0.5) * ch))
        .toList();
    final ribbon = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      ribbon.lineTo(pts[i].dx, pts[i].dy);
    }
    final w = math.min(cw, ch);

    // glow temático externo
    canvas.drawPath(
      ribbon,
      Paint()
        ..color = map.themeColor.withAlpha(52)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 1.10
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    // borda escura (dá profundidade)
    canvas.drawPath(
      ribbon,
      Paint()
        ..color = Colors.black.withAlpha(115)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.97
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    // cor principal do caminho
    canvas.drawPath(
      ribbon,
      Paint()
        ..color = map.pathColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.84
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    // reflexo central (iluminação de cima)
    canvas.drawPath(
      ribbon,
      Paint()
        ..color = Colors.white.withAlpha(22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.34
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    _drawPathArrows(canvas, cw, ch);
    _drawEntryExit(canvas, cw, ch);
  }

  void _drawEntryExit(Canvas canvas, double cw, double ch) {
    if (map.pathCells.isEmpty) return;
    final pulse = math.sin(animTime * 3.2);
    final baseR = math.min(cw, ch) * 0.28;

    // portão de entrada
    final entry = map.pathCells.first;
    final ec = Offset((entry.x + 0.5) * cw, (entry.y + 0.5) * ch);
    canvas.drawCircle(
      ec,
      baseR * (1.65 + pulse * 0.12),
      Paint()
        ..color = map.themeColor.withAlpha(55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawCircle(
      ec,
      baseR * (1.18 + pulse * 0.07),
      Paint()
        ..color = map.themeColor.withAlpha(200)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
    _drawPortalLabel(canvas, ec, '▶', map.themeColor.withAlpha(230));

    // portão de saída
    final exit = map.pathCells.last;
    final xc = Offset((exit.x + 0.5) * cw, (exit.y + 0.5) * ch);
    const exitCol = Color(0xFFFF3333);
    canvas.drawCircle(
      xc,
      baseR * (1.5 - pulse * 0.10),
      Paint()
        ..color = exitCol.withAlpha(55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(
      xc,
      baseR * (1.1 - pulse * 0.05),
      Paint()
        ..color = exitCol.withAlpha(185)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    _drawPortalLabel(canvas, xc, '✖', exitCol.withAlpha(210));
  }

  void _drawPortalLabel(
    Canvas canvas,
    Offset center,
    String text,
    Color color,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );
  }

  void _drawPathArrows(Canvas canvas, double cw, double ch) {
    final total = pathData.totalLength;
    const spacing = 1.5;
    double d = (animTime * 0.6) % spacing;
    final arrowPaint = Paint()
      ..color = map.themeColor.withAlpha(155)
      ..strokeWidth = 1.5
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
      final ahead = Offset(n.dx * cw * 0.27, n.dy * ch * 0.27);
      final left = Offset(
        -perp.dx * cw * 0.14 - n.dx * cw * 0.14,
        -perp.dy * ch * 0.14 - n.dy * ch * 0.14,
      );
      final right = Offset(
        perp.dx * cw * 0.14 - n.dx * cw * 0.14,
        perp.dy * ch * 0.14 - n.dy * ch * 0.14,
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

  void _drawRangeRing(Canvas canvas, GridTower tower, double cw, double ch) {
    final center = Offset((tower.col + 0.5) * cw, (tower.row + 0.5) * ch);
    final rangeR = tower.range * cw;
    final col = tower.color;
    canvas.drawCircle(center, rangeR, Paint()..color = col.withAlpha(22));
    canvas.drawCircle(
      center,
      rangeR,
      Paint()
        ..color = col.withAlpha(160)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
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
    final radius =
        math.min(cw, ch) *
        (enemy.isBoss
            ? 0.38
            : isTank
            ? 0.30
            : 0.20);
    final col = enemy.color;

    // alpha fade-in durante spawn
    final alphaScale = enemy.spawnTimer > 0
        ? (1.0 - enemy.spawnTimer / 0.5).clamp(0.0, 1.0)
        : 1.0;
    final alpha = (alphaScale * 255).round();

    // teleport ring durante spawn
    if (enemy.spawnTimer > 0) {
      final ring = 1.0 - (enemy.spawnTimer / 0.5);
      canvas.drawCircle(
        center,
        radius * (1.0 + ring * 1.8),
        Paint()
          ..color = col.withAlpha(((1.0 - ring) * 180).round())
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }

    // boss pulsing gold ring
    if (enemy.isBoss) {
      final pulse = 0.06 + 0.05 * math.sin(animTime * 5);
      canvas.drawCircle(
        center,
        radius * (1.55 + pulse),
        Paint()
          ..color = Colors.amber.withAlpha(((alphaScale * 70)).round())
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawCircle(
        center,
        radius * (1.4 + pulse),
        Paint()
          ..color = Colors.amber.withAlpha(((alphaScale * 150)).round())
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }

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

    // body (com fade-in)
    canvas.drawCircle(center, radius, Paint()..color = col.withAlpha(alpha));

    // inner glow
    canvas.drawCircle(
      center,
      radius * 0.45,
      Paint()..color = Colors.white.withAlpha(((alphaScale * 140)).round()),
    );

    // tank extra ring
    if (isTank) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = col.withAlpha(alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }

    // HP bar (com fade-in)
    final hpPct = (enemy.hp / enemy.maxHp).clamp(0.0, 1.0);
    final barW = cw * (enemy.isBoss ? 1.1 : 0.76);
    final barH = enemy.isBoss ? 6.0 : 4.5;
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
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(18),
    );
    // glow externo temático
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0
        ..color = map.themeColor.withAlpha(60)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    // linha nítida
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = map.themeColor.withAlpha(145),
    );

    // ornamentos de canto
    final cl = math.min(size.width, size.height) * 0.055;
    final cornerPaint = Paint()
      ..color = map.themeColor.withAlpha(210)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    const pad = 9.0;
    final w = size.width;
    final h = size.height;
    final corners = [
      [Offset(pad, pad), Offset(pad + cl, pad), Offset(pad, pad + cl)],
      [
        Offset(w - pad, pad),
        Offset(w - pad - cl, pad),
        Offset(w - pad, pad + cl),
      ],
      [
        Offset(pad, h - pad),
        Offset(pad + cl, h - pad),
        Offset(pad, h - pad - cl),
      ],
      [
        Offset(w - pad, h - pad),
        Offset(w - pad - cl, h - pad),
        Offset(w - pad, h - pad - cl),
      ],
    ];
    for (final c in corners) {
      canvas.drawLine(c[0], c[1], cornerPaint);
      canvas.drawLine(c[0], c[2], cornerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant BoardPainter old) => true;
}
