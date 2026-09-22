import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'game_currency.dart';
import 'level_generator.dart';
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

class _UnityStyleGameScreenState extends State<UnityStyleGameScreen>
    with TickerProviderStateMixin {

  late final _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..forward();
  late final _float = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat(reverse: true);
  late final _match = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );

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
    _float.dispose();
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
      history.add(_TrayMove(
        item: item,
        fromTray: fromTray,
        fromPosition: fromPosition,
        toTray: toTray,
        toPosition: toPosition,
      ));
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
    if (trays[move.toTray][move.toPosition] != move.item ||
        trays[move.fromTray][move.fromPosition] != null) {
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

    final items = trays.expand((tray) => tray).toList()
      ..shuffle(math.Random(widget.levelNumber * 37 + moves));

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
      final empty = trays.indexWhere(
        (tray) => tray.every((item) => item == null),
      );
      if (empty >= 0) {
        source = trays.indexWhere(
          (tray) => tray.any((item) => item != null),
        );
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
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0x99000000),
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (_, __, ___) => _ResultPanel(
        win: win,
        level: widget.levelNumber,
        score: score,
        moves: moves,
        earned: earned,
        timedOut: timedOut,
        onPrimary: () {
          Navigator.pop(context);
          if (win && widget.levelNumber < 2500) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => UnityStyleGameScreen(
                  levelNumber: widget.levelNumber + 1,
                ),
              ),
            );
          } else if (!win) {
            _reset();
          } else {
            Navigator.pop(context);
          }
        },
        onLevels: () {
          Navigator.pop(context);
          Navigator.pop(context);
        },
      ),
      transitionBuilder: (_, animation, __, child) => ScaleTransition(
        scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
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
            colors: [Color(0xFFFFF2CF), Color(0xFFF6D18B), Color(0xFFD98B48)],
          ),
        ),
        child: SafeArea(
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
                remaining: trays.fold<int>(
                  0,
                  (sum, tray) => sum + tray.length,
                ),
                total: level.totalItems,
              ),
              Expanded(
                child: AnimatedBuilder(
                  animation: _intro,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(0, 20 * (1 - _intro.value)),
                    child: Opacity(opacity: _intro.value, child: child),
                  ),
                  child: GridView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.35,
                    ),
                    itemCount: trays.length,
                    itemBuilder: (_, index) => _SortingTray(
                      number: index + 1,
                      items: trays[index],
                      float: _float,
                      onDrop: (item, position) {
                        final source = _findItemPosition(item);
                        if (source != null) {
                          _moveItem(item, source.$1, source.$2, index, position);
                        }
                      },
                    ),
                  ),
                ),
              ),
              _Actions(
                moves: moves,
                onUndo: history.isEmpty ? null : _undo,
                onShuffle: _shuffle,
                onHint: _hint,
              ),
            ],
          ),
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
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 42, height: 5, decoration: BoxDecoration(
            color: Color(0xFFC68B51), borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 14),
          const Text('PAUSED', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF653918))),
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
        ]),
      ),
    ).whenComplete(() {
      if (mounted && paused) setState(() => paused = false);
    });
  }
}

class _TopPanel extends StatelessWidget {
  const _TopPanel({required this.level, required this.seconds, required this.totalSeconds, required this.coins, required this.onBack, required this.onPause});
  final int level, seconds, totalSeconds, coins;
  final VoidCallback onBack, onPause;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
    child: Row(children: [
      _CircleButton(Icons.arrow_back_rounded, onBack),
      const SizedBox(width: 8),
      Expanded(child: Container(height: 58, padding: const EdgeInsets.symmetric(horizontal: 12), decoration: _box(), child: Row(children: [
        const Icon(Icons.layers_rounded, color: Color(0xFF70401E)),
        const SizedBox(width: 6),
        Text('LEVEL $level', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF653918))),
        const Spacer(),
        if (totalSeconds > 0) Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Row(children: [const Icon(Icons.timer_rounded, size: 16, color: Color(0xFF9B4D1D)), const SizedBox(width: 3), Text(_time(seconds), style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF653918)))]),
          const SizedBox(height: 4),
          SizedBox(width: 82, child: LinearProgressIndicator(minHeight: 4, value: (seconds / totalSeconds).clamp(0, 1), backgroundColor: const Color(0xFFE2C18F), valueColor: const AlwaysStoppedAnimation(Color(0xFFF18D29)))),
        ]),
        const SizedBox(width: 8),
        _CoinPill(coins),
      ]))),
      const SizedBox(width: 8),
      _CircleButton(Icons.pause_rounded, onPause),
    ]),
  );
}

class _Progress extends StatelessWidget {
  const _Progress({required this.remaining, required this.total});
  final int remaining, total;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(18, 2, 18, 4), child: ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(minHeight: 6, value: total == 0 ? 0 : remaining / total, backgroundColor: const Color(0x66FFFFFF), valueColor: const AlwaysStoppedAnimation(Color(0xFFF18D29)))));
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

class _SortingTray extends StatelessWidget {
  const _SortingTray({
    required this.number,
    required this.items,
    required this.float,
    required this.onDrop,
  });

  final int number;
  final List<SortingItem?> items;
  final Animation<double> float;
  final void Function(SortingItem item, int position) onDrop;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF9A592C), Color(0xFF633317)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Color(0xFFDFA164), width: 2),
          ),
        ),
        Positioned(
          left: 8, right: 8, bottom: 7,
          child: Container(
            height: 10,
            decoration: BoxDecoration(
              color: const Color(0xFF43210F),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        Positioned(
          left: 9, top: 7,
          child: Text('TRAY $number', style: const TextStyle(
            color: Color(0xAAFFE2B5), fontWeight: FontWeight.w900, fontSize: 10)),
        ),
        Positioned(
          right: 9, top: 7,
          child: Text('${items.whereType<SortingItem>().length}/3',
            style: const TextStyle(
              color: Color(0xAAFFE2B5), fontWeight: FontWeight.w900, fontSize: 10)),
        ),
        for (var position = 0; position < 3; position++)
          Positioned(
            left: 8 + position * 53.0,
            top: 30,
            width: 48,
            height: 48,
            child: DragTarget<SortingItem>(
              onWillAcceptWithDetails: (details) => items[position] == null,
              onAcceptWithDetails: (details) => onDrop(details.data, position),
              builder: (context, candidate, rejected) {
                final item = items[position];
                return item == null
                    ? const SizedBox.expand()
                    : _TrayItem(item: item, float: float);
              },
            ),
          ),
      ],
    );
  }
}

class _TrayItem extends StatelessWidget {
  const _TrayItem({required this.item, required this.float});
  final SortingItem item;
  final Animation<double> float;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: float,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, math.sin(float.value * math.pi) * 1.5),
        child: Draggable<SortingItem>(
          data: item,
          maxSimultaneousDrags: 1,
          feedback: Material(
            color: Colors.transparent,
            child: SizedBox(width: 44, height: 44, child: _visual()),
          ),
          childWhenDragging: Opacity(opacity: .25, child: _visual()),
          child: _visual(),
        ),
      ),
    );
  }

  Widget _visual() => SizedBox(
    width: 44,
    height: 44,
    child: SvgPicture.asset(item.asset, fit: BoxFit.contain),
  );
}

class _Actions extends StatelessWidget {
  const _Actions({required this.moves, required this.onUndo, required this.onShuffle, required this.onHint});
  final int moves;
  final VoidCallback? onUndo, onShuffle, onHint;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(14, 3, 14, 9), child: Row(children: [_SmallAction(Icons.shuffle_rounded, 'SHUFFLE', onShuffle), const Spacer(), Text('MOVES $moves', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF663718))), const Spacer(), _SmallAction(Icons.undo_rounded, 'UNDO', onUndo), const SizedBox(width: 7), _SmallAction(Icons.lightbulb_rounded, 'HINT', onHint)]));
}

class _SmallAction extends StatelessWidget {
  const _SmallAction(this.icon, this.label, this.onTap);
  final IconData icon; final String label; final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Opacity(opacity: onTap == null ? .45 : 1, child: GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8), decoration: BoxDecoration(color: const Color(0xFFF8E1B8), borderRadius: BorderRadius.circular(13), border: Border.all(color: const Color(0xFFD0924E))), child: Row(children: [Icon(icon, size: 18, color: const Color(0xFF713A18)), const SizedBox(width: 3), Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Color(0xFF713A18)))]))));
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
          color: const Color(0xFFF9E4BD),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFD0924E)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x44000000),
              blurRadius: 5,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, color: const Color(0xFF713A18)),
      ),
    );
  }
}

class _CoinPill extends StatelessWidget {
  const _CoinPill(this.coins); final int coins;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6), decoration: BoxDecoration(color: const Color(0xFFFFC44D), borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFFD57B20))), child: Row(children: [const Icon(Icons.monetization_on_rounded, size: 17, color: Color(0xFF8D4A0D)), const SizedBox(width: 2), Text('$coins', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF70350D)))]));
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({
    required this.win,
    required this.level,
    required this.score,
    required this.moves,
    required this.earned,
    required this.timedOut,
    required this.onPrimary,
    required this.onLevels,
  });

  final bool win;
  final bool timedOut;
  final int level;
  final int score;
  final int moves;
  final int earned;
  final VoidCallback onPrimary;
  final VoidCallback onLevels;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE8BC),
              borderRadius: BorderRadius.circular(29),
              border: Border.all(
                color: const Color(0xFFD18A43),
                width: 2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x99000000),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    color: win
                        ? const Color(0xFFFFB52E)
                        : const Color(0xFFE66E43),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    win
                        ? Icons.emoji_events_rounded
                        : Icons.close_rounded,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  win ? 'LEVEL COMPLETE!' : 'LEVEL FAILED',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF653918),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  win
                      ? 'Great sorting! The shelf is clean.'
                      : timedOut
                          ? 'Time is up. Try again.'
                          : 'No sorting space left. Try another order.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8B5B36),
                  ),
                ),
                if (win)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.star_rounded,
                            size: 34, color: Color(0xFFFFB51D)),
                        SizedBox(width: 4),
                        Icon(Icons.star_rounded,
                            size: 43, color: Color(0xFFFFB51D)),
                        SizedBox(width: 4),
                        Icon(Icons.star_rounded,
                            size: 34, color: Color(0xFFFFB51D)),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _Stat('LEVEL', '$level'),
                    _Stat('SCORE', '$score'),
                    _Stat('MOVES', '$moves'),
                  ],
                ),
                if (win)
                  Padding(
                    padding: const EdgeInsets.only(top: 11),
                    child: Text(
                      '+$earned COINS',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF80400A),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                _WideButton(
                  win ? 'NEXT' : 'TRY AGAIN',
                  win ? Icons.arrow_forward_rounded : Icons.refresh_rounded,
                  onPrimary,
                ),
                TextButton(
                  onPressed: onLevels,
                  child: const Text(
                    'LEVELS',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF754522),
                    ),
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

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value); final String label, value;
  @override
  Widget build(BuildContext context) => Expanded(child: Container(margin: const EdgeInsets.symmetric(horizontal: 3), padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: const Color(0xFFF8D8A6), borderRadius: BorderRadius.circular(13)), child: Column(children: [Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Color(0xFF8B5B36))), const SizedBox(height: 2), Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF653918)))])));
}

class _WideButton extends StatelessWidget {
  const _WideButton(this.label, this.icon, this.onTap); final String label; final IconData icon; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(width: double.infinity, height: 54, child: ElevatedButton.icon(onPressed: onTap, icon: Icon(icon), label: Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: .8)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF19A24), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))));
}

BoxDecoration _box() => BoxDecoration(color: const Color(0xFFF9E6C1), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFD0924E)), boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 5, offset: Offset(0, 3))]);
String _time(int seconds) => '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
