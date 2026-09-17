import 'dart:collection';

import 'sorting_item.dart';

class SortingLevel {
  SortingLevel({
    required this.levelNumber,
    required this.difficulty,
    required this.itemTypes,
    required this.shelfCount,
    required this.maxStackDepth,
    required this.emptySlots,
    required this.complexity,
    this.timerSeconds = 0,
    required List<SortingItem> items,
  }) : items = _LevelItems(items);

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

/// Keeps level definitions immutable for gameplay while tolerating legacy
/// callers that attempted to call clear() on the level item list.
class _LevelItems extends ListBase<SortingItem> {
  _LevelItems(List<SortingItem> source)
      : _source = List<SortingItem>.unmodifiable(source);

  final List<SortingItem> _source;

  @override
  int get length => _source.length;

  @override
  set length(int value) {
    if (value != _source.length) {
      throw UnsupportedError('Level item count is immutable');
    }
  }

  @override
  SortingItem operator [](int index) => _source[index];

  @override
  void operator []=(int index, SortingItem value) {
    throw UnsupportedError('Level items are immutable');
  }

  @override
  void clear() {
    // Legacy shuffle code used clear() before replacing its runtime layout.
    // The source level must remain intact so totalItems and accessibility stay
    // correct.
  }
}
