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
  static const itemsPerTray = 3;
  static const extraTrays = 1;

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
  final trays = <List<SortingItem>>[];
  final removed = <SortingItem>{};
  final history = <_TrayMove>[];
  Timer? timer;

  int secondsLeft = 0;
  int moves = 0;
  int score = 0;
  int coins = GameCurrency.defaultCoins;
  bool timerStarted = false;
  bool paused = false;
  bool gameOver = false;
  bool completionSaved = false;
  SortingItem? hint;
  List<SortingItem>? _runtimeItems;

  @override
  void initState() {
    super.initState();
    secondsLeft = level.timerSeconds;
    final trayCount = (level.totalItems + itemsPerTray - 1) ~/ itemsPerTray + extraTrays;
    trays.addAll(List.generate(trayCount, (_) => <SortingItem>[]));
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

  List<List<SortingItem>> get _runtimeShelves {
    final source = _runtimeItems ?? level.items;
    return List.generate(
      level.shelfCount,
      (shelf) => source
          .where((x) => x.shelfIndex == shelf && !removed.contains(x))
          .toList()
        ..sort((a, b) => a.stackIndex.compareTo(b.stackIndex)),
    );
  }

  SortingItem? _top(List<SortingItem> items) => items.isEmpty
      ? null
      : items.reduce((a, b) => a.stackIndex > b.stackIndex ? a : b);

  bool _accessible(SortingItem item) {
    for (final shelf in _runtimeShelves) {
      if (shelf.any((x) => x == item)) return _top(shelf) == item;
    }
    return false;
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

  void _moveItemToTray(SortingItem item, int trayIndex) {
    if (paused || gameOver || trayIndex < 0 || trayIndex >= trays.length) return;
    final target = trays[trayIndex];
    if (target.length >= itemsPerTray) {
      _toast('Tray is full');
      return;
    }
    final sourceTrayIndex = trays.indexWhere((tray) => tray.contains(item));
    if (sourceTrayIndex == trayIndex) return;
    if (sourceTrayIndex == -1 && !_accessible(item)) {
      _toast('Move the top item first');
      return;
    }

    final sourceIndex = sourceTrayIndex >= 0
        ? trays[sourceTrayIndex].indexOf(item)
        : -1;

    _startTimer();
    setState(() {
      if (sourceTrayIndex >= 0) {
        trays[sourceTrayIndex].removeAt(sourceIndex);
      } else {
        removed.add(item);
      }
      target.add(item);
      history.add(
        _TrayMove(
          item: item,
          fromTray: sourceTrayIndex,
          fromIndex: sourceIndex,
          toTray: trayIndex,
        ),
      );
      hint = null;
      moves++;
    });
    _checkMatch(trayIndex);
  }

  void _checkMatch(int trayIndex) {
    final target = trays[trayIndex];
    if (target.length != itemsPerTray) {
      _checkLose();
      _checkWin();
      return;
    }
    final productId = target.first.productId;
    if (!target.every((item) => item.productId == productId)) {
      _checkLose();
      _checkWin();
      return;
    }
    final matched = List<SortingItem>.from(target);
    _match.forward(from: 0).then((_) {
      if (!mounted || gameOver) return;
      setState(() {
        target.clear();
        history.removeWhere((move) => matched.contains(move.item));
        score += 30;
      });
      _checkWin();
      _checkLose();
    });
  }

  void _checkWin() {
    if (removed.length == level.totalItems &&
        trays.every((tray) => tray.isEmpty) &&
        !gameOver) {
      _finish(true);
    }
  }

  void _checkLose() {
    if (gameOver || trays.isEmpty) return;
    if (!trays.every((tray) => tray.length >= itemsPerTray)) return;
    Future<void>.delayed(const Duration(milliseconds: 180), () {
      if (mounted && !gameOver && trays.every((tray) => tray.length >= itemsPerTray)) {
        _finish(false);
      }
    });
  }

  void _undo() {
    if (history.isEmpty || paused || gameOver) return;
    final move = history.removeLast();
    if (!trays[move.toTray].remove(move.item)) return;

    setState(() {
      if (move.fromTray >= 0) {
        final source = trays[move.fromTray];
        final insertIndex = move.fromIndex.clamp(0, source.length);
        source.insert(insertIndex, move.item);
      } else {
        removed.remove(move.item);
      }
      moves = math.max(0, moves - 1);
      score = math.max(0, score - 1);
      hint = null;
    });
  }

  Future<void> _shuffle() async {
    if (paused || gameOver || coins < 5) {
      if (coins < 5) _toast('Need 5 coins');
      return;
    }
    final active = level.items.where((x) => !removed.contains(x)).toList()
      ..shuffle(math.Random(widget.levelNumber * 37 + moves));
    final spent = await GameCurrency.instance.spend(5);
    if (!spent || !mounted) return;
    final buckets = List.generate(level.shelfCount, (_) => <SortingItem>[]);
    for (var i = 0; i < active.length; i++) {
      buckets[i % buckets.length].add(active[i]);
    }
    final items = <SortingItem>[];
    for (var shelf = 0; shelf < buckets.length; shelf++) {
      for (var i = 0; i < buckets[shelf].length; i++) {
        final item = buckets[shelf][i];
        items.add(SortingItem(itemId: item.itemId, productId: item.productId, asset: item.asset, stackIndex: i, shelfIndex: shelf));
      }
    }
    setState(() {
      coins = GameCurrency.instance.coins;
      hint = null;
      _runtimeItems = List.unmodifiable(items);
    });
  }

  Future<void> _hint() async {
    if (paused || gameOver || coins < 3) {
      if (coins < 3) _toast('Need 3 coins');
      return;
    }
    final tops = <SortingItem>[];
    for (final shelf in _runtimeShelves) {
      final top = _top(shelf);
      if (top != null) tops.add(top);
    }
    if (tops.isEmpty) return;
    final target = tops.firstWhere(
      (x) => tops.any((y) => y.productId == x.productId && y != x),
      orElse: () => tops.first,
    );
    final spent = await GameCurrency.instance.spend(3);
    if (!spent || !mounted) return;
    setState(() {
      coins = GameCurrency.instance.coins;
      hint = target;
    });
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted && hint == target) setState(() => hint = null);
    });
  }

  void _reset() {
    timer?.cancel();
    setState(() {
      for (final tray in trays) {
        tray.clear();
      }
      removed.clear();
      history.clear();
      _runtimeItems = null;
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
    final board = _runtimeShelves;
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
              _Progress(remaining: removed.length, total: level.totalItems),
              Expanded(
                child: AnimatedBuilder(
                  animation: _intro,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(0, 20 * (1 - _intro.value)),
                    child: Opacity(opacity: _intro.value, child: child),
                  ),
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                    itemCount: board.length,
                    itemBuilder: (_, i) => _Shelf(
                      number: i + 1,
                      items: board[i],
                      top: _top(board[i]),
                      hint: hint,
                      float: _float,
                      onTap: _tapItem,
                    ),
                  ),
                ),
              ),
              _SortingTrays(trays: trays, onDrop: _moveItemToTray),
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

class _Shelf extends StatelessWidget {
  const _Shelf({
    required this.number,
    required this.items,
    required this.top,
    required this.hint,
    required this.float,
    required this.onTap,
  });

  final int number;
  final List<SortingItem> items;
  final SortingItem? top;
  final SortingItem? hint;
  final Animation<double> float;
  final ValueChanged<SortingItem> onTap;

  @override
  Widget build(BuildContext context) {
    final height = math.max(86.0, 65 + math.min(items.length, 9) * 18.0);

    return Container(
      height: height,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF9A592C), Color(0xFF633317)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDFA164), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x44000000),
            blurRadius: 7,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 8,
            right: 8,
            bottom: 7,
            child: Container(
              height: 12,
              decoration: BoxDecoration(
                color: const Color(0xFF43210F),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          Positioned(
            left: 9,
            top: 7,
            child: Text(
              '$number',
              style: const TextStyle(
                color: Color(0x99FFE2B5),
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
          ),
          for (var i = 0; i < items.length; i++)
            _ShelfItem(
              item: items[i],
              top: top,
              hint: hint,
              bottom: 14 + i * 18.0,
              float: float,
              onTap: onTap,
            ),
        ],
      ),
    );
  }
}

class _ShelfItem extends StatelessWidget {
  const _ShelfItem({required this.item, required this.top, required this.hint, required this.bottom, required this.float, required this.onTap});
  final SortingItem item;
  final SortingItem? top;
  final SortingItem? hint;
  final double bottom;
  final Animation<double> float;
  final ValueChanged<SortingItem> onTap;

  Widget _visual(bool accessible) => Container(
    height: 58,
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: item == hint ? const Color(0xFFFFD22E) : const Color(0xFFE2C39F), width: item == hint ? 3 : 2),
      boxShadow: [BoxShadow(color: item == hint ? const Color(0x88FFD22E) : const Color(0x55000000), blurRadius: item == hint ? 12 : 5, offset: const Offset(0, 3))],
    ),
    child: Opacity(opacity: accessible ? 1 : .72, child: SvgPicture.asset(item.asset)),
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: float,
    builder: (_, __) {
      final accessible = item == top;
      final y = accessible ? math.sin(float.value * math.pi) * 2 : 0;
      return Positioned(
        left: 22,
        right: 22,
        bottom: bottom + y,
        child: accessible
            ? Draggable<SortingItem>(
                data: item,
                maxSimultaneousDrags: 1,
                feedback: Material(color: Colors.transparent, child: SizedBox(width: 150, child: _visual(true))),
                childWhenDragging: Opacity(opacity: .25, child: _visual(true)),
                child: GestureDetector(onTap: () => onTap(item), child: _visual(true)),
              )
            : _visual(false),
      );
    },
  );
}

class _SortingTrays extends StatelessWidget {
  const _SortingTrays({required this.trays, required this.onDrop});
  final List<List<SortingItem>> trays;
  final void Function(SortingItem item, int trayIndex) onDrop;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(10, 0, 10, 4),
    padding: const EdgeInsets.fromLTRB(8, 9, 8, 8),
    decoration: BoxDecoration(color: const Color(0xDD5A3018), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFDDA05A), width: 2)),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Padding(
        padding: EdgeInsets.only(bottom: 7),
        child: Row(children: [
          Icon(Icons.inventory_2_rounded, size: 15, color: Color(0xFFFFD69A)),
          SizedBox(width: 5),
          Text('SORTING TRAYS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1, color: Color(0xFFFFE6C2))),
          Spacer(),
          Text('3 ITEMS / TRAY', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Color(0xFFD9AD7A))),
        ]),
      ),
      ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 190),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Wrap(
            spacing: 7,
            runSpacing: 7,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < trays.length; i++)
                _SortingTray(index: i, items: trays[i], onDrop: (item) => onDrop(item, i)),
            ],
          ),
        ),
      ),
    ]),
  );
}

class _SortingTray extends StatelessWidget {
  const _SortingTray({required this.index, required this.items, required this.onDrop});
  final int index;
  final List<SortingItem> items;
  final ValueChanged<SortingItem> onDrop;

  Color get _accent {
    const accents = [Color(0xFFE9A13A), Color(0xFF73B7A2), Color(0xFF9C8DD8), Color(0xFFE47B72), Color(0xFF6EA7D9)];
    return accents[index % accents.length];
  }

  @override
  Widget build(BuildContext context) => DragTarget<SortingItem>(
    onWillAcceptWithDetails: (details) => items.length < itemsPerTray && !items.contains(details.data),
    onAcceptWithDetails: (details) => onDrop(details.data),
    builder: (context, candidates, rejected) {
      final active = candidates.isNotEmpty;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 108,
        height: 72,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: active ? _accent.withOpacity(.28) : const Color(0xFF6D3B20),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: active ? _accent : const Color(0xFFA86A3A), width: active ? 3 : 1.5),
          boxShadow: [BoxShadow(color: active ? _accent.withOpacity(.35) : const Color(0x44000000), blurRadius: active ? 12 : 4, offset: const Offset(0, 3))],
        ),
        child: Row(children: [
          SizedBox(
            width: 17,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text((index + 1).toString(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFFFFE1B5))),
              const SizedBox(height: 3),
              Container(width: 5, height: 20, decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(5))),
            ]),
          ),
          const SizedBox(width: 3),
          Expanded(
            child: Row(
              children: List.generate(
                itemsPerTray,
                (slot) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: slot < items.length
                        ? Draggable<SortingItem>(
                            data: items[slot],
                            maxSimultaneousDrags: 1,
                            feedback: Material(
                              color: Colors.transparent,
                              child: SizedBox(
                                width: 58,
                                height: 58,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 4))]),
                                  child: SvgPicture.asset(items[slot].asset),
                                ),
                              ),
                            ),
                            childWhenDragging: Opacity(opacity: .2, child: _TraySlot(items[slot])),
                            child: _TraySlot(items[slot]),
                          )
                        : _EmptyTraySlot(accent: _accent),
                  ),
                ),
              ),
            ),
          ),
        ]),
      );
    },
  );
}

class _TraySlot extends StatelessWidget {
  const _TraySlot(this.item);
  final SortingItem item;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(2),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9), border: Border.all(color: const Color(0xFFE6C9A4))),
    child: SvgPicture.asset(item.asset),
  );
}

class _EmptyTraySlot extends StatelessWidget {
  const _EmptyTraySlot({required this.accent});
  final Color accent;
  @override
  Widget build(BuildContext context) => Container(
    height: double.infinity,
    decoration: BoxDecoration(color: const Color(0x33200E07), borderRadius: BorderRadius.circular(9), border: Border.all(color: accent.withOpacity(.45))),
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

class _TrayMove {
  const _TrayMove({
    required this.item,
    required this.fromTray,
    required this.fromIndex,
    required this.toTray,
  });

  final SortingItem item;
  final int fromTray;
  final int fromIndex;
  final int toTray;
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
