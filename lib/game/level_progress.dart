import 'package:shared_preferences/shared_preferences.dart';

class LevelProgress {
  LevelProgress._();

  static final LevelProgress instance = LevelProgress._();

  static const _highestUnlockedKey = 'highest_unlocked_level';
  static const _currentLevelKey = 'current_level';
  static const _completedLevelsKey = 'completed_levels';

  int highestUnlockedLevel = 1;
  int currentLevel = 1;
  final Set<int> completedLevels = <int>{};

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    highestUnlockedLevel = prefs.getInt(_highestUnlockedKey) ?? 1;
    currentLevel = prefs.getInt(_currentLevelKey) ?? highestUnlockedLevel;
    completedLevels
      ..clear()
      ..addAll(prefs.getStringList(_completedLevelsKey)?.map(int.parse) ?? const <int>[]);
    if (highestUnlockedLevel < 1) highestUnlockedLevel = 1;
    if (currentLevel < 1) currentLevel = 1;
  }

  bool isUnlocked(int level) => level <= highestUnlockedLevel;
  bool isCompleted(int level) => completedLevels.contains(level);
  bool isCurrent(int level) => level == highestUnlockedLevel;

  Future<void> markCompleted(int level) async {
    if (level < 1) return;
    completedLevels.add(level);
    if (level < 2500 && highestUnlockedLevel < level + 1) {
      highestUnlockedLevel = level + 1;
    }
    currentLevel = highestUnlockedLevel;
    await _save();
  }

  Future<void> markLevelOpened(int level) async {
    if (level < 1) return;
    if (level > highestUnlockedLevel) {
      for (var completed = highestUnlockedLevel; completed < level; completed++) {
        completedLevels.add(completed);
      }
      highestUnlockedLevel = level;
    }
    currentLevel = level;
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_highestUnlockedKey, highestUnlockedLevel);
    await prefs.setInt(_currentLevelKey, currentLevel);
    final values = completedLevels.toList()..sort();
    await prefs.setStringList(
      _completedLevelsKey,
      values.map((value) => value.toString()).toList(),
    );
  }
}
