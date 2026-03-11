import 'package:shared_preferences/shared_preferences.dart';

// ─── Player Progress / Save Manager ──────────────────────────────────────────
class SaveManager {
  static const _keyHighScore = 'high_score';
  static const _keyTotalCoins = 'total_coins';
  static const _keyUnlocked = 'unlocked_maps';
  static const _keyBestWave = 'best_wave';

  final SharedPreferences _prefs;

  SaveManager._(this._prefs);

  static Future<SaveManager> load() async {
    final p = await SharedPreferences.getInstance();
    return SaveManager._(p);
  }

  // ─── High Score ────────────────────────────────────────────────────────────
  int get highScore => _prefs.getInt(_keyHighScore) ?? 0;

  Future<bool> submitScore(int score) async {
    if (score > highScore) {
      await _prefs.setInt(_keyHighScore, score);
      return true; // new record
    }
    return false;
  }

  // ─── Total Coins ───────────────────────────────────────────────────────────
  int get totalCoinsEarned => _prefs.getInt(_keyTotalCoins) ?? 0;

  Future<void> addCoins(int amount) async {
    await _prefs.setInt(_keyTotalCoins, totalCoinsEarned + amount);
  }

  // ─── Unlocked Maps ─────────────────────────────────────────────────────────
  Set<int> get unlockedMaps {
    final raw = _prefs.getStringList(_keyUnlocked) ?? ['0'];
    return raw.map(int.parse).toSet();
  }

  Future<void> unlockMap(int id) async {
    final current = unlockedMaps;
    current.add(id);
    await _prefs.setStringList(
      _keyUnlocked,
      current.map((e) => e.toString()).toList(),
    );
  }

  bool isMapUnlocked(int id) => unlockedMaps.contains(id);

  // ─── Best Wave per map ─────────────────────────────────────────────────────
  int bestWave(int mapId) => _prefs.getInt('${_keyBestWave}_$mapId') ?? 0;

  Future<void> submitWave(int mapId, int wave) async {
    if (wave > bestWave(mapId)) {
      await _prefs.setInt('${_keyBestWave}_$mapId', wave);
    }
  }
}
