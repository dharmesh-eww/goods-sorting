import 'sorting_item.dart';

class SortingLevel {
  const SortingLevel({
    required this.levelNumber,
    required this.difficulty,
    required this.itemTypes,
    required this.shelfCount,
    required this.maxStackDepth,
    required this.emptySlots,
    required this.complexity,
    required this.timerSeconds,
    required this.items,
  });

  final int levelNumber;
  final double difficulty;
  final int itemTypes;
  final int shelfCount;
  final int maxStackDepth;
  final int emptySlots;
  final double complexity;
  final int timerSeconds;
  final List<SortingItem> items;

  int get totalItems => items.length;
}
