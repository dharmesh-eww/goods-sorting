import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

void main() {
  runApp(const GoodsSortingApp());
}

class GoodsSortingApp extends StatelessWidget {
  const GoodsSortingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Goods Sorting',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFFB72B)),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFE8A8),
              Color(0xFFFFD47A),
              Color(0xFFF4A64A),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const _HomeHeader(),
              Expanded(
                child: Stack(
                  children: [
                    const Positioned.fill(child: _StoreScene()),
                    Positioned(
                      left: 24,
                      right: 24,
                      bottom: 28,
                      child: _LevelCard(onPlay: () {}),
                    ),
                  ],
                ),
              ),
              const _BottomNavigation(),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          const _RoundButton(icon: Icons.person_rounded),
          const Spacer(),
          const _CurrencyChip(icon: Icons.monetization_on_rounded, value: '1,250'),
          const SizedBox(width: 8),
          const _CurrencyChip(icon: Icons.favorite_rounded, value: '5'),
          const SizedBox(width: 8),
          const _RoundButton(icon: Icons.settings_rounded),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: .9),
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {},
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icon, color: const Color(0xFF5B3A20), size: 24),
        ),
      ),
    );
  }
}

class _CurrencyChip extends StatelessWidget {
  const _CurrencyChip({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .92),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(blurRadius: 5, offset: Offset(0, 2), color: Color(0x33000000))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFFFFA800), size: 22),
          const SizedBox(width: 5),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF5B3A20))),
        ],
      ),
    );
  }
}

class _StoreScene extends StatelessWidget {
  const _StoreScene();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 170),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF4D5), Color(0xFFFFDFA0)],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: .8), width: 3),
          boxShadow: const [BoxShadow(blurRadius: 14, offset: Offset(0, 7), color: Color(0x33000000))],
        ),
        child: Stack(
          children: [
            Positioned(
              top: 20,
              left: 24,
              right: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  _FeatureBubble(icon: Icons.card_giftcard_rounded, label: 'Daily'),
                  _FeatureBubble(icon: Icons.emoji_events_rounded, label: 'Awards'),
                ],
              ),
            ),
            const Positioned(
              top: 78,
              left: 0,
              right: 0,
              child: Text(
                'MY MARKET',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2, color: Color(0xFF70451E)),
              ),
            ),
            const Positioned(
              left: 26,
              right: 26,
              top: 120,
              bottom: 18,
              child: _Shelves(),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureBubble extends StatelessWidget {
  const _FeatureBubble({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(blurRadius: 7, offset: Offset(0, 3), color: Color(0x30000000))],
            ),
            child: Icon(icon, color: Color(0xFFFF9F1C), size: 27),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF70451E))),
        ],
      ),
    );
  }
}

class _Shelves extends StatelessWidget {
  const _Shelves();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: const [
        _Shelf(items: ['assets/images/products/can.svg', 'assets/images/products/juice.svg', 'assets/images/products/cookies.svg', 'assets/images/products/milk.svg']),
        _Shelf(items: ['assets/images/products/apple.svg', 'assets/images/products/shampoo.svg', 'assets/images/products/juice.svg', 'assets/images/products/chocolate.svg']),
        _Shelf(items: ['assets/images/products/milk.svg', 'assets/images/products/cookies.svg', 'assets/images/products/can.svg', 'assets/images/products/apple.svg']),
      ],
    );
  }
}

class _Shelf extends StatelessWidget {
  const _Shelf({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 82,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF9A5A2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF6D3D20), width: 3),
        boxShadow: const [BoxShadow(blurRadius: 4, offset: Offset(0, 4), color: Color(0x55000000))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items.map((asset) => _Product(asset: asset)).toList(),
      ),
    );
  }
}

class _Product extends StatelessWidget {
  const _Product({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        boxShadow: const [BoxShadow(blurRadius: 3, offset: Offset(0, 2), color: Color(0x44000000))],
      ),
      child: SvgPicture.asset(asset, width: 39, height: 53, fit: BoxFit.contain),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.onPlay});

  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .96),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(blurRadius: 12, offset: Offset(0, 6), color: Color(0x44000000))],
      ),
      child: Column(
        children: [
          const Text('LEVEL 1', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Color(0xFF6C431F))),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: const LinearProgressIndicator(minHeight: 9, value: 0, backgroundColor: Color(0xFFEBD8BC), valueColor: AlwaysStoppedAnimation(Color(0xFFFFB52E))),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: onPlay,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFA914),
                foregroundColor: Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              child: const Text('PLAY', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(blurRadius: 12, offset: Offset(0, -4), color: Color(0x30000000))],
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(icon: Icons.home_rounded, label: 'Home', selected: true),
          _NavItem(icon: Icons.map_rounded, label: 'Levels'),
          _NavItem(icon: Icons.card_giftcard_rounded, label: 'Events'),
          _NavItem(icon: Icons.shopping_bag_rounded, label: 'Shop'),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, this.selected = false});

  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFFFFA914) : const Color(0xFF8A7765);
    return SizedBox(
      width: 70,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 27),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.w900 : FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
