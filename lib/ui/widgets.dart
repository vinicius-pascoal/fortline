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
  final int wave;
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
    required this.wave,
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
    const menuH = 340.0;

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
            color: const Color(0xF2242A44),
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
              ...kTowerDefs
                  .where((def) => def.minWave <= wave)
                  .map(
                    (def) => _TowerRow(
                      def: def,
                      affordable: coins >= def.cost,
                      onTap: () => onPick(def.type),
                    ),
                  ),
              if (wave < 5)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '🌩 Raios disponível na wave 5',
                    style: TextStyle(
                      color: Colors.amber.withAlpha(160),
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                    ),
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

// ─── Tower action overlay ─────────────────────────────────────────────────────
class TowerActionOverlay extends StatelessWidget {
  final GridTower tower;
  final Size boardSize;
  final int rows;
  final int cols;
  final int coins;
  final VoidCallback onUpgrade;
  final VoidCallback onSell;
  final VoidCallback onClose;

  const TowerActionOverlay({
    super.key,
    required this.tower,
    required this.boardSize,
    required this.rows,
    required this.cols,
    required this.coins,
    required this.onUpgrade,
    required this.onSell,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final cw = boardSize.width / cols;
    final ch = boardSize.height / rows;
    final cx = (tower.col + 0.5) * cw;
    final cy = (tower.row + 0.5) * ch;

    const menuW = 200.0;
    const menuH = 160.0;

    double left = cx - menuW / 2;
    double top = cy + ch * 0.6;
    if (left < 4) left = 4;
    if (left + menuW > boardSize.width - 4) left = boardSize.width - menuW - 4;
    if (top + menuH > boardSize.height - 4) top = cy - ch * 0.5 - menuH;
    if (top < 4) top = 4;

    final def = kTowerDefs.firstWhere((d) => d.type == tower.type);
    final canUpgrade = coins >= tower.upgradeCost;

    return Positioned(
      left: left,
      top: top,
      width: menuW,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xF2242A44),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: def.color.withAlpha(180), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: def.color.withAlpha(70),
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
                  Text(
                    '${def.emoji} ${def.name} Lv.${tower.level}',
                    style: TextStyle(
                      color: def.color,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  GestureDetector(
                    onTap: onClose,
                    child: const Icon(
                      Icons.close,
                      color: Colors.white38,
                      size: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: canUpgrade ? onUpgrade : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: canUpgrade
                            ? RuneColors.accent
                            : Colors.white12,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        '↑ ${tower.upgradeCost}🪙',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: canUpgrade ? Colors.white : Colors.white30,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onSell,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.amber,
                        side: const BorderSide(color: Colors.amber, width: 1),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Vender ${tower.sellValue}🪙',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
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

// ─── HUD Card ─────────────────────────────────────────────────────────────────
class HudCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? iconColor;

  const HudCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final icoColor = iconColor ?? RuneColors.accent;
    return Container(
      width: 82,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [RuneColors.hudCard, const Color(0xFF0A1020)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: icoColor.withAlpha(80)),
        boxShadow: [
          BoxShadow(
            color: icoColor.withAlpha(35),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: icoColor),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
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
