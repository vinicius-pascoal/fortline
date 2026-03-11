import 'dart:math' as math;
import 'package:flutter/material.dart';

// ─── Map Definition ───────────────────────────────────────────────────────────
class MapDef {
  final int id;
  final String name;
  final String description;
  final String emoji;
  final Color themeColor;
  final Color pathColor;
  final Color boardColor;
  final int rows;
  final int cols;
  final List<math.Point<int>> pathCells;
  final int startCoins;
  final int startLives;
  final int wavesCount; // waves to beat to unlock next
  final double difficultyMult; // enemy hp/speed multiplier

  const MapDef({
    required this.id,
    required this.name,
    required this.description,
    required this.emoji,
    required this.themeColor,
    required this.pathColor,
    required this.boardColor,
    required this.rows,
    required this.cols,
    required this.pathCells,
    required this.startCoins,
    required this.startLives,
    required this.wavesCount,
    required this.difficultyMult,
  });

  Set<String> get pathCellSet =>
      pathCells.map<String>((p) => '${p.y}_${p.x}').toSet();

  List<Offset> get pathPoints => pathCells
      .map<Offset>((p) => Offset(p.x + 0.5, p.y + 0.5))
      .toList(growable: false);

  /// Retorna true se a célula (row, col) está disponível para construção.
  ///
  /// Regras:
  ///  1. Deve ser ortogonalmente adjacente ao caminho (distância Manhattan = 1,
  ///     sem diagonais).
  ///  2. A célula do caminho adjacente não pode pertencer à **zona de entrada**
  ///     (primeiros [entryExclude] nós) nem à **zona de saída** (últimos
  ///     [exitExclude] nós), evitando que o jogador empilhe torres no começo.
  bool isBuildable(int row, int col) {
    if (row < 0 || row >= rows || col < 0 || col >= cols) return false;
    for (final p in pathCells) {
      if (p.y == row && p.x == col) return false; // sobre o caminho
    }

    const entryExclude = 5; // primeiros nós bloqueados para construção
    const exitExclude = 2; // últimos nós bloqueados para construção
    final start = entryExclude.clamp(0, pathCells.length);
    final end = (pathCells.length - exitExclude).clamp(start, pathCells.length);

    for (int i = start; i < end; i++) {
      final p = pathCells[i];
      final dr = (p.y - row).abs();
      final dc = (p.x - col).abs();
      // adjacência ortogonal estrita (sem diagonal)
      if (dr + dc == 1) return true;
    }
    return false;
  }
}

// ─── Map 1: Floresta Sombria ──────────────────────────────────────────────────
const _map1Path = [
  math.Point(0, 2),
  math.Point(1, 2),
  math.Point(2, 2),
  math.Point(3, 2),
  math.Point(3, 3),
  math.Point(3, 4),
  math.Point(3, 5),
  math.Point(4, 5),
  math.Point(5, 5),
  math.Point(6, 5),
  math.Point(6, 4),
  math.Point(6, 3),
  math.Point(6, 2),
  math.Point(7, 2),
  math.Point(8, 2),
  math.Point(9, 2),
  math.Point(10, 2),
  math.Point(11, 2),
];

// ─── Map 2: Ruínas Arcanas ────────────────────────────────────────────────────
// Rota em S duplo
const _map2Path = [
  math.Point(0, 1),
  math.Point(1, 1),
  math.Point(2, 1),
  math.Point(2, 2),
  math.Point(2, 3),
  math.Point(2, 4),
  math.Point(2, 5),
  math.Point(3, 5),
  math.Point(4, 5),
  math.Point(4, 4),
  math.Point(4, 3),
  math.Point(4, 2),
  math.Point(4, 1),
  math.Point(5, 1),
  math.Point(6, 1),
  math.Point(6, 2),
  math.Point(6, 3),
  math.Point(6, 4),
  math.Point(6, 5),
  math.Point(7, 5),
  math.Point(7, 6),
  math.Point(7, 7),
  math.Point(7, 8),
  math.Point(7, 9),
  math.Point(7, 10),
  math.Point(7, 11),
];

// ─── Map 3: Abismo Vulcânico ──────────────────────────────────────────────────
// Rota em espiral/zigue-zague aggressivo
const _map3Path = [
  math.Point(0, 0),
  math.Point(1, 0),
  math.Point(2, 0),
  math.Point(3, 0),
  math.Point(3, 1),
  math.Point(3, 2),
  math.Point(3, 3),
  math.Point(3, 4),
  math.Point(2, 4),
  math.Point(1, 4),
  math.Point(0, 4),
  math.Point(0, 5),
  math.Point(0, 6),
  math.Point(1, 6),
  math.Point(2, 6),
  math.Point(3, 6),
  math.Point(4, 6),
  math.Point(5, 6),
  math.Point(5, 5),
  math.Point(5, 4),
  math.Point(5, 3),
  math.Point(5, 2),
  math.Point(5, 1),
  math.Point(6, 1),
  math.Point(7, 1),
  math.Point(7, 2),
  math.Point(7, 3),
  math.Point(7, 4),
  math.Point(7, 5),
  math.Point(7, 6),
  math.Point(7, 7),
  math.Point(7, 8),
  math.Point(7, 9),
  math.Point(7, 10),
  math.Point(7, 11),
];

// ─── All Maps ─────────────────────────────────────────────────────────────────
const List<MapDef> kMaps = [
  MapDef(
    id: 0,
    name: 'Floresta Sombria',
    description: 'Tutorial — rota simples',
    emoji: '\u1f311',
    themeColor: Color(0xFF4CAF50),
    pathColor: Color(0xFF2D5C36),
    boardColor: Color(0xFF1A2E1C),
    rows: 8,
    cols: 12,
    pathCells: _map1Path,
    startCoins: 220,
    startLives: 20,
    wavesCount: 8,
    difficultyMult: 1.0,
  ),
  MapDef(
    id: 1,
    name: 'Ruínas Arcanas',
    description: 'Rota em duplo S — intermediário',
    emoji: '🏰',
    themeColor: Color(0xFF9C27B0),
    pathColor: Color(0xFF4A1870),
    boardColor: Color(0xFF221035),
    rows: 8,
    cols: 12,
    pathCells: _map2Path,
    startCoins: 200,
    startLives: 15,
    wavesCount: 10,
    difficultyMult: 1.3,
  ),
  MapDef(
    id: 2,
    name: 'Abismo Vulcânico',
    description: 'Labirinto apertado — difícil',
    emoji: '🌋',
    themeColor: Color(0xFFE64A19),
    pathColor: Color(0xFF6B2208),
    boardColor: Color(0xFF2A1200),
    rows: 8,
    cols: 12,
    pathCells: _map3Path,
    startCoins: 180,
    startLives: 10,
    wavesCount: 12,
    difficultyMult: 1.7,
  ),
];

// ─── Helper: compute path points + cumulative lengths ────────────────────────
class PathData {
  final List<Offset> points;
  final List<double> cumLengths;
  final double totalLength;

  const PathData({
    required this.points,
    required this.cumLengths,
    required this.totalLength,
  });

  factory PathData.fromMap(MapDef map) {
    final pts = map.pathPoints;
    final lengths = [0.0];
    double total = 0;
    for (int i = 0; i < pts.length - 1; i++) {
      total += (pts[i + 1] - pts[i]).distance;
      lengths.add(total);
    }
    return PathData(points: pts, cumLengths: lengths, totalLength: total);
  }

  Offset resolve(double distance) {
    if (distance <= 0) return points.first;
    if (distance >= totalLength) return points.last;
    for (int i = 0; i < cumLengths.length - 1; i++) {
      if (distance <= cumLengths[i + 1]) {
        final t =
            (distance - cumLengths[i]) / (cumLengths[i + 1] - cumLengths[i]);
        return Offset.lerp(points[i], points[i + 1], t)!;
      }
    }
    return points.last;
  }
}
