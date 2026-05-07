import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../streak/bloc/streak_bloc.dart';
import '../model/badge_definition.dart';
import '../widgets/badge_tile.dart';

class BadgesPage extends StatelessWidget {
  const BadgesPage({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (_) => const BadgesPage());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Badges')),
      body: BlocBuilder<StreakBloc, StreakState>(
        builder: (context, state) {
          final longest = state.longestStreak;
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.9,
            ),
            itemCount: BadgeDefinitions.all.length,
            itemBuilder: (context, index) {
              final def = BadgeDefinitions.all[index];
              return BadgeTile(
                definition: def,
                unlocked: longest >= def.threshold,
                currentLongestStreak: longest,
              );
            },
          );
        },
      ),
    );
  }
}
