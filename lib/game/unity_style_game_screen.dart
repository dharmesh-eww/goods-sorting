import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'game_currency.dart';
import 'level_generator.dart';
import 'level_complete_screen.dart';
import 'time_up_screen.dart';
import 'level_progress.dart';
import 'sorting_item.dart';

/// Unity-inspired play screen. The Unity project has a game canvas with a
/// top panel, timer, earnings, and separate win/lose panels; this screen keeps
/// those responsibilities together while using Flutter widgets/animations.
class UnityStyleGameScreen extends StatefulWidget {
  const UnityStyleGameScreen({super.key, required this.levelNumber});

  final int levelNumber;

  @override
  State<UnityStyleGameScreen> createState() => _UnityStyleGameScreenState();
}

class _UnityStyleGameScreenState extends State<UnityStyleGameScreen> with TickerProviderStateMixin {
  late final _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward();
  late final _match = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));

  late final level = LevelGenerator.generate(widget.levelNumber);
  Timer? timer;
  late List<List<SortingItem?>> trays;
  final history = <_TrayMove>[];

  int secondsLeft = 0;
  int moves = 0;
  int score = 0;
  int coins = GameCurrency.defaultCoins;
  bool timerStarted = false;
  bool paused = false;
  bool gameOver = false;
  bool completionSaved = false;
  SortingItem? hint;

  @override
  void initState() {
    super.initState();
    secondsLeft = level.timerSeconds;
    _createInitialTrays();
    _loadCoins();
  }

  @override
  void dispose() {
    timer?.cancel();
    _intro.dispose();
    _match.dispose();
    super.dispose();
  }

  Future<void> _loadCoins() async {
    await GameCurrency.instance.load();
    if (mounted) setState(() => coins = GameCurrency.instance.coins);
  }

  int get trayCount => level.shelfCount + 3;

  void _createInitialTrays() {
    final source = List<SortingItem>.from(level.items);
    trays = List.generate(trayCount, (_) => <SortingItem?>[null, null, null]);
    for (var i = 0; i < source.length; i++) {
      trays[i ~/ 3][i % 3] = source[i];
    }
  }

  void _startTimer() {
    if (level.timerSeconds == 0 || timerStarted || paused || gameOver) return;
    timerStarted = true;
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || paused || gameOver) return;
      if (secondsLeft <= 1) {
        timer?.cancel();
        setState(() => secondsLeft = 0);
        _finish(false, timedOut: true);
      } else {
        setState(() => secondsLeft--);
      }
    });
  }

  void _moveItem(SortingItem item, int fromTray, int fromPosition, int toTray, int toPosition) {
    if (paused || gameOver) return;
    if (fromTray == toTray && fromPosition == toPosition) return;
    if (trays[toTray][toPosition] != null) {
      _toast('That position is occupied');
      return;
    }
    if (trays[fromTray][fromPosition] != item) return;

    _startTimer();
    setState(() {
      trays[fromTray][fromPosition] = null;
      trays[toTray][toPosition] = item;
      history.add(
        _TrayMove(item: item, fromTray: fromTray, fromPosition: fromPosition, toTray: toTray, toPosition: toPosition),
      );
      moves++;
      score += 5;
    });
    _checkMatch(toTray);
  }

  void _checkMatch(int trayIndex) {
    final tray = trays[trayIndex];
    if (tray.any((item) => item == null)) return;
    final filled = tray.whereType<SortingItem>().toList();
    if (filled.length != 3) return;
    final productId = filled.first.productId;
    if (!filled.every((item) => item.productId == productId)) return;

    final matched = List<SortingItem>.from(filled);
    _match.forward(from: 0).then((_) {
      if (!mounted || gameOver) return;
      setState(() {
        trays[trayIndex] = <SortingItem?>[null, null, null];
        history.removeWhere((move) => matched.contains(move.item));
        score += 30;
      });
      _checkWin();
    });
  }

  void _checkWin() {
    if (trays.every((tray) => tray.every((item) => item == null)) && !gameOver) {
      _finish(true);
    }
  }

  void _undo() {
    if (history.isEmpty || paused || gameOver) return;
    final move = history.removeLast();
    if (trays[move.toTray][move.toPosition] != move.item || trays[move.fromTray][move.fromPosition] != null) {
      return;
    }

    setState(() {
      trays[move.toTray][move.toPosition] = null;
      trays[move.fromTray][move.fromPosition] = move.item;
      moves = math.max(0, moves - 1);
      score = math.max(0, score - 5);
    });
  }

  Future<void> _shuffle() async {
    if (paused || gameOver || coins < 5) {
      if (coins < 5) _toast('Need 5 coins');
      return;
    }

    final spent = await GameCurrency.instance.spend(5);
    if (!spent || !mounted) return;

    final items = trays.expand((tray) => tray).toList()..shuffle(math.Random(widget.levelNumber * 37 + moves));

    final shuffled = List.generate(trayCount, (_) => <SortingItem?>[null, null, null]);
    var slot = 0;
    for (final item in items) {
      while (slot < trayCount * 3 && shuffled[slot ~/ 3][slot % 3] != null) slot++;
      if (slot >= trayCount * 3) break;
      shuffled[slot ~/ 3][slot % 3] = item;
      slot++;
    }

    setState(() {
      trays = shuffled;
      coins = GameCurrency.instance.coins;
    });
  }

  Future<void> _hint() async {
    if (paused || gameOver || coins < 3) {
      if (coins < 3) _toast('Need 3 coins');
      return;
    }

    final spent = await GameCurrency.instance.spend(3);
    if (!spent || !mounted) return;

    int? source;
    int? target;

    for (var i = 0; i < trays.length && source == null; i++) {
      final sourceItems = trays[i].whereType<SortingItem>().toList();
      if (sourceItems.isEmpty) continue;

      final sourceProductId = sourceItems.last.productId;

      for (var j = i + 1; j < trays.length; j++) {
        final targetItems = trays[j].whereType<SortingItem>().toList();
        if (targetItems.length >= 3 || targetItems.isEmpty) continue;

        final targetProductId = targetItems.last.productId;
        if (sourceProductId == targetProductId) {
          source = i;
          target = j;
          break;
        }
      }
    }

    if (source == null) {
      final empty = trays.indexWhere((tray) => tray.every((item) => item == null));
      if (empty >= 0) {
        source = trays.indexWhere((tray) => tray.any((item) => item != null));
        target = empty;
      }
    }

    setState(() => coins = GameCurrency.instance.coins);
    if (source != null && target != null) {
      _toast('Try moving an item from tray ${source! + 1}');
    } else {
      _toast('No move available');
    }
  }

  void _reset() {
    timer?.cancel();
    setState(() {
      _createInitialTrays();
      history.clear();
      secondsLeft = level.timerSeconds;
      timerStarted = false;
      paused = false;
      gameOver = false;
      completionSaved = false;
      moves = 0;
      score = 0;
      hint = null;
    });
    _intro.forward(from: 0);
  }

  Future<void> _finish(bool win, {bool timedOut = false}) async {
    if (gameOver || !mounted) return;

    gameOver = true;
    timer?.cancel();

    var earned = 0;
    if (win && !completionSaved) {
      completionSaved = true;
      earned = math.max(3, 3 + secondsLeft ~/ 20);
      await LevelProgress.instance.markCompleted(widget.levelNumber);
      await GameCurrency.instance.add(earned);
      score += earned * 10;
      coins = GameCurrency.instance.coins;
    }

    if (!mounted) return;

    if (win) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 450),
          reverseTransitionDuration: const Duration(milliseconds: 350),
          pageBuilder: (_, animation, __) => LevelCompleteScreen(
            levelNumber: widget.levelNumber,
            score: score,
            moves: moves,
            earnedCoins: earned,
            onNext: () {
              if (widget.levelNumber >= LevelProgress.maxLevel) {
                Navigator.pop(context);
                return;
              }

              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => UnityStyleGameScreen(
                    levelNumber: widget.levelNumber + 1,
                  ),
                ),
              );
            },
            onLevels: () => Navigator.pop(context),
          ),
          transitionsBuilder: (_, animation, __, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween<double>(begin: .96, end: 1).animate(curved),
                child: child,
              ),
            );
          },
        ),
      );
    } else if (timedOut) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 450),
          reverseTransitionDuration: const Duration(milliseconds: 350),
          pageBuilder: (_, animation, __) => TimeUpScreen(
            levelNumber: widget.levelNumber,
            onRetry: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => UnityStyleGameScreen(
                    levelNumber: widget.levelNumber,
                  ),
                ),
              );
            },
            onLevels: () => Navigator.pop(context),
          ),
          transitionsBuilder: (_, animation, __, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween<double>(begin: .97, end: 1).animate(curved),
                child: child,
              ),
            );
          },
        ),
      );
    }
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 900),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF24140D), Color(0xFF5A3019), Color(0xFFC77A35)],
          ),
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: IgnorePointer(child: _ShelfBackdrop())),
            SafeArea(
              child: Column(
                children: [
                  _TopPanel(
                    level: widget.levelNumber,
                    seconds: secondsLeft,
                    totalSeconds: level.timerSeconds,
                    coins: coins,
                    onBack: () => Navigator.pop(context),
                    onPause: () => _showPause(),
                  ),
                  _Progress(
                    remaining: trays.fold<int>(0, (sum, tray) => sum + tray.whereType<SortingItem>().length),
                    total: level.totalItems,
                  ),
                  Expanded(
                    child: AnimatedBuilder(
                      animation: _intro,
                      builder: (_, child) => Transform.translate(
                        offset: Offset(0, 20 * (1 - _intro.value)),
                        child: Opacity(opacity: _intro.value, child: child),
                      ),
                      child: _CustomTrayLayout(
                        trays: trays,
                        onDrop: (trayIndex, item, position) {
                          final source = _findItemPosition(item);
                          if (source == null) return;

                          var targetPosition = position;
                          if (targetPosition == null) {
                            targetPosition = trays[trayIndex].indexWhere((slot) => slot == null);
                          }

                          if (targetPosition == null || targetPosition < 0) {
                            _toast('Tray is full');
                            return;
                          }

                          _moveItem(item, source.$1, source.$2, trayIndex, targetPosition);
                        },
                      ),
                    ),
                  ),
                  _Actions(moves: moves, onUndo: history.isEmpty ? null : _undo, onShuffle: _shuffle, onHint: _hint),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  (int, int)? _findItemPosition(SortingItem item) {
    for (var trayIndex = 0; trayIndex < trays.length; trayIndex++) {
      for (var position = 0; position < 3; position++) {
        if (trays[trayIndex][position] == item) return (trayIndex, position);
      }
    }
    return null;
  }

  void _showPause() {
    if (gameOver) return;
    setState(() => paused = true);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (sheet) => Container(
        padding: const EdgeInsets.all(22),
        decoration: const BoxDecoration(
          color: Color(0xFFFFEAC1),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(color: Color(0xFFC68B51), borderRadius: BorderRadius.circular(4)),
            ),
            const SizedBox(height: 14),
            const Text(
              'PAUSED',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF653918)),
            ),
            const SizedBox(height: 18),
            _WideButton('RESUME', Icons.play_arrow_rounded, () {
              Navigator.pop(sheet);
              if (mounted) setState(() => paused = false);
            }),
            const SizedBox(height: 10),
            _WideButton('RESTART', Icons.refresh_rounded, () {
              Navigator.pop(sheet);
              _reset();
            }),
          ],
        ),
      ),
    ).whenComplete(() {
      if (mounted && paused) setState(() => paused = false);
    });
  }
}

class _ShelfBackdrop extends StatelessWidget {
  const _ShelfBackdrop();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _ShelfBackdropPainter());
  }
}

class _ShelfBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final wall = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF1E110B), Color(0xFF4A2514), Color(0xFF8A4B24)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, wall);

    final wood = Paint()
      ..color = const Color(0xFFB96C32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (var y = 150.0; y < size.height; y += 175) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), wood);
      canvas.drawLine(
        Offset(0, y + 5),
        Offset(size.width, y + 5),
        Paint()
          ..color = const Color(0x33000000)
          ..strokeWidth = 8,
      );
    }

    final glow = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0x66FFD78A), const Color(0x00FFD78A)],
      ).createShader(Rect.fromCircle(center: Offset(size.width * .5, size.height * .24), radius: size.width * .7));
    canvas.drawCircle(Offset(size.width * .5, size.height * .24), size.width * .7, glow);
  }

  @override
  bool shouldRepaint(covariant _ShelfBackdropPainter oldDelegate) => false;
}

class _TopPanel extends StatelessWidget {
  const _TopPanel({
    required this.level,
    required this.seconds,
    required this.totalSeconds,
    required this.coins,
    required this.onBack,
    required this.onPause,
  });

  final int level, seconds, totalSeconds, coins;
  final VoidCallback onBack, onPause;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 5),
      child: Row(
        children: [
          _CircleButton(Icons.arrow_back_rounded, onBack),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF5F351D), Color(0xFF2C170D)],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE1A15D), width: 1.5),
                boxShadow: const [
                  BoxShadow(color: Color(0x99000000), blurRadius: 10, offset: Offset(0, 5)),
                  BoxShadow(color: Color(0x44FFD68A), blurRadius: 2, offset: Offset(0, -1)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFFFC95B), Color(0xFFB96320)]),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFFE0A5), width: 1),
                    ),
                    child: const Icon(Icons.layers_rounded, size: 18, color: Color(0xFF4D250F)),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'LEVEL $level',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: .3,
                        shadows: [Shadow(color: Color(0x99000000), blurRadius: 3, offset: Offset(0, 2))],
                      ),
                    ),
                  ),
                  if (totalSeconds > 0) ...[
                    const SizedBox(width: 6),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.timer_rounded, size: 15, color: Color(0xFFFFC45D)),
                            const SizedBox(width: 2),
                            Text(
                              _time(seconds),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 52,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: LinearProgressIndicator(
                              minHeight: 4,
                              value: (seconds / totalSeconds).clamp(0, 1),
                              backgroundColor: const Color(0x663E1F0E),
                              valueColor: const AlwaysStoppedAnimation(Color(0xFFFFA52E)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(width: 6),
                  _CoinPill(coins),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _CircleButton(Icons.pause_rounded, onPause),
        ],
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.remaining, required this.total});

  final int remaining, total;

  @override
  Widget build(BuildContext context) {
    final value = total == 0 ? 0.0 : remaining / total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 2, 18, 6),
      child: Container(
        height: 9,
        decoration: BoxDecoration(
          color: const Color(0x660F0804),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x55F4B15E)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: value.clamp(0, 1),
              child: const DecoratedBox(
                decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFFFD05A), Color(0xFFF07A21)])),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TrayMove {
  const _TrayMove({
    required this.item,
    required this.fromTray,
    required this.fromPosition,
    required this.toTray,
    required this.toPosition,
  });

  final SortingItem item;
  final int fromTray;
  final int fromPosition;
  final int toTray;
  final int toPosition;
}

class _CustomTrayLayout extends StatelessWidget {
  const _CustomTrayLayout({
    required this.trays,
    required this.onDrop,
  });

  final List<List<SortingItem?>> trays;
  final void Function(int trayIndex, SortingItem item, int? position) onDrop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 390 ? 3 : 2;
        final rows = <List<int>>[];

        for (var start = 0; start < trays.length; start += columns) {
          final end = math.min(start + columns, trays.length);
          rows.add(List<int>.generate(end - start, (index) => start + index));
        }

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Column(
            children: [
              for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var column = 0; column < columns; column++)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: column == columns - 1 ? 0 : 8,
                          ),
                          child: rows[rowIndex].length > column
                              ? _SortingTray(
                                  number: rows[rowIndex][column] + 1,
                                  items: trays[rows[rowIndex][column]],
                                  onDrop: (item, position) => onDrop(
                                    rows[rowIndex][column],
                                    item,
                                    position,
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                  ],
                ),
                if (rowIndex != rows.length - 1) const SizedBox(height: 12),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SortingTray extends StatelessWidget {
  const _SortingTray({
    required this.number,
    required this.items,
    required this.onDrop,
  });

  final int number;
  final List<SortingItem?> items;
  final void Function(SortingItem item, int? position) onDrop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemSize = ((constraints.maxWidth - 8) / 3).clamp(34.0, 50.0);
        final gap = (constraints.maxWidth - itemSize * 3) / 2;
        const lineHeight = 4.0;
        final lineTop = itemSize + 2.0;

        return SizedBox(
          height: lineTop + lineHeight,
          child: DragTarget<SortingItem>(
            onWillAcceptWithDetails: (details) => items.any((item) => item == null),
            onAcceptWithDetails: (details) {
              final box = context.findRenderObject() as RenderBox;
              final localOffset = box.globalToLocal(details.offset);

              int? position;
              for (var index = 0; index < 3; index++) {
                final left = index * (itemSize + gap);
                final rect = Rect.fromLTWH(left, 0, itemSize, itemSize + 2);
                if (rect.contains(localOffset) && items[index] == null) {
                  position = index;
                  break;
                }
              }

              onDrop(details.data, position);
            },
            builder: (context, candidate, rejected) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var position = 0; position < 3; position++)
                    Positioned(
                      left: position * (itemSize + gap),
                      top: 0,
                      width: itemSize,
                      height: itemSize,
                      child: items[position] == null
                          ? const SizedBox.expand()
                          : _TrayItem(
                              item: items[position]!,
                              size: itemSize,
                            ),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: lineTop,
                    height: lineHeight,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFB66A32),
                            Color(0xFFE6A15C),
                            Color(0xFF8A481F),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x88000000),
                            blurRadius: 2,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _TrayItem extends StatelessWidget {
  const _TrayItem({
    required this.item,
    required this.size,
  });

  final SortingItem item;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Draggable<SortingItem>(
      data: item,
      maxSimultaneousDrags: 1,
      feedback: Material(
        color: Colors.transparent,
        child: Transform.scale(
          scale: 1.12,
          child: SizedBox(width: size, height: size, child: _visual()),
        ),
      ),
      childWhenDragging: Opacity(opacity: .25, child: _visual()),
      child: _visual(),
    );
  }

  Widget _visual() => SizedBox(
        width: size,
        height: size,
        child: SvgPicture.asset(item.asset, fit: BoxFit.contain),
      );
}

class _Actions extends StatelessWidget {
  const _Actions({required this.moves, required this.onUndo, required this.onShuffle, required this.onHint});

  final int moves;
  final VoidCallback? onUndo, onShuffle, onHint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 3, 12, 10),
      child: Row(
        children: [
          _SmallAction(Icons.shuffle_rounded, 'SHUFFLE', onShuffle),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF5C3017), Color(0xFF2A1409)]),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: const Color(0xFFB96A34)),
              boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 5, offset: Offset(0, 3))],
            ),
            child: Text(
              'MOVES $moves',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFFFFE5C1)),
            ),
          ),
          const Spacer(),
          _SmallAction(Icons.undo_rounded, 'UNDO', onUndo),
          const SizedBox(width: 7),
          _SmallAction(Icons.lightbulb_rounded, 'HINT', onHint),
        ],
      ),
    );
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction(this.icon, this.label, this.onTap);

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? .45 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFD58A), Color(0xFFC8732D)],
            ),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: const Color(0xFFFFE1AE)),
            boxShadow: const [BoxShadow(color: Color(0x88000000), blurRadius: 5, offset: Offset(0, 3))],
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF5B2A0E)),
              const SizedBox(width: 3),
              Text(
                label,
                style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Color(0xFF5B2A0E)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton(this.icon, this.onTap);

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFD68A), Color(0xFFB96425)],
          ),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFFFE4B7), width: 1.5),
          boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 8, offset: Offset(0, 5))],
        ),
        child: Icon(icon, color: const Color(0xFF5A2B0E)),
      ),
    );
  }
}

class _CoinPill extends StatelessWidget {
  const _CoinPill(this.coins);

  final int coins;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFE08A), Color(0xFFE99521)],
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFFFF0B5)),
        boxShadow: const [BoxShadow(color: Color(0x88000000), blurRadius: 4, offset: Offset(0, 3))],
      ),
      child: Row(
        children: [
          const Icon(Icons.monetization_on_rounded, size: 18, color: Color(0xFF8D4A0D)),
          const SizedBox(width: 2),
          Text(
            '$coins',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF70350D)),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _box() => BoxDecoration(
  gradient: const LinearGradient(colors: [Color(0xFF5F351D), Color(0xFF2C170D)]),
  borderRadius: BorderRadius.circular(18),
  border: Border.all(color: const Color(0xFFD0924E)),
  boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 4))],
);
String _time(int seconds) => '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
