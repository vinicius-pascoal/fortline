import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'colors.dart';

// ─── Enums ───────────────────────────────────────────────────────────────────
enum TowerType { sniper, splash, fast, slow, laser }

enum EnemyType { normal, fast, tank, flying, regen }

enum ProjectileKind { bullet, splash, laser }

// ─── Tower Static Definitions ─────────────────────────────────────────────────
class TowerDef {
  final TowerType type;
  final String name;
  final String emoji;
  final int cost;
  final Color color;
  final String description;
  final ProjectileKind projectileKind;

  const TowerDef({
    required this.type,
    required this.name,
    required this.emoji,
    required this.cost,
    required this.color,
    required this.description,
    required this.projectileKind,
  });
}

const List<TowerDef> kTowerDefs = [
  TowerDef(
    type: TowerType.sniper,
    name: 'Sniper',
    emoji: '🔵',
    cost: 80,
    color: RuneColors.towerSniper,
    description: 'Longo alcance, alto dano',
    projectileKind: ProjectileKind.bullet,
  ),
  TowerDef(
    type: TowerType.splash,
    name: 'Splash',
    emoji: '🔶',
    cost: 100,
    color: RuneColors.towerSplash,
    description: 'Dano em área',
    projectileKind: ProjectileKind.splash,
  ),
  TowerDef(
    type: TowerType.fast,
    name: 'Rápida',
    emoji: '🟢',
    cost: 60,
    color: RuneColors.towerFast,
    description: 'Cadência altíssima',
    projectileKind: ProjectileKind.bullet,
  ),
  TowerDef(
    type: TowerType.slow,
    name: 'Lenta',
    emoji: '🟣',
    cost: 70,
    color: RuneColors.towerSlow,
    description: 'Lentifica inimigos',
    projectileKind: ProjectileKind.bullet,
  ),
  TowerDef(
    type: TowerType.laser,
    name: 'Laser',
    emoji: '🔴',
    cost: 130,
    color: RuneColors.towerLaser,
    description: 'Dano contínuo em linha',
    projectileKind: ProjectileKind.laser,
  ),
];

// ─── GridTower ────────────────────────────────────────────────────────────────
class GridTower {
  final int row;
  final int col;
  final TowerType type;
  int level;
  double cooldown;
  // laser beam target (for drawing)
  Enemy? laserTarget;

  GridTower({
    required this.row,
    required this.col,
    required this.type,
    this.level = 1,
    this.cooldown = 0,
    this.laserTarget,
  });

  Offset get center => Offset(col + 0.5, row + 0.5);

  double get range {
    switch (type) {
      case TowerType.sniper:
        return 4.5 + (level - 1) * 0.5;
      case TowerType.splash:
        return 2.2 + (level - 1) * 0.3;
      case TowerType.fast:
        return 1.8 + (level - 1) * 0.25;
      case TowerType.slow:
        return 2.5 + (level - 1) * 0.3;
      case TowerType.laser:
        return 3.5 + (level - 1) * 0.4;
    }
  }

  double get damage {
    switch (type) {
      case TowerType.sniper:
        return 55 + (level - 1) * 30;
      case TowerType.splash:
        return 20 + (level - 1) * 12;
      case TowerType.fast:
        return 10 + (level - 1) * 6;
      case TowerType.slow:
        return 8 + (level - 1) * 5;
      case TowerType.laser:
        return 22 + (level - 1) * 10; // DPS
    }
  }

  double get fireInterval {
    switch (type) {
      case TowerType.sniper:
        return math.max(0.5, 1.6 - (level - 1) * 0.12);
      case TowerType.splash:
        return math.max(0.5, 1.2 - (level - 1) * 0.10);
      case TowerType.fast:
        return math.max(0.08, 0.28 - (level - 1) * 0.03);
      case TowerType.slow:
        return math.max(0.4, 1.0 - (level - 1) * 0.10);
      case TowerType.laser:
        return 0.0; // continuous — handled separately
    }
  }

  double get splashRadius => 1.0 + (level - 1) * 0.2;

  int get upgradeCost {
    final base = kTowerDefs.firstWhere((d) => d.type == type).cost;
    return (base * 0.6 + level * 25).round();
  }

  Color get color {
    switch (type) {
      case TowerType.sniper:
        return RuneColors.towerSniper;
      case TowerType.splash:
        return RuneColors.towerSplash;
      case TowerType.fast:
        return RuneColors.towerFast;
      case TowerType.slow:
        return RuneColors.towerSlow;
      case TowerType.laser:
        return RuneColors.towerLaser;
    }
  }

  String get label {
    switch (type) {
      case TowerType.sniper:
        return 'S';
      case TowerType.splash:
        return 'X';
      case TowerType.fast:
        return 'R';
      case TowerType.slow:
        return 'L';
      case TowerType.laser:
        return '⚡';
    }
  }
}

// ─── Enemy ────────────────────────────────────────────────────────────────────
class Enemy {
  final EnemyType type;
  double distance;
  double speed;
  double hp;
  double maxHp;
  int reward;
  bool alive;
  bool flying;
  double slowTimer;
  double slowFactor;

  Enemy({
    required this.type,
    this.distance = 0,
    required this.speed,
    required this.hp,
    required this.maxHp,
    required this.reward,
    this.alive = true,
    this.flying = false,
    this.slowTimer = 0,
    this.slowFactor = 1.0,
  });

  double get effectiveSpeed => speed * slowFactor;

  Color get color {
    switch (type) {
      case EnemyType.normal:
        return RuneColors.enemyNormal;
      case EnemyType.fast:
        return RuneColors.enemyFast;
      case EnemyType.tank:
        return RuneColors.enemyTank;
      case EnemyType.flying:
        return RuneColors.enemyFlying;
      case EnemyType.regen:
        return RuneColors.enemyRegen;
    }
  }
}

// ─── Projectile ───────────────────────────────────────────────────────────────
class Projectile {
  Offset position;
  Enemy? target;
  double speed;
  double damage;
  bool dead;
  Color color;
  ProjectileKind kind;
  double splashRadius;
  double slowFactor;
  double slowDuration;

  Projectile({
    required this.position,
    required this.target,
    required this.speed,
    required this.damage,
    this.dead = false,
    this.color = RuneColors.projFast,
    this.kind = ProjectileKind.bullet,
    this.splashRadius = 0,
    this.slowFactor = 1.0,
    this.slowDuration = 0,
  });
}

// ─── Particle ─────────────────────────────────────────────────────────────────
class Particle {
  Offset position;
  Offset velocity;
  double life; // 0→1, starts at 1
  double maxLife;
  double size;
  Color color;
  bool dead;

  Particle({
    required this.position,
    required this.velocity,
    required this.life,
    required this.maxLife,
    required this.size,
    required this.color,
    this.dead = false,
  });
}

// ─── ImpactFlash ──────────────────────────────────────────────────────────────
class ImpactFlash {
  Offset position;
  double life; // starts at 1
  double radius;
  Color color;

  ImpactFlash({
    required this.position,
    required this.life,
    required this.radius,
    required this.color,
  });
}

// ─── LaserBeam ────────────────────────────────────────────────────────────────
class LaserBeam {
  Offset from;
  Offset to;
  double life; // starts at 1, quickly fades
  Color color;

  LaserBeam({
    required this.from,
    required this.to,
    required this.life,
    required this.color,
  });
}
