import 'level_data.dart';
import 'level_repository.dart';

/// Compatibility facade for older callers.
///
/// Level creation now lives in [LevelRepository], keeping level data and game
/// progression separate in the same way as the Unity LevelData/LevelManager
/// architecture.
class LevelGenerator {
  static final products = LevelRepository.productAssets;

  static SortingLevel generate(int level) => LevelRepository.getLevel(level);
}
