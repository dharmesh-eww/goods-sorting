import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';

class TimeUpScreen extends StatefulWidget {
  const TimeUpScreen({
    super.key,
    required this.levelNumber,
    required this.onRetry,
    required this.onLevels,
  });

  final int levelNumber;
  final VoidCallback onRetry;
  final VoidCallback onLevels;

  @override
  State<TimeUpScreen> createState() => _TimeUpScreenState();
}

class _TimeUpScreenState extends State<TimeUpScreen> with TickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  )..forward();

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _entrance.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF160C08), Color(0xFF4A2015), Color(0xFF8D3D27)],
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _entrance,
            builder: (_, child) => FadeTransition(
              opacity: _entrance,
              child: Transform.translate(
                offset: Offset(0, 24 * (1 - Curves.easeOutBack.transform(_entrance.value))),
                child: child,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 30, 22, 20),
              child: Column(
                children: [
                  const Spacer(),
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, child) {
                      final scale = 1 + .055 * Curves.easeInOut.transform(_pulse.value);
                      return Transform.scale(scale: scale, child: child);
                    },
                    child: Container(
                      width: 150,
                      height: 150,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE6D1),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFFFA65C), width: 4),
                        boxShadow: const [
                          BoxShadow(color: Color(0x668A271B), blurRadius: 25, spreadRadius: 5),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Lottie.asset(
                            'assets/animations/timer_clock.json',
                            width: 76,
                            height: 76,
                            repeat: true,
                            fit: BoxFit.contain,
                          ),
                          SvgPicture.asset(
                            'assets/images/result/alarm_clock.svg',
                            width: 62,
                            height: 62,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "TIME'S UP!",
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1,
                      shadows: [Shadow(color: Color(0x99000000), blurRadius: 8, offset: Offset(0, 4))],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You ran out of time on Level ' + widget.levelNumber.toString() + '.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: .82)),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0x44FFB16D),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0x88FFB16D)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer_off_rounded, color: Color(0xFFFFC078)),
                        SizedBox(width: 8),
                        Text(
                          '00:00',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  _PrimaryButton(label: 'TRY AGAIN', icon: Icons.refresh_rounded, onTap: widget.onRetry),
                  const SizedBox(height: 9),
                  TextButton(
                    onPressed: widget.onLevels,
                    child: const Text(
                      'LEVEL SELECTION',
                      style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFFFD9B5)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 22),
        label: Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: .7)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF07C38),
          foregroundColor: Colors.white,
          elevation: 7,
          shadowColor: const Color(0x99000000),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
            side: const BorderSide(color: Color(0xFFFFB37B)),
          ),
        ),
      ),
    );
  }
}
