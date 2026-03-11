import 'package:flutter/material.dart';
import '../core/colors.dart';
import '../core/models.dart';

// ─── Tower picker overlay ─────────────────────────────────────────────────────
class TowerPickerOverlay extends StatelessWidget {
  final int row;
  final int col;
  final Size boardSize;
  final int rows;
  final int cols;
  final int coins;
  final void Function(TowerType) onPick;
  final VoidCallback onCancel;

  const TowerPickerOverlay({
    super.key,
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

    const menuW = 248.0;
    const menuH = 300.0;

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
            color: const Color(0xF2111830),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: RuneColors.accent.withAlpha(180),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: RuneColors.accent.withAlpha(80),
                blurRadius: 20,
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
                    '✦ Construir Torre',
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
              ...kTowerDefs.map(
                (def) => _TowerRow(
                  def: def,
                  affordable: coins >= def.cost,
                  onTap: () => onPick(def.type),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TowerRow extends StatelessWidget {
  final TowerDef def;
  final bool affordable;
  final VoidCallback onTap;

  const _TowerRow({
    required this.def,
    required this.affordable,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: affordable ? onTap : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: affordable
              ? def.color.withAlpha(30)
              : Colors.white.withAlpha(10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: affordable ? def.color.withAlpha(140) : Colors.white12,
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
                      color: affordable ? def.color : Colors.white38,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    def.description,
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
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
  }
}

// ─── HUD Card ─────────────────────────────────────────────────────────────────
class HudCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const HudCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 78,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      decoration: BoxDecoration(
        color: RuneColors.hudCard,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: RuneColors.accent.withAlpha(64)),
        boxShadow: [
          BoxShadow(color: RuneColors.accent.withAlpha(20), blurRadius: 8),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: RuneColors.accent),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 9),
          ),
        ],
      ),
    );
  }
}
