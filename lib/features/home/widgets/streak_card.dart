import 'package:flutter/material.dart';

class StreakCard extends StatefulWidget {
  const StreakCard({
    super.key,
    required this.currentStreak,
    required this.longestStreak,
    required this.completedToday,
  });

  final int currentStreak;
  final int longestStreak;
  final bool completedToday;

  @override
  State<StreakCard> createState() => _StreakCardState();
}

class _StreakCardState extends State<StreakCard> {
  /// Previous value fed to the count-up tween. We seed it equal to the
  /// first-observed `currentStreak` so cold starts don't animate from 0,
  /// which would feel like a lie ("you just got 5 days!") every launch.
  late int _previousStreak = widget.currentStreak;

  @override
  void didUpdateWidget(covariant StreakCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentStreak != widget.currentStreak) {
      _previousStreak = oldWidget.currentStreak;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: colorScheme.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Text(
              '🔥',
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TweenAnimationBuilder<int>(
                    tween: IntTween(
                      begin: _previousStreak,
                      end: widget.currentStreak,
                    ),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => Text(
                      '$value day${value == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  Text(
                    widget.completedToday
                        ? 'You\'ve sketched today. Nice.'
                        : 'Keep the streak alive.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Longest streak: ${widget.longestStreak}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onPrimaryContainer
                              .withValues(alpha: 0.75),
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
