import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class LevelSelectionScreen extends StatelessWidget {
  const LevelSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final levels = List.generate(20, (index) => index + 1);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFE8A8), Color(0xFFFFCD6E), Color(0xFFE78C3D)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back)),
                    const Expanded(child: Text('LEVELS', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900))),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(18),
                  itemCount: levels.length,
                  itemBuilder: (_, index) {
                    final level = levels[index];
                    final unlocked = level <= 3;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: unlocked
                              ? SvgPicture.asset('assets/images/products/apple.svg')
                              : const Icon(Icons.lock),
                        ),
                        title: Text('Level $level'),
                        subtitle: Text(unlocked ? 'Ready to play' : 'Complete previous level'),
                        trailing: Icon(unlocked ? Icons.play_arrow_rounded : Icons.lock_rounded),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
