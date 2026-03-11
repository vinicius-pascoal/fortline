import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

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
        scaffoldBackgroundColor: const Color(0xFF0E1320),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5C8DFF),
          brightness: Brightness.dark,
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
  static const int towerCost = 60;

  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;

  final List<GridTower> _towers = [];
  final List<Enemy> _enemies = [];
  final List<Projectile> _projectiles = [];

  late final List<Offset> _pathPoints;
  late final List<double> _pathCumulativeLengths;
  late final Set<String> _pathCells;
  late final double _pathLength;

  int _coins = 180;
  int _lives = 20;
  int _score = 0;
  int _wave = 1;

  int _remainingToSpawn = 0;
  double _spawnTimer = 0;
  double _nextWaveTimer = 0;
  bool _gameOver = false;
  bool _running = true;

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

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _lastElapsed).inMicroseconds / 1e6)
        .clamp(0.0, 0.033)
        .toDouble();
    _lastElapsed = elapsed;

    if (!_running || _gameOver) {
      if (mounted) {
        setState(() {});
      }
      return;
    }

    _updateWave(dt);
    _updateEnemies(dt);
    _updateTowers(dt);
    _updateProjectiles(dt);
    _cleanup();

    if (mounted) {
      setState(() {});
    }
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
    final double lifeScale = 1 + (_wave - 1) * 0.18;
    final double speedScale = 1 + (_wave - 1) * 0.03;

    _enemies.add(
      Enemy(
        maxHp: 35 * lifeScale,
        hp: 35 * lifeScale,
        speed: 1.15 * speedScale,
        reward: 12 + (_wave * 2),
      ),
    );

    if (_remainingToSpawn == 1) {
      _nextWaveTimer = 2.0;
    }
  }

  void _updateEnemies(double dt) {
    for (final enemy in _enemies) {
      if (!enemy.alive) continue;

      enemy.distance += enemy.speed * dt;

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

      Enemy? target;
      double bestDistance = double.infinity;

      for (final enemy in _enemies) {
        if (!enemy.alive || enemy.hp <= 0) continue;

        final enemyPos = _positionAlongPath(enemy.distance);
        final dist = (enemyPos - tower.center).distance;

        if (dist <= tower.range && dist < bestDistance) {
          bestDistance = dist;
          target = enemy;
        }
      }

      if (target != null) {
        _projectiles.add(
          Projectile(
            position: tower.center,
            target: target,
            speed: 8.8,
            damage: tower.damage,
          ),
        );
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
        target.hp -= projectile.damage;
        projectile.dead = true;

        if (target.hp <= 0 && target.alive) {
          target.alive = false;
          _coins += target.reward;
          _score += 25;
        }
        continue;
      }

      final step = projectile.speed * dt;
      if (step >= distance) {
        projectile.position = targetPos;
      } else {
        projectile.position += direction / distance * step;
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
      final startDistance = _pathCumulativeLengths[i];
      final endDistance = _pathCumulativeLengths[i + 1];

      if (distance <= endDistance) {
        final t = (distance - startDistance) / (endDistance - startDistance);
        return Offset.lerp(_pathPoints[i], _pathPoints[i + 1], t)!;
      }
    }

    return _pathPoints.last;
  }

  GridTower? _towerAt(int row, int col) {
    for (final tower in _towers) {
      if (tower.row == row && tower.col == col) {
        return tower;
      }
    }
    return null;
  }

  void _onBoardTap(Offset localPosition, Size size) {
    if (_gameOver) return;

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

    if (_coins >= towerCost) {
      setState(() {
        _coins -= towerCost;
        _towers.add(GridTower(row: row, col: col));
      });
    }
  }

  void _resetGame() {
    setState(() {
      _coins = 180;
      _lives = 20;
      _score = 0;
      _wave = 1;
      _remainingToSpawn = 0;
      _spawnTimer = 0;
      _nextWaveTimer = 0;
      _gameOver = false;
      _running = true;
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

  @override
  Widget build(BuildContext context) {
    final infoStyle = Theme.of(context).textTheme.titleMedium;

    return Scaffold(
      appBar: AppBar(title: const Text('Última Muralha'), centerTitle: true),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _HudCard(
                    label: 'Moedas',
                    value: '$_coins',
                    icon: Icons.monetization_on_rounded,
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Toque em um bloco vazio para construir uma torre ($towerCost moedas). '
                'Toque em uma torre existente para melhorar.',
                style: infoStyle?.copyWith(color: Colors.white70, fontSize: 14),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
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
                            onTapDown: (details) =>
                                _onBoardTap(details.localPosition, boardSize),
                            child: CustomPaint(
                              painter: BoardPainter(
                                rows: rows,
                                cols: cols,
                                pathCells: _pathCells,
                                towers: _towers,
                                enemies: _enemies,
                                projectiles: _projectiles,
                                pathPositionResolver: _positionAlongPath,
                              ),
                              child: const SizedBox.expand(),
                            ),
                          ),
                          if (_gameOver)
                            Positioned.fill(
                              child: Container(
                                color: Colors.black.withValues(alpha: 0.72),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'Game Over',
                                        style: TextStyle(
                                          fontSize: 36,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Pontuação: $_score',
                                        style: const TextStyle(fontSize: 18),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        setState(() {
                          _running = !_running;
                        });
                      },
                      icon: Icon(
                        _running
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      label: Text(_running ? 'Pausar' : 'Continuar'),
                    ),
                  ),
                  const SizedBox(width: 12),
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
      width: 155,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF151D30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class GridTower {
  final int row;
  final int col;
  int level;
  double cooldown;

  GridTower({
    required this.row,
    required this.col,
    this.level = 1,
    this.cooldown = 0,
  });

  Offset get center => Offset(col + 0.5, row + 0.5);

  double get range => 2.0 + (level - 1) * 0.35;

  double get damage => 18 + (level - 1) * 10;

  double get fireInterval =>
      math.max(0.18, 0.85 - (level - 1) * 0.08).toDouble();

  int get upgradeCost => 40 + level * 30;
}

class Enemy {
  double distance;
  double speed;
  double hp;
  double maxHp;
  int reward;
  bool alive;

  Enemy({
    this.distance = 0,
    required this.speed,
    required this.hp,
    required this.maxHp,
    required this.reward,
    this.alive = true,
  });
}

class Projectile {
  Offset position;
  Enemy? target;
  double speed;
  double damage;
  bool dead;

  Projectile({
    required this.position,
    required this.target,
    required this.speed,
    required this.damage,
    this.dead = false,
  });
}

class BoardPainter extends CustomPainter {
  final int rows;
  final int cols;
  final Set<String> pathCells;
  final List<GridTower> towers;
  final List<Enemy> enemies;
  final List<Projectile> projectiles;
  final Offset Function(double distance) pathPositionResolver;

  BoardPainter({
    required this.rows,
    required this.cols,
    required this.pathCells,
    required this.towers,
    required this.enemies,
    required this.projectiles,
    required this.pathPositionResolver,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cellWidth = size.width / cols;
    final cellHeight = size.height / rows;

    final backgroundPaint = Paint()..color = const Color(0xFF0F1728);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)),
      backgroundPaint,
    );

    final pathPaint = Paint()..color = const Color(0xFF2C4068);
    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        if (!pathCells.contains('${row}_$col')) continue;

        final rect = Rect.fromLTWH(
          col * cellWidth,
          row * cellHeight,
          cellWidth,
          cellHeight,
        );

        canvas.drawRect(rect.deflate(1), pathPaint);
      }
    }

    final gridPaint = Paint()
      ..color = Colors.white10
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int row = 0; row <= rows; row++) {
      final y = row * cellHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (int col = 0; col <= cols; col++) {
      final x = col * cellWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    for (final tower in towers) {
      final center = Offset(
        (tower.col + 0.5) * cellWidth,
        (tower.row + 0.5) * cellHeight,
      );

      final baseRadius = math.min(cellWidth, cellHeight) * 0.30;

      final basePaint = Paint()..color = const Color(0xFF7C9CFF);
      final corePaint = Paint()..color = const Color(0xFFDDE5FF);
      final barrelPaint = Paint()
        ..color = const Color(0xFFAFBEFF)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;

      canvas.drawCircle(center, baseRadius, basePaint);
      canvas.drawCircle(center, baseRadius * 0.48, corePaint);
      canvas.drawLine(
        center,
        Offset(center.dx, center.dy - baseRadius * 1.1),
        barrelPaint,
      );

      final levelPainter = TextPainter(
        text: TextSpan(
          text: '${tower.level}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      levelPainter.paint(
        canvas,
        Offset(
          center.dx - levelPainter.width / 2,
          center.dy + baseRadius * 0.9,
        ),
      );
    }

    for (final enemy in enemies) {
      if (!enemy.alive) continue;

      final gridPos = pathPositionResolver(enemy.distance);
      final center = Offset(gridPos.dx * cellWidth, gridPos.dy * cellHeight);

      final radius = math.min(cellWidth, cellHeight) * 0.22;
      final bodyPaint = Paint()..color = const Color(0xFFFF6B6B);
      final innerPaint = Paint()..color = const Color(0xFFFFB3B3);

      canvas.drawCircle(center, radius, bodyPaint);
      canvas.drawCircle(center, radius * 0.45, innerPaint);

      final hpPercent = (enemy.hp / enemy.maxHp).clamp(0.0, 1.0);
      final barWidth = cellWidth * 0.56;
      final barHeight = 5.0;

      final barBackground = Rect.fromCenter(
        center: Offset(center.dx, center.dy - radius - 10),
        width: barWidth,
        height: barHeight,
      );

      final barFill = Rect.fromLTWH(
        barBackground.left,
        barBackground.top,
        barBackground.width * hpPercent,
        barBackground.height,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(barBackground, const Radius.circular(3)),
        Paint()..color = Colors.black54,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(barFill, const Radius.circular(3)),
        Paint()..color = const Color(0xFF62F2A2),
      );
    }

    final projectilePaint = Paint()..color = const Color(0xFFFFE08A);
    for (final projectile in projectiles) {
      final center = Offset(
        projectile.position.dx * cellWidth,
        projectile.position.dy * cellHeight,
      );

      canvas.drawCircle(center, 4, projectilePaint);
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white12,
    );
  }

  @override
  bool shouldRepaint(covariant BoardPainter oldDelegate) => true;
}
