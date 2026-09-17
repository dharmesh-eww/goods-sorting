import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'game/goods_sorting_game_screen.dart';
import 'game/level_generator.dart';
import 'game/level_progress.dart';

class LevelSelectionScreen extends StatefulWidget {
  const LevelSelectionScreen({super.key});
  @override
  State<LevelSelectionScreen> createState() => _LevelSelectionScreenState();
}

class _LevelSelectionScreenState extends State<LevelSelectionScreen> with SingleTickerProviderStateMixin {
  static const totalLevels = 2500;
  final progress = LevelProgress.instance;
  late final AnimationController controller;
  bool loading = true;
  int selected = 1;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();
    _load();
  }

  Future<void> _load() async {
    await progress.load();
    if (mounted) setState(() { selected = progress.currentLevel; loading = false; });
  }

  @override
  void dispose() { controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final highest = progress.highestUnlockedLevel;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFE8A8), Color(0xFFFFCD6E), Color(0xFFE78C3D)])),
        child: SafeArea(child: Column(children: [
          _Header(onBack: () => Navigator.pop(context)),
          _Journey(current: highest, completed: progress.completedLevels.length, controller: controller),
          Expanded(child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
            itemCount: totalLevels,
            itemBuilder: (context, index) {
              final number = index + 1;
              final data = LevelGenerator.generate(number);
              final unlocked = progress.isUnlocked(number);
              final completed = progress.isCompleted(number);
              final current = progress.isCurrent(number);
              final animation = CurvedAnimation(parent: controller, curve: Interval((index * .015).clamp(0.0, .45), ((index * .015) + .45).clamp(.45, 1.0), curve: Curves.easeOutCubic));
              return AnimatedBuilder(animation: animation, builder: (_, child) => Opacity(opacity: animation.value, child: Transform.translate(offset: Offset(0, 18 * (1 - animation.value)), child: child)), child: Padding(padding: const EdgeInsets.only(bottom: 12), child: _LevelTile(number: number, unlocked: unlocked, completed: completed, current: current, selected: selected == number, difficulty: _difficultyName(data.difficulty), progress: completed ? 1 : current ? .04 : 0, onTap: unlocked ? () => setState(() => selected = number) : null, onPlay: unlocked ? () => _play(number) : null)));
            },
          )),
        ])),
      ),
    );
  }

  Future<void> _play(int levelNumber) async {
    await progress.markLevelOpened(levelNumber);
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => GoodsSortingGameScreen(levelNumber: levelNumber)));
    if (mounted) setState(() {});
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack}); final VoidCallback onBack;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 7), child: Row(children: [_CircleButton(icon: Icons.arrow_back_rounded, onTap: onBack), const SizedBox(width: 12), const Expanded(child: Text('LEVELS', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: 2, color: Color(0xFF623D1F)))), _Resource(asset: 'assets/images/products/apple.svg', value: '1,250'), const SizedBox(width: 7), _Resource(icon: Icons.favorite_rounded, value: '5')]));
}

class _Journey extends StatelessWidget {
  const _Journey({required this.current, required this.completed, required this.controller});
  final int current, completed; final AnimationController controller;
  @override
  Widget build(BuildContext context) => FadeTransition(opacity: controller, child: Container(margin: const EdgeInsets.fromLTRB(18, 3, 18, 5), padding: const EdgeInsets.all(14), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFFFBF0), Color(0xFFFFE1A1)]), borderRadius: BorderRadius.circular(23), border: Border.all(color: Colors.white, width: 2), boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 11, offset: Offset(0, 6))]), child: Row(children: [Container(width: 55, height: 55, padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: const Color(0xFFFFB52E), borderRadius: BorderRadius.circular(17), border: Border.all(color: Colors.white, width: 2)), child: SvgPicture.asset('assets/images/products/apple.svg')), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('MARKET JOURNEY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1, color: Color(0xFF97704B))), const SizedBox(height: 3), Text('$completed completed • Level $current unlocked', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF633E20)))])), const Icon(Icons.auto_awesome_rounded, color: Color(0xFFFFA914), size: 27)])));
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({required this.number, required this.unlocked, required this.completed, required this.current, required this.selected, required this.difficulty, required this.progress, this.onTap, this.onPlay});
  final int number; final bool unlocked, completed, current, selected; final String difficulty; final double progress; final VoidCallback? onTap, onPlay;
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap, child: AnimatedContainer(duration: const Duration(milliseconds: 180), padding: const EdgeInsets.all(12), decoration: BoxDecoration(gradient: LinearGradient(colors: unlocked ? const [Color(0xFFFFFCF2), Color(0xFFFFE4AB)] : const [Color(0xFFE5D0B0), Color(0xFFD1B38B)]), borderRadius: BorderRadius.circular(23), border: Border.all(color: current ? const Color(0xFFFF8C00) : selected ? const Color(0xFFFFB52E) : Colors.white.withValues(alpha: .75), width: current ? 3 : 2), boxShadow: [BoxShadow(color: const Color(0x50000000), blurRadius: current ? 13 : 8, offset: const Offset(0, 6))]), child: Row(children: [_Badge(number: number, unlocked: unlocked, completed: completed), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Text(current ? 'CURRENT • Level $number' : '$difficulty • Level $number', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: unlocked ? const Color(0xFF633E20) : const Color(0xFF806B54)))), if (completed) const Icon(Icons.check_circle_rounded, color: Color(0xFF55A34A), size: 21) else if (!unlocked) const Icon(Icons.lock_rounded, color: Color(0xFF8D765D), size: 20) else if (current) const Icon(Icons.play_circle_fill_rounded, color: Color(0xFFFF9715), size: 22)]), const SizedBox(height: 7), ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(minHeight: 8, value: progress, backgroundColor: const Color(0xFFD8C09D), valueColor: const AlwaysStoppedAnimation(Color(0xFFFFA914)))), const SizedBox(height: 5), Text(completed ? 'Completed' : current ? 'Play this level now' : unlocked ? 'Unlocked' : 'Complete previous level', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF98724C)))])), const SizedBox(width: 9), _Play(enabled: unlocked, onTap: onPlay)]));
}

class _Badge extends StatelessWidget {
  const _Badge({required this.number, required this.unlocked, required this.completed});
  final int number; final bool unlocked, completed;
  @override
  Widget build(BuildContext context) => Container(width: 62, height: 70, decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: unlocked ? const [Color(0xFFFFCA4C), Color(0xFFF18A11)] : const [Color(0xFFB8A38A), Color(0xFF8D775E)]), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white, width: 2), boxShadow: const [BoxShadow(color: Color(0x50000000), blurRadius: 5, offset: Offset(0, 4))]), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(completed ? Icons.check_rounded : unlocked ? Icons.shopping_basket_rounded : Icons.lock_rounded, color: Colors.white, size: 21), Text('$number', style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: Colors.white, height: 1))]));
}

class _Play extends StatelessWidget {
  const _Play({required this.enabled, required this.onTap}); final bool enabled; final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(color: Colors.transparent, child: InkWell(customBorder: const CircleBorder(), onTap: onTap, child: Container(width: 50, height: 50, decoration: BoxDecoration(gradient: LinearGradient(colors: enabled ? const [Color(0xFFFFC94B), Color(0xFFF28C12)] : const [Color(0xFFB9A48B), Color(0xFF8F795F)]), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2), boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 6, offset: Offset(0, 4))]), child: Icon(enabled ? Icons.play_arrow_rounded : Icons.lock_rounded, color: Colors.white, size: 29))));
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap}); final IconData icon; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(color: Colors.white.withValues(alpha: .92), shape: const CircleBorder(), elevation: 4, child: InkWell(customBorder: const CircleBorder(), onTap: onTap, child: SizedBox(width: 45, height: 45, child: Icon(icon, color: const Color(0xFF633E20), size: 24))));
}

class _Resource extends StatelessWidget {
  const _Resource({this.asset, this.icon, required this.value}); final String? asset; final IconData? icon; final String value;
  @override
  Widget build(BuildContext context) => Container(height: 38, padding: const EdgeInsets.symmetric(horizontal: 8), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .92), borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Color(0x30000000), blurRadius: 5, offset: Offset(0, 2))]), child: Row(children: [if (asset != null) SizedBox(width: 24, height: 24, child: SvgPicture.asset(asset!)) else Icon(icon, size: 19, color: const Color(0xFFF05D62)), const SizedBox(width: 5), Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF633E20)))]));
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
