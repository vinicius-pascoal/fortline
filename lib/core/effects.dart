import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'models.dart';

final _rng = math.Random();

// ─── Factory helpers ─────────────────────────────────────────────────────────

/// Spawn a burst of particles at [gridPos] (grid-space).
List<Particle> spawnExplosion({
  required Offset gridPos,
  required Color color,
  int count = 18,
  double speedMin = 0.6,
  double speedMax = 2.2,
}) {
  return List.generate(count, (_) {
    final angle = _rng.nextDouble() * math.pi * 2;
    final speed = speedMin + _rng.nextDouble() * (speedMax - speedMin);
    return Particle(
      position: gridPos,
      velocity: Offset(math.cos(angle) * speed, math.sin(angle) * speed),
      life: 1.0,
      maxLife: 0.45 + _rng.nextDouble() * 0.35,
      size: 0.05 + _rng.nextDouble() * 0.10,
      color: Color.lerp(color, Colors.white, _rng.nextDouble() * 0.5)!,
    );
  });
}

/// Tiny hit-spark particles.
List<Particle> spawnImpactSparks({
  required Offset gridPos,
  required Color color,
  int count = 6,
}) {
  return List.generate(count, (_) {
    final angle = _rng.nextDouble() * math.pi * 2;
    final speed = 0.3 + _rng.nextDouble() * 0.8;
    return Particle(
      position: gridPos,
      velocity: Offset(math.cos(angle) * speed, math.sin(angle) * speed),
      life: 1.0,
      maxLife: 0.20 + _rng.nextDouble() * 0.15,
      size: 0.03 + _rng.nextDouble() * 0.05,
      color: color,
    );
  });
}

ImpactFlash spawnFlash({
  required Offset gridPos,
  required Color color,
  double radius = 0.5,
}) {
  return ImpactFlash(
    position: gridPos,
    life: 1.0,
    radius: radius,
    color: color,
  );
}

LaserBeam spawnLaser({
  required Offset from,
  required Offset to,
  Color color = const Color(0xFFFF1744),
}) {
  return LaserBeam(from: from, to: to, life: 1.0, color: color);
}

// ─── Update helpers ───────────────────────────────────────────────────────────
void updateParticles(List<Particle> particles, double dt) {
  for (final p in particles) {
    if (p.dead) continue;
    p.life -= dt / p.maxLife;
    if (p.life <= 0) {
      p.dead = true;
      continue;
    }
    p.position += p.velocity * dt;
    // gravity
    p.velocity = Offset(p.velocity.dx * 0.92, p.velocity.dy * 0.92 + 0.8 * dt);
  }
  particles.removeWhere((p) => p.dead);
}

void updateFlashes(List<ImpactFlash> flashes, double dt) {
  for (final f in flashes) {
    f.life -= dt / 0.18;
  }
  flashes.removeWhere((f) => f.life <= 0);
}

void updateLasers(List<LaserBeam> lasers, double dt) {
  for (final l in lasers) {
    l.life -= dt / 0.12;
  }
  lasers.removeWhere((l) => l.life <= 0);
}

// ─── Draw helpers (call inside CustomPainter) ─────────────────────────────────
void drawParticles(
  Canvas canvas,
  List<Particle> particles,
  double cw,
  double ch,
) {
  for (final p in particles) {
    final alpha = (p.life * 255).clamp(0, 255).toInt();
    final paint = Paint()
      ..color = p.color.withAlpha(alpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(
      Offset(p.position.dx * cw, p.position.dy * ch),
      p.size * math.min(cw, ch),
      paint,
    );
  }
}

void drawFlashes(
  Canvas canvas,
  List<ImpactFlash> flashes,
  double cw,
  double ch,
) {
  for (final f in flashes) {
    final alpha = (f.life * 200).clamp(0, 255).toInt();
    canvas.drawCircle(
      Offset(f.position.dx * cw, f.position.dy * ch),
      f.radius * math.min(cw, ch),
      Paint()
        ..color = f.color.withAlpha(alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }
}

void drawLasers(Canvas canvas, List<LaserBeam> lasers, double cw, double ch) {
  for (final l in lasers) {
    final alpha = (l.life * 255).clamp(0, 255).toInt();
    // glow
    canvas.drawLine(
      Offset(l.from.dx * cw, l.from.dy * ch),
      Offset(l.to.dx * cw, l.to.dy * ch),
      Paint()
        ..color = l.color.withAlpha((alpha * 0.5).round())
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    // core
    canvas.drawLine(
      Offset(l.from.dx * cw, l.from.dy * ch),
      Offset(l.to.dx * cw, l.to.dy * ch),
      Paint()
        ..color = Colors.white.withAlpha(alpha)
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );
  }
}
