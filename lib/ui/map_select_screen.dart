import 'package:flutter/material.dart';
import '../core/colors.dart';
import '../core/maps.dart';
import '../core/save_manager.dart';
import 'game_page.dart';

class MapSelectScreen extends StatefulWidget {
  final SaveManager save;

  const MapSelectScreen({super.key, required this.save});

  @override
  State<MapSelectScreen> createState() => _MapSelectScreenState();
}

class _MapSelectScreenState extends State<MapSelectScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RuneColors.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2238),
        title: const Text(
          '\u2694 Última Muralha \u2694',
          style: TextStyle(
            color: Color(0xFFBDB0FF),
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 2.0,
            shadows: [Shadow(color: Color(0x887B5CF0), blurRadius: 14)],
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Player Stats Banner
            _StatsBanner(save: widget.save),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    'Selecione o Mapa',
                    style: TextStyle(
                      color: Colors.white.withAlpha(200),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: RuneColors.infiniteAccent.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: RuneColors.infiniteAccent.withAlpha(140),
                        width: 1,
                      ),
                    ),
                    child: const Text(
                      '\u221e modo infinito disponível',
                      style: TextStyle(
                        color: RuneColors.infiniteAccent,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: kMaps.length,
                itemBuilder: (ctx, i) {
                  final map = kMaps[i];
                  final unlocked = widget.save.isMapUnlocked(map.id);
                  final best = widget.save.bestWave(map.id);
                  return _MapCard(
                    map: map,
                    unlocked: unlocked,
                    bestWave: best,
                    onTap: unlocked
                        ? () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  GamePage(map: map, save: widget.save),
                            ),
                          )
                        : null,
                    onInfiniteTap: unlocked
                        ? () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => GamePage(
                                map: map,
                                save: widget.save,
                                infiniteMode: true,
                              ),
                            ),
                          )
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsBanner extends StatelessWidget {
  final SaveManager save;
  const _StatsBanner({required this.save});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1440), Color(0xFF111830)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: RuneColors.accent.withAlpha(80)),
        boxShadow: [
          BoxShadow(
            color: RuneColors.accent.withAlpha(40),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _Stat(
            icon: Icons.stars_rounded,
            label: 'Recorde',
            value: '${save.highScore}',
          ),
          _Stat(
            icon: Icons.monetization_on_rounded,
            label: 'Moedas Totais',
            value: '${save.totalCoinsEarned}',
          ),
          _Stat(
            icon: Icons.map_rounded,
            label: 'Mapas',
            value: '${save.unlockedMaps.length}/${kMaps.length}',
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _Stat({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: RuneColors.accent, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 10),
        ),
      ],
    );
  }
}

class _MapCard extends StatelessWidget {
  final MapDef map;
  final bool unlocked;
  final int bestWave;
  final VoidCallback? onTap;
  final VoidCallback? onInfiniteTap;

  const _MapCard({
    required this.map,
    required this.unlocked,
    required this.bestWave,
    required this.onTap,
    this.onInfiniteTap,
  });

  @override
  Widget build(BuildContext context) {
    final col = unlocked ? map.themeColor : RuneColors.mapLocked;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: unlocked ? RuneColors.mapUnlocked : RuneColors.mapLocked,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: unlocked ? col.withAlpha(150) : Colors.white12,
            width: 1.5,
          ),
          boxShadow: unlocked
              ? [
                  BoxShadow(
                    color: col.withAlpha(60),
                    blurRadius: 14,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            // Map emoji + glow
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: col.withAlpha(30),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: col.withAlpha(100), width: 1),
              ),
              child: Center(
                child: Text(
                  map.emoji,
                  style: TextStyle(
                    fontSize: 28,
                    color: unlocked ? Colors.white : Colors.white38,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    map.name,
                    style: TextStyle(
                      color: unlocked ? Colors.white : Colors.white38,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    map.description,
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  if (unlocked && bestWave > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Melhor wave: $bestWave',
                      style: TextStyle(color: col, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
            if (!unlocked)
              const Icon(
                Icons.lock_outline_rounded,
                color: Colors.white24,
                size: 26,
              )
            else
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Icon(Icons.arrow_forward_ios_rounded, color: col, size: 18),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: onInfiniteTap,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: RuneColors.infiniteAccent.withAlpha(28),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: RuneColors.infiniteAccent.withAlpha(160),
                          width: 1,
                        ),
                      ),
                      child: const Text(
                        '\u221e',
                        style: TextStyle(
                          color: RuneColors.infiniteAccent,
                          fontSize: 15,
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
    );
  }
}
