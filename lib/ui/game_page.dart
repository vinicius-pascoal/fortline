import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../core/colors.dart';
import '../core/effects.dart';
import '../core/maps.dart';
import '../core/models.dart';
import '../core/save_manager.dart';
import 'board_painter.dart';
import 'widgets.dart';

class GamePage extends StatefulWidget {
  final MapDef map;
  final SaveManager save;

  const GamePage({super.key, required this.map, required this.save});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage>
    with SingleTickerProviderStateMixin {
  late final PathData _path;
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;
  double _animTime = 0;

  final List<GridTower> _towers = [];
  final List<Enemy> _enemies = [];
  final List<Projectile> _projectiles = [];
  final List<Particle> _particles = [];
  final List<ImpactFlash> _flashes = [];
  final List<LaserBeam> _lasers = [];

  late int _coins;
  late int _lives;
  int _score = 0;
  int _wave = 1;
  int _totalCoinsEarned = 0;

  int _remainingToSpawn = 0;
  double _spawnTimer = 0;
  double _nextWaveTimer = 0;
  bool _gameOver = false;
  bool _gameWon = false;
  bool _running = true;
  bool _newRecord = false;

  int? _pendingRow;
  int? _pendingCol;

  final _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _path = PathData.fromMap(widget.map);
    _coins = widget.map.startCoins;
    _lives = widget.map.startLives;
    _startWave(_wave);
    _ticker = createTicker(_tick)..start();
  }

  // ─── Wave logic ──────────────────────────────────────────────────────────────
  void _startWave(int wave) {
    _remainingToSpawn = 5 + wave * 2;
    _spawnTimer = 0.2;
  }

  void _spawnEnemy() {
    final diff = widget.map.difficultyMult;
    final hpS = diff * (1 + (_wave - 1) * 0.18);
    final speedS = diff * (1 + (_wave - 1) * 0.03);

    EnemyType type = EnemyType.normal;
    if (_wave >= 2) {
      final r = _rng.nextDouble();
      if (_wave >= 5 && r < 0.15) {
        type = EnemyType.regen;
      } else if (_wave >= 4 && r < 0.30) {
        type = EnemyType.flying;
      } else if (_wave >= 3 && r < 0.50) {
        type = EnemyType.tank;
      } else if (r < 0.65) {
        type = EnemyType.fast;
      }
    }

    double hp, speed;
    int reward;
    bool flying = false;

    switch (type) {
      case EnemyType.normal:
        hp = 35 * hpS;
        speed = 1.15 * speedS;
        reward = 12 + _wave * 2;
      case EnemyType.fast:
        hp = 20 * hpS;
        speed = 2.20 * speedS;
        reward = 15 + _wave * 2;
      case EnemyType.tank:
        hp = 120 * hpS;
        speed = 0.65 * speedS;
        reward = 30 + _wave * 3;
      case EnemyType.flying:
        hp = 28 * hpS;
        speed = 1.60 * speedS;
        reward = 20 + _wave * 2;
        flying = true;
      case EnemyType.regen:
        hp = 50 * hpS;
        speed = 1.00 * speedS;
        reward = 25 + _wave * 2;
    }

    _enemies.add(
      Enemy(
        type: type,
        maxHp: hp,
        hp: hp,
        speed: speed,
        reward: reward,
        flying: flying,
      ),
    );
    if (_remainingToSpawn == 1) _nextWaveTimer = 2.0;
  }

  // ─── Tick ────────────────────────────────────────────────────────────────────
  void _tick(Duration elapsed) {
    final dt = ((elapsed - _lastElapsed).inMicroseconds / 1e6)
        .clamp(0.0, 0.033)
        .toDouble();
    _lastElapsed = elapsed;
    _animTime += dt;

    if (!_running || _gameOver || _gameWon) {
      if (mounted) setState(() {});
      return;
    }

    _updateWave(dt);
    _updateEnemies(dt);
    _updateTowers(dt);
    _updateProjectiles(dt);
    _cleanup(dt);

    if (mounted) setState(() {});
  }

  void _updateWave(double dt) {
    if (_remainingToSpawn > 0) {
      _spawnTimer -= dt;
      if (_spawnTimer <= 0) {
        _spawnEnemy();
        _remainingToSpawn--;
        _spawnTimer = math.max(0.28, 0.85 - (_wave * 0.03));
      }
      return;
    }
    if (_enemies.isEmpty) {
      _nextWaveTimer -= dt;
      if (_nextWaveTimer <= 0) {
        // check win
        if (_wave >= widget.map.wavesCount) {
          _endGame(won: true);
          return;
        }
        _wave++;
        _nextWaveTimer = 2.0;
        _startWave(_wave);
      }
    }
  }

  void _updateEnemies(double dt) {
    for (final e in _enemies) {
      if (!e.alive) continue;
      e.distance += e.effectiveSpeed * dt;

      if (e.type == EnemyType.regen && e.hp < e.maxHp) {
        e.hp = math.min(e.maxHp, e.hp + e.maxHp * 0.04 * dt);
      }

      // slow decay
      if (e.slowTimer > 0) {
        e.slowTimer -= dt;
        if (e.slowTimer <= 0) {
          e.slowTimer = 0;
          e.slowFactor = 1.0;
        }
      }

      if (e.distance >= _path.totalLength) {
        e.alive = false;
        _lives--;
        if (_lives <= 0) {
          _lives = 0;
          _endGame(won: false);
        }
      }
    }
  }

  void _updateTowers(double dt) {
    for (final tower in _towers) {
      final isLaser = tower.type == TowerType.laser;

      if (isLaser) {
        // laser deals continuous damage
        Enemy? target = _findTarget(tower);
        if (target != null) {
          target.hp -= tower.damage * dt;
          final fromG = tower.center;
          final toG = _path.resolve(target.distance);
          _lasers.add(spawnLaser(from: fromG, to: toG, color: tower.color));
          tower.laserTarget = target;
          if (target.hp <= 0 && target.alive) {
            _killEnemy(target, tower.center);
          }
        } else {
          tower.laserTarget = null;
        }
        continue;
      }

      tower.cooldown -= dt;
      if (tower.cooldown > 0) continue;

      Enemy? target = _findTarget(tower);
      if (target == null) continue;

      final isSplash = tower.type == TowerType.splash;
      Color projColor;
      switch (tower.type) {
        case TowerType.sniper:
          projColor = RuneColors.projSniper;
        case TowerType.splash:
          projColor = RuneColors.projSplash;
        case TowerType.fast:
          projColor = RuneColors.projFast;
        case TowerType.slow:
          projColor = RuneColors.projSlow;
        default:
          projColor = RuneColors.projFast;
      }

      _projectiles.add(
        Projectile(
          position: tower.center,
          target: target,
          speed: tower.type == TowerType.sniper ? 14.0 : 8.0,
          damage: tower.damage,
          color: projColor,
          kind: isSplash ? ProjectileKind.splash : ProjectileKind.bullet,
          splashRadius: isSplash ? tower.splashRadius : 0,
          slowFactor: tower.type == TowerType.slow ? 0.5 : 1.0,
          slowDuration: tower.type == TowerType.slow ? 1.8 : 0.0,
        ),
      );
      tower.cooldown = tower.fireInterval;
    }
  }

  Enemy? _findTarget(GridTower tower) {
    final canHitFlying = tower.type != TowerType.slow;
    Enemy? target;
    double bestProgress = -1;
    for (final e in _enemies) {
      if (!e.alive || e.hp <= 0) continue;
      if (e.flying && !canHitFlying) continue;
      final pos = _path.resolve(e.distance);
      final dist = (pos - tower.center).distance;
      if (dist <= tower.range && e.distance > bestProgress) {
        bestProgress = e.distance;
        target = e;
      }
    }
    return target;
  }

  void _updateProjectiles(double dt) {
    for (final proj in _projectiles) {
      if (proj.dead) continue;
      final target = proj.target;
      if (target == null || !target.alive || target.hp <= 0) {
        proj.dead = true;
        continue;
      }

      final targetPos = _path.resolve(target.distance);
      final dir = targetPos - proj.position;
      final dist = dir.distance;

      if (dist < 0.12) {
        _hitProjectile(proj, target, targetPos);
        continue;
      }
      final step = proj.speed * dt;
      proj.position = step >= dist
          ? targetPos
          : proj.position + dir / dist * step;
    }
  }

  void _hitProjectile(Projectile proj, Enemy target, Offset hitPos) {
    proj.dead = true;

    if (proj.kind == ProjectileKind.splash) {
      // area damage
      for (final e in _enemies) {
        if (!e.alive || e.hp <= 0) continue;
        final ep = _path.resolve(e.distance);
        if ((ep - hitPos).distance <= proj.splashRadius) {
          e.hp -= proj.damage;
          _particles.addAll(
            spawnImpactSparks(gridPos: ep, color: proj.color, count: 4),
          );
          if (e.hp <= 0 && e.alive) _killEnemy(e, hitPos);
        }
      }
      _flashes.add(
        spawnFlash(
          gridPos: hitPos,
          color: proj.color,
          radius: proj.splashRadius * 0.7,
        ),
      );
      _particles.addAll(
        spawnExplosion(gridPos: hitPos, color: proj.color, count: 22),
      );
    } else {
      if (proj.slowFactor < 1.0) {
        target.slowTimer = proj.slowDuration;
        target.slowFactor = proj.slowFactor;
      }
      target.hp -= proj.damage;
      _particles.addAll(spawnImpactSparks(gridPos: hitPos, color: proj.color));
      _flashes.add(
        spawnFlash(gridPos: hitPos, color: proj.color, radius: 0.35),
      );
      if (target.hp <= 0 && target.alive) _killEnemy(target, hitPos);
    }
  }

  void _killEnemy(Enemy e, Offset pos) {
    e.alive = false;
    final reward = e.reward;
    _coins += reward;
    _totalCoinsEarned += reward;
    _score += 25;
    _particles.addAll(
      spawnExplosion(
        gridPos: _path.resolve(e.distance),
        color: e.color,
        count: 16,
      ),
    );
    _flashes.add(
      spawnFlash(
        gridPos: _path.resolve(e.distance),
        color: e.color,
        radius: 0.55,
      ),
    );
  }

  void _cleanup(double dt) {
    _enemies.removeWhere((e) => !e.alive);
    _projectiles.removeWhere((p) => p.dead);
    updateParticles(_particles, dt);
    updateFlashes(_flashes, dt);
    updateLasers(_lasers, dt);
  }

  Future<void> _endGame({required bool won}) async {
    _gameOver = !won;
    _gameWon = won;
    _running = false;

    _newRecord = await widget.save.submitScore(_score);
    await widget.save.submitWave(widget.map.id, _wave);
    await widget.save.addCoins(_totalCoinsEarned);

    // unlock next map
    if (won) {
      final nextId = widget.map.id + 1;
      if (nextId < kMaps.length) {
        await widget.save.unlockMap(nextId);
      }
    }

    if (mounted) setState(() {});
  }

  void _reset() {
    setState(() {
      _coins = widget.map.startCoins;
      _lives = widget.map.startLives;
      _score = 0;
      _wave = 1;
      _totalCoinsEarned = 0;
      _remainingToSpawn = 0;
      _spawnTimer = 0;
      _nextWaveTimer = 0;
      _gameOver = false;
      _gameWon = false;
      _running = true;
      _newRecord = false;
      _pendingRow = null;
      _pendingCol = null;
      _towers.clear();
      _enemies.clear();
      _projectiles.clear();
      _particles.clear();
      _flashes.clear();
      _lasers.clear();
      _startWave(_wave);
    });
  }

  // ─── Board tap ───────────────────────────────────────────────────────────────
  void _onBoardTap(Offset pos, Size size) {
    if (_gameOver || _gameWon) return;

    if (_pendingRow != null) {
      setState(() {
        _pendingRow = null;
        _pendingCol = null;
      });
      return;
    }

    final cw = size.width / widget.map.cols;
    final ch = size.height / widget.map.rows;
    final col = (pos.dx / cw).floor();
    final row = (pos.dy / ch).floor();

    if (row < 0 || row >= widget.map.rows) return;
    if (col < 0 || col >= widget.map.cols) return;
    if (widget.map.pathCellSet.contains('${row}_$col')) return;

    // existing tower → upgrade
    for (final t in _towers) {
      if (t.row == row && t.col == col) {
        if (_coins >= t.upgradeCost) {
          setState(() {
            _coins -= t.upgradeCost;
            t.level++;
          });
        }
        return;
      }
    }

    setState(() {
      _pendingRow = row;
      _pendingCol = col;
    });
  }

  void _buildTower(TowerType type) {
    if (_pendingRow == null || _pendingCol == null) return;
    final def = kTowerDefs.firstWhere((d) => d.type == type);
    if (_coins < def.cost) {
      setState(() {
        _pendingRow = null;
        _pendingCol = null;
      });
      return;
    }
    setState(() {
      _coins -= def.cost;
      _towers.add(GridTower(row: _pendingRow!, col: _pendingCol!, type: type));
      _pendingRow = null;
      _pendingCol = null;
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  // ─── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final map = widget.map;
    return Scaffold(
      backgroundColor: RuneColors.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1022),
        leading: BackButton(color: RuneColors.accent),
        title: Text(
          '${map.emoji} ${map.name}',
          style: const TextStyle(
            color: Color(0xFFBDB0FF),
            fontWeight: FontWeight.bold,
            letterSpacing: 1.4,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // HUD
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  HudCard(
                    label: 'Moedas',
                    value: '$_coins',
                    icon: Icons.auto_awesome,
                  ),
                  HudCard(
                    label: 'Vidas',
                    value: '$_lives',
                    icon: Icons.favorite_rounded,
                  ),
                  HudCard(
                    label: 'Wave',
                    value: '$_wave/${map.wavesCount}',
                    icon: Icons.waves_rounded,
                  ),
                  HudCard(
                    label: 'Score',
                    value: '$_score',
                    icon: Icons.stars_rounded,
                  ),
                ],
              ),
            ),
            // Board
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: AspectRatio(
                  aspectRatio: map.cols / map.rows,
                  child: LayoutBuilder(
                    builder: (ctx, constraints) {
                      final bs = Size(
                        constraints.maxWidth,
                        constraints.maxHeight,
                      );
                      return Stack(
                        children: [
                          GestureDetector(
                            onTapDown: (d) => _onBoardTap(d.localPosition, bs),
                            child: CustomPaint(
                              painter: BoardPainter(
                                map: map,
                                towers: _towers,
                                enemies: _enemies,
                                projectiles: _projectiles,
                                particles: _particles,
                                flashes: _flashes,
                                lasers: _lasers,
                                pathData: _path,
                                pendingRow: _pendingRow,
                                pendingCol: _pendingCol,
                                animTime: _animTime,
                              ),
                              child: const SizedBox.expand(),
                            ),
                          ),
                          if (_pendingRow != null && _pendingCol != null)
                            TowerPickerOverlay(
                              row: _pendingRow!,
                              col: _pendingCol!,
                              boardSize: bs,
                              rows: map.rows,
                              cols: map.cols,
                              coins: _coins,
                              onPick: _buildTower,
                              onCancel: () => setState(() {
                                _pendingRow = null;
                                _pendingCol = null;
                              }),
                            ),
                          if (_gameOver || _gameWon)
                            _EndOverlay(
                              won: _gameWon,
                              score: _score,
                              wave: _wave,
                              newRecord: _newRecord,
                              onRestart: _reset,
                              onExit: () => Navigator.of(context).pop(),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            // Controls
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 12),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => setState(() => _running = !_running),
                      style: FilledButton.styleFrom(
                        backgroundColor: RuneColors.accent,
                      ),
                      icon: Icon(
                        _running
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      label: Text(_running ? 'Pausar' : 'Continuar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _reset,
                      icon: const Icon(Icons.restart_alt_rounded),
                      label: const Text('Reiniciar'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── End game overlay ─────────────────────────────────────────────────────────
class _EndOverlay extends StatelessWidget {
  final bool won;
  final int score;
  final int wave;
  final bool newRecord;
  final VoidCallback onRestart;
  final VoidCallback onExit;

  const _EndOverlay({
    required this.won,
    required this.score,
    required this.wave,
    required this.newRecord,
    required this.onRestart,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(200),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                won ? '✦ Vitória! ✦' : '☠ Game Over ☠',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: won
                      ? const Color(0xFFFFD700)
                      : const Color(0xFFFF6B6B),
                ),
              ),
              const SizedBox(height: 10),
              if (newRecord)
                const Text(
                  '🏆 Novo Recorde!',
                  style: TextStyle(fontSize: 16, color: Color(0xFFFFD700)),
                ),
              const SizedBox(height: 6),
              Text(
                'Pontuação: $score',
                style: const TextStyle(fontSize: 18, color: Colors.white70),
              ),
              Text(
                'Wave: $wave',
                style: const TextStyle(fontSize: 14, color: Colors.white38),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton.icon(
                    onPressed: onRestart,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reiniciar'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: onExit,
                    icon: const Icon(Icons.map_rounded),
                    label: const Text('Mapas'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
