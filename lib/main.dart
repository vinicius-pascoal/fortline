import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

// ─── Paleta mágica/rúnica ────────────────────────────────────────────────────
class RuneColors {
  static const background = Color(0xFF0A0D1A);
  static const boardBg = Color(0xFF0D1022);
  static const pathTile = Color(0xFF1C2544);
  static const gridLine = Color(0x1A8899CC);
  static const hudCard = Color(0xFF111830);
  static const accent = Color(0xFF7B5CF0);

  // torres
  static const towerSniper = Color(0xFF00E5FF);
  static const towerSplash = Color(0xFFFF6D00);
  static const towerFast = Color(0xFF76FF03);
  static const towerSlow = Color(0xFFAA00FF);
  static const towerCore = Color(0xFFEDE7F6);

  // inimigos
  static const enemyNormal = Color(0xFFFF5252);
  static const enemyFast = Color(0xFFFFD740);
  static const enemyTank = Color(0xFF69F0AE);
  static const enemyFlying = Color(0xFF40C4FF);
  static const enemyRegen = Color(0xFFEA80FC);

  // projéteis
  static const projSniper = Color(0xFF00E5FF);
  static const projSplash = Color(0xFFFF6D00);
  static const projFast = Color(0xFF76FF03);
  static const projSlow = Color(0xFFCE93D8);

  static const hpBar = Color(0xFF62F2A2);
  static const hpBarLow = Color(0xFFFF5252);
}

// ─── Tipos ───────────────────────────────────────────────────────────────────
enum TowerType { sniper, splash, fast, slow }

enum EnemyType { normal, fast, tank, flying, regen }

// ─── Dados estáticos das torres ──────────────────────────────────────────────
class TowerDef {
  final TowerType type;
  final String name;
  final String emoji;
  final int cost;
  final Color color;
  final String description;

  const TowerDef({
    required this.type,
    required this.name,
    required this.emoji,
    required this.cost,
    required this.color,
    required this.description,
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
  ),
  TowerDef(
    type: TowerType.splash,
    name: 'Splash',
    emoji: '🔶',
    cost: 100,
    color: RuneColors.towerSplash,
    description: 'Dano em área',
  ),
  TowerDef(
    type: TowerType.fast,
    name: 'Rápida',
    emoji: '🟢',
    cost: 60,
    color: RuneColors.towerFast,
    description: 'Ataque muito veloz',
  ),
  TowerDef(
    type: TowerType.slow,
    name: 'Lenta',
    emoji: '🟣',
    cost: 70,
    color: RuneColors.towerSlow,
    description: 'Lentifica inimigos',
  ),
];

void main() {
  runApp(const TowerDefenseApp());
}

class TowerDefenseApp extends StatelessWidget {
  const TowerDefenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Última Muralha',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: RuneColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: RuneColors.accent,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0D1022),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const TowerDefensePage(),
    );
  }
}

class TowerDefensePage extends StatefulWidget {
  const TowerDefensePage({super.key});

  @override
  State<TowerDefensePage> createState() => _TowerDefensePageState();
}

class _TowerDefensePageState extends State<TowerDefensePage>
    with SingleTickerProviderStateMixin {
  static const int rows = 8;
  static const int cols = 12;

  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;

  final List<GridTower> _towers = [];
  final List<Enemy> _enemies = [];
  final List<Projectile> _projectiles = [];

  late final List<Offset> _pathPoints;
  late final List<double> _pathCumulativeLengths;
  late final Set<String> _pathCells;
  late final double _pathLength;

  int _coins = 220;
  int _lives = 20;
  int _score = 0;
  int _wave = 1;

  int _remainingToSpawn = 0;
  double _spawnTimer = 0;
  double _nextWaveTimer = 0;
  bool _gameOver = false;
  bool _running = true;

  // menu de seleção de torre
  int? _pendingRow;
  int? _pendingCol;
  Size _boardSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _initPath();
    _startWave(_wave);
    _ticker = createTicker(_tick)..start();
  }

  void _initPath() {
    final pathCells = <math.Point<int>>[
      const math.Point(0, 3),
      const math.Point(1, 3),
      const math.Point(2, 3),
      const math.Point(3, 3),
      const math.Point(3, 4),
      const math.Point(3, 5),
      const math.Point(4, 5),
      const math.Point(5, 5),
      const math.Point(6, 5),
      const math.Point(6, 4),
      const math.Point(6, 3),
      const math.Point(6, 2),
      const math.Point(7, 2),
      const math.Point(8, 2),
      const math.Point(9, 2),
      const math.Point(10, 2),
      const math.Point(11, 2),
    ];

    _pathPoints = pathCells
        .map<Offset>((p) => Offset(p.x.toDouble() + 0.5, p.y.toDouble() + 0.5))
        .toList(growable: false);

    _pathCells = pathCells.map<String>((p) => '${p.y}_${p.x}').toSet();

    _pathCumulativeLengths = [0.0];
    double total = 0.0;
    for (int i = 0; i < _pathPoints.length - 1; i++) {
      total += (_pathPoints[i + 1] - _pathPoints[i]).distance;
      _pathCumulativeLengths.add(total);
    }
    _pathLength = total;
  }

  void _startWave(int wave) {
    _remainingToSpawn = 5 + wave * 2;
    _spawnTimer = 0.2;
  }

  // ─── Tick ──────────────────────────────────────────────────────────────────
  void _tick(Duration elapsed) {
    final dt = ((elapsed - _lastElapsed).inMicroseconds / 1e6)
        .clamp(0.0, 0.033)
        .toDouble();
    _lastElapsed = elapsed;

    if (!_running || _gameOver) {
      if (mounted) setState(() {});
      return;
    }

    _updateWave(dt);
    _updateEnemies(dt);
    _updateTowers(dt);
    _updateProjectiles(dt);
    _cleanup();

    if (mounted) setState(() {});
  }

  void _updateWave(double dt) {
    if (_remainingToSpawn > 0) {
      _spawnTimer -= dt;
      if (_spawnTimer <= 0) {
        _spawnEnemy();
        _remainingToSpawn--;
        _spawnTimer = math.max(0.28, 0.85 - (_wave * 0.03)).toDouble();
      }
      return;
    }
    if (_enemies.isEmpty) {
      _nextWaveTimer -= dt;
      if (_nextWaveTimer <= 0) {
        _wave++;
        _nextWaveTimer = 2.0;
        _startWave(_wave);
      }
    }
  }

  void _spawnEnemy() {
    final rng = math.Random();
    final double lifeScale = 1 + (_wave - 1) * 0.18;
    final double speedScale = 1 + (_wave - 1) * 0.03;

    // a partir da wave 2, sorteia variantes
    EnemyType type = EnemyType.normal;
    if (_wave >= 2) {
      final r = rng.nextDouble();
      if (_wave >= 5 && r < 0.15)
        type = EnemyType.regen;
      else if (_wave >= 4 && r < 0.30)
        type = EnemyType.flying;
      else if (_wave >= 3 && r < 0.50)
        type = EnemyType.tank;
      else if (r < 0.65)
        type = EnemyType.fast;
    }

    double hp, speed;
    int reward;
    bool flying = false;

    switch (type) {
      case EnemyType.normal:
        hp = 35 * lifeScale;
        speed = 1.15 * speedScale;
        reward = 12 + _wave * 2;
      case EnemyType.fast:
        hp = 20 * lifeScale;
        speed = 2.2 * speedScale;
        reward = 15 + _wave * 2;
      case EnemyType.tank:
        hp = 120 * lifeScale;
        speed = 0.65 * speedScale;
        reward = 30 + _wave * 3;
      case EnemyType.flying:
        hp = 28 * lifeScale;
        speed = 1.6 * speedScale;
        reward = 20 + _wave * 2;
        flying = true;
      case EnemyType.regen:
        hp = 50 * lifeScale;
        speed = 1.0 * speedScale;
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

  void _updateEnemies(double dt) {
    for (final enemy in _enemies) {
      if (!enemy.alive) continue;

      enemy.distance += enemy.speed * dt;

      // regeneração
      if (enemy.type == EnemyType.regen && enemy.hp < enemy.maxHp) {
        enemy.hp = math.min(enemy.maxHp, enemy.hp + enemy.maxHp * 0.04 * dt);
      }

      if (enemy.distance >= _pathLength) {
        enemy.alive = false;
        _lives--;
        if (_lives <= 0) {
          _lives = 0;
          _gameOver = true;
          _running = false;
        }
      }
    }
  }

  void _updateTowers(double dt) {
    for (final tower in _towers) {
      tower.cooldown -= dt;
      if (tower.cooldown > 0) continue;

      // torres lentas não acertam voadores
      final canHitFlying = tower.type != TowerType.slow;

      Enemy? target;
      double bestProgress = -1;

      for (final enemy in _enemies) {
        if (!enemy.alive || enemy.hp <= 0) continue;
        if (enemy.flying && !canHitFlying) continue;

        final enemyPos = _positionAlongPath(enemy.distance);
        final dist = (enemyPos - tower.center).distance;

        if (dist <= tower.range && enemy.distance > bestProgress) {
          bestProgress = enemy.distance;
          target = enemy;
        }
      }

      if (target != null) {
        if (tower.type == TowerType.splash) {
          // splash: projétil na direção do alvo, vai causar dano em área ao chegar
          _projectiles.add(
            Projectile(
              position: tower.center,
              target: target,
              speed: 7.0,
              damage: tower.damage,
              color: RuneColors.projSplash,
              isSplash: true,
              splashRadius: tower.splashRadius,
            ),
          );
        } else {
          Color projColor;
          switch (tower.type) {
            case TowerType.sniper:
              projColor = RuneColors.projSniper;
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
              speed: tower.type == TowerType.sniper ? 14.0 : 8.8,
              damage: tower.damage,
              color: projColor,
              slowFactor: tower.type == TowerType.slow ? 0.5 : 1.0,
              slowDuration: tower.type == TowerType.slow ? 1.8 : 0.0,
            ),
          );
        }
        tower.cooldown = tower.fireInterval;
      }
    }
  }

  void _updateProjectiles(double dt) {
    for (final projectile in _projectiles) {
      if (projectile.dead) continue;

      final target = projectile.target;
      if (target == null || !target.alive || target.hp <= 0) {
        projectile.dead = true;
        continue;
      }

      final targetPos = _positionAlongPath(target.distance);
      final direction = targetPos - projectile.position;
      final distance = direction.distance;

      if (distance < 0.12) {
        if (projectile.isSplash) {
          // dano em área
          for (final e in _enemies) {
            if (!e.alive || e.hp <= 0) continue;
            final ep = _positionAlongPath(e.distance);
            if ((ep - targetPos).distance <= projectile.splashRadius) {
              e.hp -= projectile.damage;
              if (e.hp <= 0 && e.alive) {
                e.alive = false;
                _coins += e.reward;
                _score += 25;
              }
            }
          }
        } else {
          target.hp -= projectile.damage;
          // aplica lentidão
          if (projectile.slowFactor < 1.0) {
            target.slowTimer = projectile.slowDuration;
            target.slowFactor = projectile.slowFactor;
          }
          if (target.hp <= 0 && target.alive) {
            target.alive = false;
            _coins += target.reward;
            _score += 25;
          }
        }
        projectile.dead = true;
        continue;
      }

      final step = projectile.speed * dt;
      projectile.position = step >= distance
          ? targetPos
          : projectile.position + direction / distance * step;
    }

    // atualiza efeito de lentidão nos inimigos
    for (final e in _enemies) {
      if (e.slowTimer > 0) {
        e.slowTimer -= dt;
        if (e.slowTimer <= 0) {
          e.slowTimer = 0;
          e.slowFactor = 1.0;
        }
      }
    }
  }

  void _cleanup() {
    _enemies.removeWhere((e) => !e.alive);
    _projectiles.removeWhere((p) => p.dead);
  }

  Offset _positionAlongPath(double distance) {
    if (distance <= 0) return _pathPoints.first;
    if (distance >= _pathLength) return _pathPoints.last;

    for (int i = 0; i < _pathCumulativeLengths.length - 1; i++) {
      final start = _pathCumulativeLengths[i];
      final end = _pathCumulativeLengths[i + 1];
      if (distance <= end) {
        final t = (distance - start) / (end - start);
        return Offset.lerp(_pathPoints[i], _pathPoints[i + 1], t)!;
      }
    }
    return _pathPoints.last;
  }

  GridTower? _towerAt(int row, int col) {
    for (final t in _towers) {
      if (t.row == row && t.col == col) return t;
    }
    return null;
  }

  // ─── Toque no tabuleiro ────────────────────────────────────────────────────
  void _onBoardTap(Offset localPosition, Size size) {
    if (_gameOver) return;

    // fechar menu pendente se tocar fora
    if (_pendingRow != null) {
      setState(() {
        _pendingRow = null;
        _pendingCol = null;
      });
      return;
    }

    final cellWidth = size.width / cols;
    final cellHeight = size.height / rows;
    final col = (localPosition.dx / cellWidth).floor();
    final row = (localPosition.dy / cellHeight).floor();

    if (row < 0 || row >= rows || col < 0 || col >= cols) return;
    if (_pathCells.contains('${row}_$col')) return;

    final existing = _towerAt(row, col);
    if (existing != null) {
      final cost = existing.upgradeCost;
      if (_coins >= cost) {
        setState(() {
          _coins -= cost;
          existing.level++;
        });
      }
      return;
    }

    // abrir mini-menu de seleção de torre
    setState(() {
      _pendingRow = row;
      _pendingCol = col;
      _boardSize = size;
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

  void _resetGame() {
    setState(() {
      _coins = 220;
      _lives = 20;
      _score = 0;
      _wave = 1;
      _remainingToSpawn = 0;
      _spawnTimer = 0;
      _nextWaveTimer = 0;
      _gameOver = false;
      _running = true;
      _pendingRow = null;
      _pendingCol = null;
      _towers.clear();
      _enemies.clear();
      _projectiles.clear();
      _startWave(_wave);
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  // ─── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '✦ Última Muralha ✦',
          style: TextStyle(
            color: Color(0xFFBDB0FF),
            fontWeight: FontWeight.bold,
            letterSpacing: 1.8,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // HUD
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _HudCard(
                    label: 'Moedas',
                    value: '$_coins',
                    icon: Icons.auto_awesome,
                  ),
                  _HudCard(
                    label: 'Vidas',
                    value: '$_lives',
                    icon: Icons.favorite_rounded,
                  ),
                  _HudCard(
                    label: 'Wave',
                    value: '$_wave',
                    icon: Icons.waves_rounded,
                  ),
                  _HudCard(
                    label: 'Score',
                    value: '$_score',
                    icon: Icons.stars_rounded,
                  ),
                ],
              ),
            ),
            // Tabuleiro
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: AspectRatio(
                  aspectRatio: cols / rows,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final boardSize = Size(
                        constraints.maxWidth,
                        constraints.maxHeight,
                      );
                      return Stack(
                        children: [
                          GestureDetector(
                            onTapDown: (d) =>
                                _onBoardTap(d.localPosition, boardSize),
                            child: CustomPaint(
                              painter: BoardPainter(
                                rows: rows,
                                cols: cols,
                                pathCells: _pathCells,
                                towers: _towers,
                                enemies: _enemies,
                                projectiles: _projectiles,
                                pathPositionResolver: _positionAlongPath,
                                pendingRow: _pendingRow,
                                pendingCol: _pendingCol,
                              ),
                              child: const SizedBox.expand(),
                            ),
                          ),
                          // Mini-menu de seleção de torre
                          if (_pendingRow != null && _pendingCol != null)
                            _TowerPickerOverlay(
                              row: _pendingRow!,
                              col: _pendingCol!,
                              boardSize: boardSize,
                              rows: rows,
                              cols: cols,
                              coins: _coins,
                              onPick: _buildTower,
                              onCancel: () => setState(() {
                                _pendingRow = null;
                                _pendingCol = null;
                              }),
                            ),
                          // Game Over
                          if (_gameOver)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.80),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        '☠ Game Over ☠',
                                        style: TextStyle(
                                          fontSize: 34,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFFF6B6B),
                                          letterSpacing: 2,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        'Pontuação: $_score',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          color: Colors.white70,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      FilledButton.icon(
                                        onPressed: _resetGame,
                                        icon: const Icon(Icons.refresh_rounded),
                                        label: const Text('Reiniciar'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            // Controles
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
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
                      onPressed: _resetGame,
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

// ─── Overlay de seleção de torre ─────────────────────────────────────────────
class _TowerPickerOverlay extends StatelessWidget {
  final int row;
  final int col;
  final Size boardSize;
  final int rows;
  final int cols;
  final int coins;
  final void Function(TowerType) onPick;
  final VoidCallback onCancel;

  const _TowerPickerOverlay({
    required this.row,
    required this.col,
    required this.boardSize,
    required this.rows,
    required this.cols,
    required this.coins,
    required this.onPick,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final cw = boardSize.width / cols;
    final ch = boardSize.height / rows;
    final cx = (col + 0.5) * cw;
    final cy = (row + 0.5) * ch;

    const menuW = 240.0;
    const menuH = 240.0;

    double left = cx - menuW / 2;
    double top = cy + ch * 0.6;
    if (left < 4) left = 4;
    if (left + menuW > boardSize.width - 4) left = boardSize.width - menuW - 4;
    if (top + menuH > boardSize.height - 4) top = cy - ch * 0.5 - menuH;
    if (top < 4) top = 4;

    return Positioned(
      left: left,
      top: top,
      width: menuW,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xF0111830),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: RuneColors.accent.withValues(alpha: 0.7),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: RuneColors.accent.withValues(alpha: 0.3),
                blurRadius: 18,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Construir Torre',
                    style: TextStyle(
                      color: Color(0xFFBDB0FF),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 1,
                    ),
                  ),
                  GestureDetector(
                    onTap: onCancel,
                    child: const Icon(
                      Icons.close,
                      color: Colors.white38,
                      size: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...kTowerDefs.map((def) {
                final affordable = coins >= def.cost;
                return GestureDetector(
                  onTap: affordable ? () => onPick(def.type) : null,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: affordable
                          ? def.color.withValues(alpha: 0.12)
                          : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: affordable
                            ? def.color.withValues(alpha: 0.55)
                            : Colors.white12,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(def.emoji, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                def.name,
                                style: TextStyle(
                                  color: affordable
                                      ? def.color
                                      : Colors.white38,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                def.description,
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${def.cost}🪙',
                          style: TextStyle(
                            color: affordable ? Colors.amber : Colors.white24,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── HUD Card ─────────────────────────────────────────────────────────────────
class _HudCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _HudCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 82,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: RuneColors.hudCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: RuneColors.accent.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: RuneColors.accent.withValues(alpha: 0.08),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: RuneColors.accent),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

// ─── Modelos ──────────────────────────────────────────────────────────────────
class GridTower {
  final int row;
  final int col;
  final TowerType type;
  int level;
  double cooldown;

  GridTower({
    required this.row,
    required this.col,
    required this.type,
    this.level = 1,
    this.cooldown = 0,
  });

  Offset get center => Offset(col + 0.5, row + 0.5);

  double get range {
    switch (type) {
      case TowerType.sniper:
        return 4.0 + (level - 1) * 0.5;
      case TowerType.splash:
        return 2.2 + (level - 1) * 0.3;
      case TowerType.fast:
        return 1.8 + (level - 1) * 0.25;
      case TowerType.slow:
        return 2.5 + (level - 1) * 0.3;
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
    }
  }

  double get fireInterval {
    switch (type) {
      case TowerType.sniper:
        return math.max(0.5, 1.6 - (level - 1) * 0.12).toDouble();
      case TowerType.splash:
        return math.max(0.5, 1.2 - (level - 1) * 0.10).toDouble();
      case TowerType.fast:
        return math.max(0.08, 0.28 - (level - 1) * 0.03).toDouble();
      case TowerType.slow:
        return math.max(0.4, 1.0 - (level - 1) * 0.10).toDouble();
    }
  }

  double get splashRadius {
    return 1.0 + (level - 1) * 0.2;
  }

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
    }
  }
}

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
}

class Projectile {
  Offset position;
  Enemy? target;
  double speed;
  double damage;
  bool dead;
  Color color;
  bool isSplash;
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
    this.isSplash = false,
    this.splashRadius = 0,
    this.slowFactor = 1.0,
    this.slowDuration = 0,
  });
}

// ─── Painter ─────────────────────────────────────────────────────────────────
class BoardPainter extends CustomPainter {
  final int rows;
  final int cols;
  final Set<String> pathCells;
  final List<GridTower> towers;
  final List<Enemy> enemies;
  final List<Projectile> projectiles;
  final Offset Function(double) pathPositionResolver;
  final int? pendingRow;
  final int? pendingCol;

  BoardPainter({
    required this.rows,
    required this.cols,
    required this.pathCells,
    required this.towers,
    required this.enemies,
    required this.projectiles,
    required this.pathPositionResolver,
    this.pendingRow,
    this.pendingCol,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cw = size.width / cols;
    final ch = size.height / rows;

    // fundo
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)),
      Paint()..color = RuneColors.boardBg,
    );

    // células do caminho
    final pathPaint = Paint()..color = RuneColors.pathTile;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (!pathCells.contains('${r}_$c')) continue;
        canvas.drawRect(
          Rect.fromLTWH(c * cw, r * ch, cw, ch).deflate(1),
          pathPaint,
        );
      }
    }

    // grade
    final gridPaint = Paint()
      ..color = RuneColors.gridLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (int r = 0; r <= rows; r++) {
      canvas.drawLine(Offset(0, r * ch), Offset(size.width, r * ch), gridPaint);
    }
    for (int c = 0; c <= cols; c++) {
      canvas.drawLine(
        Offset(c * cw, 0),
        Offset(c * cw, size.height),
        gridPaint,
      );
    }

    // célula selecionada pendente
    if (pendingRow != null && pendingCol != null) {
      canvas.drawRect(
        Rect.fromLTWH(pendingCol! * cw, pendingRow! * ch, cw, ch).deflate(1),
        Paint()
          ..color = RuneColors.accent.withValues(alpha: 0.3)
          ..style = PaintingStyle.fill,
      );
      canvas.drawRect(
        Rect.fromLTWH(pendingCol! * cw, pendingRow! * ch, cw, ch).deflate(1),
        Paint()
          ..color = RuneColors.accent.withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // torres
    for (final tower in towers) {
      _drawTower(canvas, tower, cw, ch);
    }

    // inimigos
    for (final enemy in enemies) {
      if (!enemy.alive) continue;
      _drawEnemy(canvas, enemy, cw, ch);
    }

    // projéteis
    for (final proj in projectiles) {
      if (proj.dead) continue;
      final center = Offset(proj.position.dx * cw, proj.position.dy * ch);
      final projPaint = Paint()
        ..color = proj.color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(center, proj.isSplash ? 5.5 : 4, projPaint);
      // núcleo brilhante
      canvas.drawCircle(
        center,
        proj.isSplash ? 3 : 2,
        Paint()..color = Colors.white.withValues(alpha: 0.85),
      );
    }

    // borda
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = RuneColors.accent.withValues(alpha: 0.18),
    );
  }

  void _drawTower(Canvas canvas, GridTower tower, double cw, double ch) {
    final center = Offset((tower.col + 0.5) * cw, (tower.row + 0.5) * ch);
    final baseR = math.min(cw, ch) * 0.28;
    final col = tower.color;

    // halo rúnico
    canvas.drawCircle(
      center,
      baseR * 1.55,
      Paint()
        ..color = col.withValues(alpha: 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // base
    canvas.drawCircle(
      center,
      baseR,
      Paint()..color = col.withValues(alpha: 0.85),
    );

    // núcleo
    canvas.drawCircle(
      center,
      baseR * 0.48,
      Paint()..color = RuneColors.towerCore,
    );

    // símbolo da letra
    final tp = TextPainter(
      text: TextSpan(
        text: tower.label,
        style: TextStyle(
          color: col,
          fontSize: baseR * 0.95,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );

    // nível
    final lvl = TextPainter(
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
    lvl.paint(
      canvas,
      Offset(center.dx - lvl.width / 2, center.dy + baseR * 0.9),
    );
  }

  void _drawEnemy(Canvas canvas, Enemy enemy, double cw, double ch) {
    final gp = pathPositionResolver(enemy.distance);
    final center = Offset(gp.dx * cw, gp.dy * ch);
    final radius =
        math.min(cw, ch) * (enemy.type == EnemyType.tank ? 0.29 : 0.19);

    Color bodyColor;
    switch (enemy.type) {
      case EnemyType.normal:
        bodyColor = RuneColors.enemyNormal;
      case EnemyType.fast:
        bodyColor = RuneColors.enemyFast;
      case EnemyType.tank:
        bodyColor = RuneColors.enemyTank;
      case EnemyType.flying:
        bodyColor = RuneColors.enemyFlying;
      case EnemyType.regen:
        bodyColor = RuneColors.enemyRegen;
    }

    // lentidão: pulsar roxo
    if (enemy.slowTimer > 0) {
      canvas.drawCircle(
        center,
        radius * 1.6,
        Paint()
          ..color = RuneColors.projSlow.withValues(alpha: 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }

    // voadores: aura azul
    if (enemy.flying) {
      canvas.drawCircle(
        center,
        radius * 1.5,
        Paint()
          ..color = RuneColors.enemyFlying.withValues(alpha: 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    canvas.drawCircle(center, radius, Paint()..color = bodyColor);
    canvas.drawCircle(
      center,
      radius * 0.45,
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );

    // tanque: bordas extras
    if (enemy.type == EnemyType.tank) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = RuneColors.enemyTank
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }

    // barra de vida
    final hpPct = (enemy.hp / enemy.maxHp).clamp(0.0, 1.0);
    final barW = cw * 0.70;
    final barH = 4.5;
    final barBg = Rect.fromCenter(
      center: Offset(center.dx, center.dy - radius - 8),
      width: barW,
      height: barH,
    );
    final barFill = Rect.fromLTWH(
      barBg.left,
      barBg.top,
      barBg.width * hpPct,
      barH,
    );
    final hpColor = hpPct > 0.5 ? RuneColors.hpBar : RuneColors.hpBarLow;

    canvas.drawRRect(
      RRect.fromRectAndRadius(barBg, const Radius.circular(3)),
      Paint()..color = Colors.black54,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(barFill, const Radius.circular(3)),
      Paint()..color = hpColor,
    );
  }

  @override
  bool shouldRepaint(covariant BoardPainter old) => true;
}
