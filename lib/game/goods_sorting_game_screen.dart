import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'level_data.dart';
import 'level_generator.dart';
import 'sorting_item.dart';

class GoodsSortingGameScreen extends StatefulWidget {
  const GoodsSortingGameScreen({super.key, required this.levelNumber});

  final int levelNumber;

  @override
  State<GoodsSortingGameScreen> createState() => _GoodsSortingGameScreenState();
}

class _GoodsSortingGameScreenState extends State<GoodsSortingGameScreen>
    with TickerProviderStateMixin {
  static const _trayCapacity = 7;
  static const _maxLevel = 2500;

  late SortingLevel level;
  late AnimationController _intro;
  late AnimationController _float;
  late AnimationController _hintPulse;

  final List<SortingItem> tray = [];
  final List<SortingItem> moveHistory = [];
  final Set<SortingItem> removedItems = <SortingItem>{};

  bool busy = false;
  bool paused = false;
  bool resultShowing = false;
  int moves = 0;
  int score = 0;
  int coins = 250;
  SortingItem? hintedItem;

  @override
  void initState() {
    super.initState();
    level = LevelGenerator.generate(widget.levelNumber);
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward();
    _float = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _hintPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
  }

  @override
  void dispose() {
    _intro.dispose();
    _float.dispose();
    _hintPulse.dispose();
    super.dispose();
  }

  int get clearedItems => removedItems.length;
  int get remainingItems => level.totalItems - clearedItems;
  int get earnedCoins => (score ~/ 30) * 3;

  @override
  Widget build(BuildContext context) {
    final shelves = List.generate(
      level.shelfCount,
      (index) => level.items
          .where((item) =>
              item.shelfIndex == index && !removedItems.contains(item))
          .toList()
        ..sort((a, b) => a.stackIndex.compareTo(b.stackIndex)),
    );

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF1C9), Color(0xFFFFD56E), Color(0xFFE8893E)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _GameHeader(
                level: level,
                score: score,
                coins: coins,
                onBack: _exitToLevels,
                onPause: _showPause,
              ),
              _ProgressBar(total: level.totalItems, cleared: clearedItems),
              Expanded(
                child: AnimatedBuilder(
                  animation: _intro,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(0, 24 * (1 - _intro.value)),
                    child: Opacity(opacity: _intro.value, child: child),
                  ),
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 7, 12, 8),
                    itemCount: shelves.length,
                    itemBuilder: (context, index) {
                      final items = shelves[index];
                      return _Shelf(
                        key: ValueKey('shelf-$index-${level.levelNumber}'),
                        shelfNumber: index + 1,
                        items: items,
                        topItem: _topItem(items),
                        floatAnimation: _float,
                        hintItem: hintedItem,
                        onItemTap: _selectItem,
                      );
                    },
                  ),
                ),
              ),
              _Tray(
                items: tray,
                maxSlots: _trayCapacity,
                onItemTap: _removeFromTray,
              ),
              _GameActions(
                moves: moves,
                canUndo: moveHistory.isNotEmpty && !busy,
                onShuffle: _shuffle,
                onUndo: _undo,
                onHint: _hint,
              ),
            ],
          ),
        ),
      ),
    );
  }

  SortingItem? _topItem(List<SortingItem> items) {
    if (items.isEmpty) return null;
    return items.reduce((a, b) => a.stackIndex > b.stackIndex ? a : b);
  }

  bool _isAccessible(SortingItem item) {
    final items = level.items
        .where((candidate) =>
            candidate.shelfIndex == item.shelfIndex &&
            !removedItems.contains(candidate))
        .toList();
    return _topItem(items) == item;
  }

  void _selectItem(SortingItem item) {
    if (busy || paused || resultShowing || removedItems.contains(item)) return;
    if (!_isAccessible(item)) {
      _showToast('Move the top item first');
      return;
    }
    if (tray.length >= _trayCapacity) return;

    setState(() {
      removedItems.add(item);
      tray.add(item);
      moveHistory.add(item);
      hintedItem = null;
      moves++;
    });
    _hintPulse.stop();
    _checkMatch(item.productId);
  }

  Future<void> _checkMatch(int productId) async {
    final matches =
        tray.where((item) => item.productId == productId).take(3).toList();
    if (matches.length < 3 || busy) {
      _checkLose();
      return;
    }

    busy = true;
    await Future<void>.delayed(const Duration(milliseconds: 130));
    if (!mounted) return;

    setState(() {
      for (final item in matches) {
        tray.remove(item);
        moveHistory.remove(item);
      }
      score += 30;
      coins += 3;
    });

    await Future<void>.delayed(const Duration(milliseconds: 180));
    busy = false;
    if (!mounted) return;

    if (remainingItems == 0 && tray.isEmpty) {
      _showResult(true);
    } else {
      setState(() {});
      _checkLose();
    }
  }

  void _checkLose() {
    if (tray.length < _trayCapacity || busy || resultShowing) return;
    Future<void>.delayed(const Duration(milliseconds: 180), () {
      if (mounted && tray.length >= _trayCapacity && !busy && !resultShowing) {
        _showResult(false);
      }
    });
  }

  void _removeFromTray(SortingItem item) {
    if (busy || paused || resultShowing) return;
    setState(() {
      tray.remove(item);
      removedItems.remove(item);
      moveHistory.remove(item);
    });
  }

  void _undo() {
    if (busy || paused || resultShowing || moveHistory.isEmpty) return;
    final item = moveHistory.removeLast();
    if (!tray.remove(item)) return;
    setState(() {
      removedItems.remove(item);
      hintedItem = null;
      moves = math.max(0, moves - 1);
      score = math.max(0, score - 1);
    });
  }

  void _shuffle() {
    if (busy || paused || resultShowing || coins < 5) {
      if (coins < 5) _showToast('Need 5 coins to shuffle');
      return;
    }

    final active =
        level.items.where((item) => !removedItems.contains(item)).toList();
    if (active.length < 2) return;
    active.shuffle(math.Random(widget.levelNumber * 31 + moves + score));

    final byShelf = List.generate(level.shelfCount, (_) => <SortingItem>[]);
    for (var i = 0; i < active.length; i++) {
      byShelf[i % level.shelfCount].add(active[i]);
    }

    final shuffled = <SortingItem>[];
    for (var shelf = 0; shelf < byShelf.length; shelf++) {
      for (var index = 0; index < byShelf[shelf].length; index++) {
        final item = byShelf[shelf][index];
        shuffled.add(SortingItem(
          productId: item.productId,
          asset: item.asset,
          stackIndex: index,
          shelfIndex: shelf,
        ));
      }
    }

    final newItems = <SortingItem>[];
    newItems.addAll(level.items.where((item) => removedItems.contains(item)));
    newItems.addAll(shuffled);

    setState(() {
      coins -= 5;
      hintedItem = null;
      level = SortingLevel(
        levelNumber: level.levelNumber,
        difficulty: level.difficulty,
        itemTypes: level.itemTypes,
        shelfCount: level.shelfCount,
        maxStackDepth: level.maxStackDepth,
        emptySlots: level.emptySlots,
        complexity: level.complexity,
        items: List.unmodifiable(newItems),
      );
      moveHistory.clear();
    });
    _showToast('Board shuffled');
  }

  void _hint() {
    if (busy || paused || resultShowing) return;
    if (coins < 3) {
      _showToast('Need 3 coins for a hint');
      return;
    }

    final accessible = <SortingItem>[];
    for (var shelf = 0; shelf < level.shelfCount; shelf++) {
      final items = level.items
          .where((item) =>
              item.shelfIndex == shelf && !removedItems.contains(item))
          .toList();
      final top = _topItem(items);
      if (top != null) accessible.add(top);
    }

    SortingItem? target;
    for (final item in accessible) {
      if (level.items.any((candidate) =>
          candidate.productId == item.productId &&
          candidate != item &&
          !removedItems.contains(candidate))) {
        target = item;
        break;
      }
    }
    target ??= accessible.isEmpty ? null : accessible.first;
    if (target == null) return;

    setState(() {
      coins -= 3;
      hintedItem = target;
    });
    _hintPulse
      ..stop()
      ..repeat(reverse: true);

    Future<void>.delayed(const Duration(seconds: 2), () {
      if (!mounted || hintedItem != target) return;
      _hintPulse.stop();
      setState(() => hintedItem = null);
    });
  }

  void _resetLevel() {
    setState(() {
      level = LevelGenerator.generate(widget.levelNumber);
      tray.clear();
      moveHistory.clear();
      removedItems.clear();
      hintedItem = null;
      moves = 0;
      score = 0;
      busy = false;
      paused = false;
      resultShowing = false;
    });
    _intro.forward(from: 0);
  }

  void _exitToLevels() {
    if (busy || resultShowing) return;
    Navigator.of(context).pop();
  }

  void _showPause() {
    if (busy || resultShowing) return;
    setState(() => paused = true);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (sheetContext) => _PauseSheet(
        onResume: () {
          Navigator.pop(sheetContext);
          if (mounted) setState(() => paused = false);
        },
        onRestart: () {
          Navigator.pop(sheetContext);
          if (mounted) _resetLevel();
        },
      ),
    ).whenComplete(() {
      if (mounted && paused) setState(() => paused = false);
    });
  }

  void _showResult(bool win) {
    if (!mounted || resultShowing) return;
    resultShowing = true;

    showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: win ? 'Level complete' : 'Level failed',
      barrierColor: const Color(0x99000000),
      transitionDuration: const Duration(milliseconds: 650),
      pageBuilder: (_, __, ___) => _ResultDialog(
        win: win,
        level: widget.levelNumber,
        score: score,
        moves: moves,
        coins: coins,
        earnedCoins: earnedCoins,
        onPrimary: () => _handleResultPrimary(win),
        onExit: _handleResultExit,
      ),
      transitionBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween<double>(begin: .72, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  void _handleResultPrimary(bool win) {
    Navigator.of(context).pop();
    if (!mounted) return;
    setState(() => resultShowing = false);

    if (win) {
      if (widget.levelNumber >= _maxLevel) {
        _showToast('All 2500 levels completed!');
      } else {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 600),
            reverseTransitionDuration: const Duration(milliseconds: 350),
            pageBuilder: (_, __, ___) => GoodsSortingGameScreen(
              levelNumber: widget.levelNumber + 1,
            ),
            transitionsBuilder: (_, animation, __, child) {
              final curved = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              );
              return FadeTransition(
                opacity: curved,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(.18, 0),
                    end: Offset.zero,
                  ).animate(curved),
                  child: ScaleTransition(
                    scale: Tween<double>(begin: .96, end: 1).animate(curved),
                    child: child,
                  ),
                ),
              );
            },
          ),
        );
      }
    } else {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (_, __, ___) => GoodsSortingGameScreen(
            levelNumber: widget.levelNumber,
          ),
          transitionsBuilder: (_, animation, __, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
            );
            return FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween<double>(begin: .92, end: 1).animate(curved),
                child: child,
              ),
            );
          },
        ),
      );
    }
  }

  void _handleResultExit() {
    Navigator.of(context).pop();
    if (!mounted) return;
    setState(() => resultShowing = false);
    Future<void>.delayed(const Duration(milliseconds: 30), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 900),
          margin: const EdgeInsets.fromLTRB(24, 0, 24, 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }
}

class _ResultDialog extends StatefulWidget {
  const _ResultDialog({
    required this.win,
    required this.level,
    required this.score,
    required this.moves,
    required this.coins,
    required this.earnedCoins,
    required this.onPrimary,
    required this.onExit,
  });

  final bool win;
  final int level;
  final int score;
  final int moves;
  final int coins;
  final int earnedCoins;
  final VoidCallback onPrimary;
  final VoidCallback onExit;

  @override
  State<_ResultDialog> createState() => _ResultDialogState();
}

class _ResultDialogState extends State<_ResultDialog>
    with TickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..forward();

  late final AnimationController _confetti = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..forward();

  late final AnimationController _reward = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    _confetti.dispose();
    _reward.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.win ? 'LEVEL COMPLETE!' : 'LEVEL FAILED';
    final subtitle = widget.win
        ? 'Amazing sorting! The shelf is perfectly clean.'
        : 'The tray is full. Try another sorting order.';

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (widget.win)
              Positioned.fill(
                child: IgnorePointer(child: _Confetti(animation: _confetti)),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final t = Curves.elasticOut.transform(_controller.value);
                  return Transform.translate(
                    offset: Offset(0, 24 * (1 - _controller.value)),
                    child: Transform.scale(
                      scale: .96 + t * .04,
                      child: child,
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 390),
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFFFEF5), Color(0xFFFFD776)],
                    ),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x88000000),
                        blurRadius: 28,
                        offset: Offset(0, 14),
                      ),
                      BoxShadow(
                        color: Color(0x55FFFFFF),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ResultBurst(win: widget.win, animation: _controller),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .5,
                          color: widget.win
                              ? const Color(0xFF704016)
                              : const Color(0xFF8A3E22),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF8A6845),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _ResultStat(
                            icon: Icons.stars_rounded,
                            label: 'SCORE',
                            value: '${widget.score}',
                          ),
                          _ResultStat(
                            icon: Icons.touch_app_rounded,
                            label: 'MOVES',
                            value: '${widget.moves}',
                          ),
                          _ResultStat(
                            icon: Icons.monetization_on_rounded,
                            label: 'COINS',
                            value: '${widget.coins}',
                          ),
                        ],
                      ),
                      if (widget.win) ...[
                        const SizedBox(height: 10),
                        _RewardAnimation(
                          animation: _reward,
                          coins: widget.earnedCoins,
                        ),
                        const SizedBox(height: 3),
                        _Stars(animation: _reward),
                      ],
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: widget.onPrimary,
                          icon: Icon(
                            widget.win
                                ? Icons.arrow_forward_rounded
                                : Icons.refresh_rounded,
                          ),
                          label: Text(
                            widget.win
                                ? (widget.level >= 2500
                                    ? 'FINISH'
                                    : 'NEXT LEVEL')
                                : 'TRY AGAIN',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .4,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.win
                                ? const Color(0xFF8A4B22)
                                : const Color(0xFFB54F2A),
                            foregroundColor: Colors.white,
                            elevation: 7,
                            shadowColor: const Color(0x66000000),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: widget.onExit,
                        icon: const Icon(Icons.grid_view_rounded, size: 17),
                        label: const Text(
                          'EXIT TO LEVELS',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF7B5A38),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Confetti extends StatelessWidget {
  const _Confetti({required this.animation});
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Stack(
          children: List.generate(34, (index) {
            final seed = index * 17 + 5;
            final startX = ((seed * 37) % 100) / 100.0;
            final drift = math.sin(seed * .9) * 28;
            final speed = .72 + (seed % 7) * .055;
            final progress = (animation.value * speed) % 1.0;
            final x = MediaQuery.sizeOf(context).width * startX +
                drift * math.sin(progress * math.pi * 2);
            final y = -30 +
                MediaQuery.sizeOf(context).height * progress * 1.12;
            final rotation = progress * math.pi * (2 + index % 3);
            final size = 5.0 + (index % 4) * 2.0;
            final shapes = [
              Icons.star_rounded,
              Icons.circle,
              Icons.square_rounded,
              Icons.diamond_rounded,
            ];
            return Positioned(
              left: x,
              top: y,
              child: Transform.rotate(
                angle: rotation,
                child: Icon(
                  shapes[index % shapes.length],
                  size: size + 5,
                  color: _confettiColor(index),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Color _confettiColor(int index) {
    const colors = [
      Color(0xFFFFB52B),
      Color(0xFFEF6C45),
      Color(0xFF58A85C),
      Color(0xFF4C8FD8),
      Color(0xFFB96DD8),
    ];
    return colors[index % colors.length];
  }
}

class _RewardAnimation extends StatelessWidget {
  const _RewardAnimation({required this.animation, required this.coins});
  final Animation<double> animation;
  final int coins;

  @override
  Widget build(BuildContext context) {
    if (coins <= 0) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final curved = Curves.easeOutBack.transform(animation.value);
        final opacity = Curves.easeOut.transform(
          math.min(1.0, animation.value * 1.7),
        );
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - curved)),
            child: Transform.scale(scale: .8 + curved * .2, child: child),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF2BE),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFFC83D), width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.monetization_on_rounded,
              size: 18,
              color: Color(0xFFE68A18),
            ),
            const SizedBox(width: 5),
            Text(
              '+$coins COINS',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: .5,
                color: Color(0xFF754318),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultBurst extends StatelessWidget {
  const _ResultBurst({required this.win, required this.animation});
  final bool win;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final pulse = 1 + math.sin(animation.value * math.pi * 3) * .035;
        return Transform.scale(scale: pulse, child: child);
      },
      child: SizedBox(
        width: 118,
        height: 88,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ...List.generate(8, (index) {
              final angle = index * math.pi / 4;
              return Transform.translate(
                offset: Offset(math.cos(angle) * 43, math.sin(angle) * 31),
                child: Icon(
                  win ? Icons.star_rounded : Icons.close_rounded,
                  size: index.isEven ? 17 : 12,
                  color: win
                      ? const Color(0xFFFFB52B)
                      : const Color(0xFFD46A3A),
                ),
              );
            }),
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: win
                      ? const [Color(0xFFFFC83D), Color(0xFFF27A1D)]
                      : const [Color(0xFFE98250), Color(0xFFB84628)],
                ),
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x55000000),
                    blurRadius: 9,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(
                win ? Icons.emoji_events_rounded : Icons.close_rounded,
                color: Colors.white,
                size: 42,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.animation});
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            final start = .35 + index * .14;
            final progress = ((animation.value - start) / .35).clamp(0.0, 1.0);
            final scale = Curves.elasticOut.transform(progress);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Transform.rotate(
                angle: index == 1 ? 0 : (index == 0 ? -.12 : .12),
                child: Transform.scale(
                  scale: scale,
                  child: Icon(
                    Icons.star_rounded,
                    size: index == 1 ? 42 : 34,
                    color: const Color(0xFFFFA914),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _ResultStat extends StatelessWidget {
  const _ResultStat({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 21, color: const Color(0xFFE58A1D)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Color(0xFF613A1D),
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w900,
            letterSpacing: .9,
            color: Color(0xFF9A7048),
          ),
        ),
      ],
    );
  }
}

class _GameHeader extends StatelessWidget {
  const _GameHeader({
    required this.level,
    required this.score,
    required this.coins,
    required this.onBack,
    required this.onPause,
  });

  final SortingLevel level;
  final int score;
  final int coins;
  final VoidCallback onBack;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 4),
      child: Row(
        children: [
          _RoundButton(icon: Icons.arrow_back_rounded, onTap: onBack),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LEVEL ${level.levelNumber}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    color: Color(0xFF5D381D),
                  ),
                ),
                Text(
                  _difficultyName(level.difficulty),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: Color(0xFF986B3F),
                  ),
                ),
              ],
            ),
          ),
          _SmallStat(icon: Icons.stars_rounded, value: '$score'),
          const SizedBox(width: 5),
          _SmallStat(icon: Icons.monetization_on_rounded, value: '$coins'),
          const SizedBox(width: 5),
          _RoundButton(icon: Icons.pause_rounded, onTap: onPause),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.total, required this.cleared});
  final int total;
  final int cleared;

  @override
  Widget build(BuildContext context) {
    final value = total == 0 ? 0.0 : (cleared / total).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 3),
      child: Row(
        children: [
          const Icon(
            Icons.shopping_basket_rounded,
            size: 17,
            color: Color(0xFF9B632E),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: const Color(0x55FFFFFF),
                valueColor: const AlwaysStoppedAnimation(Color(0xFFF28B16)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$cleared/$total',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Color(0xFF633E20),
            ),
          ),
        ],
      ),
    );
  }
}

class _Shelf extends StatelessWidget {
  const _Shelf({
    super.key,
    required this.shelfNumber,
    required this.items,
    required this.topItem,
    required this.floatAnimation,
    required this.hintItem,
    required this.onItemTap,
  });

  final int shelfNumber;
  final List<SortingItem> items;
  final SortingItem? topItem;
  final Animation<double> floatAnimation;
  final SortingItem? hintItem;
  final ValueChanged<SortingItem> onItemTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 108,
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFCF2), Color(0xFFFFE5AA)],
        ),
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 9,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 33,
            child: Center(
              child: Text(
                '$shelfNumber',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF9A7048),
                ),
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final count = math.max(1, items.length);
                final size = math.min(
                  57.0,
                  math.max(43.0, constraints.maxWidth / math.min(5, count)),
                );
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 7,
                      child: Container(
                        height: 9,
                        decoration: BoxDecoration(
                          color: const Color(0xFFAA672D),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x35000000),
                              blurRadius: 2,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                    ...items.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      final isTop = item == topItem;
                      final depthFromTop = topItem == null
                          ? 0
                          : topItem!.stackIndex - item.stackIndex;
                      return Positioned(
                        left: math.min(
                          constraints.maxWidth - size,
                          index * (size - 3),
                        ),
                        bottom: 12 + math.max(0, depthFromTop) * 5.5,
                        child: AnimatedBuilder(
                          animation: floatAnimation,
                          builder: (context, child) => Transform.translate(
                            offset: Offset(
                              0,
                              isTop
                                  ? math.sin(floatAnimation.value * math.pi) * 1.6
                                  : 0,
                            ),
                            child: child,
                          ),
                          child: _ProductCard(
                            item: item,
                            size: size,
                            enabled: isTop,
                            highlighted: item == hintItem,
                            onTap: () => onItemTap(item),
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatefulWidget {
  const _ProductCard({
    required this.item,
    required this.size,
    required this.enabled,
    required this.highlighted,
    required this.onTap,
  });

  final SortingItem item;
  final double size;
  final bool enabled;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.enabled ? (_) => setState(() => pressed = true) : null,
      onTapUp: widget.enabled
          ? (_) {
              setState(() => pressed = false);
              widget.onTap();
            }
          : null,
      onTapCancel:
          widget.enabled ? () => setState(() => pressed = false) : null,
      child: AnimatedScale(
        scale: pressed ? .86 : 1,
        duration: const Duration(milliseconds: 85),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: widget.size - 3,
          height: widget.size - 3,
          padding: EdgeInsets.all(widget.size * .10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.enabled
                  ? const [Colors.white, Color(0xFFF4E4C3)]
                  : const [Color(0xFFE8DCC4), Color(0xFFCBB996)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.highlighted
                  ? const Color(0xFFFF8B18)
                  : widget.enabled
                      ? const Color(0xFFFFC34D)
                      : const Color(0xFFB79B72),
              width: widget.highlighted ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0x40000000),
                blurRadius: widget.enabled ? 6 : 3,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Opacity(
            opacity: widget.enabled ? 1 : .68,
            child: SvgPicture.asset(widget.item.asset),
          ),
        ),
      ),
    );
  }
}

class _Tray extends StatelessWidget {
  const _Tray({
    required this.items,
    required this.maxSlots,
    required this.onItemTap,
  });

  final List<SortingItem> items;
  final int maxSlots;
  final ValueChanged<SortingItem> onItemTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(13, 1, 13, 5),
      padding: const EdgeInsets.fromLTRB(9, 7, 9, 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF874923), Color(0xFF633318)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFFFD277), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x50000000),
            blurRadius: 8,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.inventory_2_rounded,
                size: 16,
                color: Color(0xFFFFD277),
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'MATCH TRAY',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                '${items.length}/$maxSlots',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFFFE4A8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          SizedBox(
            height: 50,
            child: Row(
              children: List.generate(maxSlots, (index) {
                final item = index < items.length ? items[index] : null;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      transitionBuilder: (child, animation) => ScaleTransition(
                        scale: animation,
                        child: child,
                      ),
                      child: item == null
                          ? Container(
                              key: ValueKey('empty-$index'),
                              decoration: BoxDecoration(
                                color: const Color(0x3320100A),
                                borderRadius: BorderRadius.circular(11),
                                border: Border.all(
                                  color: const Color(0x66FFD98B),
                                ),
                              ),
                            )
                          : GestureDetector(
                              key: ValueKey('tray-${identityHashCode(item)}'),
                              onTap: () => onItemTap(item),
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(11),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x45000000),
                                      blurRadius: 4,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: SvgPicture.asset(item.asset),
                              ),
                            ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameActions extends StatelessWidget {
  const _GameActions({
    required this.moves,
    required this.canUndo,
    required this.onShuffle,
    required this.onUndo,
    required this.onHint,
  });

  final int moves;
  final bool canUndo;
  final VoidCallback onShuffle;
  final VoidCallback onUndo;
  final VoidCallback onHint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 1, 14, 7),
      child: Row(
        children: [
          Expanded(
            child: _ActionButton(
              icon: Icons.shuffle_rounded,
              label: 'SHUFFLE',
              onTap: onShuffle,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: _ActionButton(
              icon: Icons.undo_rounded,
              label: '$moves MOVES',
              onTap: canUndo ? onUndo : null,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: _ActionButton(
              icon: Icons.lightbulb_rounded,
              label: 'HINT',
              onTap: onHint,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: enabled ? 1 : .48,
          child: Container(
            height: 47,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF9E8), Color(0xFFFFE2A1)],
              ),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x35000000),
                  blurRadius: 5,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 19, color: const Color(0xFF633E20)),
                const SizedBox(height: 1),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF633E20),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 43,
          height: 43,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Color(0xFFFFD986)],
            ),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x3B000000),
                blurRadius: 5,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, color: const Color(0xFF633E20), size: 21),
        ),
      ),
    );
  }
}

class _SmallStat extends StatelessWidget {
  const _SmallStat({required this.icon, required this.value});
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xAAFFF8DF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFFE78B17)),
          const SizedBox(width: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: Color(0xFF633E20),
            ),
          ),
        ],
      ),
    );
  }
}

class _PauseSheet extends StatelessWidget {
  const _PauseSheet({required this.onResume, required this.onRestart});
  final VoidCallback onResume;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      icon: Icons.pause_circle_filled_rounded,
      title: 'GAME PAUSED',
      subtitle: 'Take a break. Your board is safe.',
      actions: [
        _SheetButton(
          label: 'RESUME',
          icon: Icons.play_arrow_rounded,
          onTap: onResume,
        ),
        _SheetButton(
          label: 'RESTART',
          icon: Icons.refresh_rounded,
          onTap: onRestart,
        ),
      ],
    );
  }
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actions,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 25),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF8E5), Color(0xFFFFD47A)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0x55805A2E),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 13),
          Container(
            width: 66,
            height: 66,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFFFFB52B), Color(0xFFF07A20)],
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 9),
          Text(
            title,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w900,
              color: Color(0xFF60391E),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8B623D),
            ),
          ),
          const SizedBox(height: 15),
          ...actions,
        ],
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: SizedBox(
        width: double.infinity,
        height: 49,
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 20),
          label: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: .5,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8A4B22),
            foregroundColor: Colors.white,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}

String _difficultyName(double value) {
  if (value < .04) return 'VERY EASY';
  if (value < .15) return 'EASY';
  if (value < .30) return 'NORMAL';
  if (value < .48) return 'MEDIUM';
  if (value < .65) return 'HARD';
  if (value < .80) return 'ADVANCED';
  if (value < .92) return 'EXPERT';
  return 'MASTER';
}
