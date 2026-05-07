import 'package:flutter/material.dart';

import '../model/badge_definition.dart';

class BadgeTile extends StatelessWidget {
  const BadgeTile({
    super.key,
    required this.definition,
    required this.unlocked,
    required this.currentLongestStreak,
  });

  final BadgeDefinition definition;
  final bool unlocked;
  final int currentLongestStreak;

  @override
  Widget build(BuildContext context) {
    final daysAway = definition.threshold - currentLongestStreak;
    final colorScheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: unlocked ? 1.0 : 0.45,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: unlocked ? definition.color : colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(definition.emoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 8),
            Text(
              definition.name,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              unlocked ? '${definition.threshold} days' : '$daysAway more',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
