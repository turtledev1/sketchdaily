import 'package:flutter/material.dart';

class BadgeDefinition {
  const BadgeDefinition({
    required this.threshold,
    required this.name,
    required this.description,
    required this.emoji,
    required this.color,
  });

  /// Consecutive-days streak needed to unlock this badge.
  final int threshold;
  final String name;
  final String description;
  final String emoji;
  final Color color;
}

class BadgeDefinitions {
  const BadgeDefinitions._();

  static const List<BadgeDefinition> all = [
    BadgeDefinition(
      threshold: 3,
      name: 'Warm-up',
      description: 'Three days in a row. The hardest part is starting.',
      emoji: '✏️',
      color: Color(0xFFBEE3F8),
    ),
    BadgeDefinition(
      threshold: 7,
      name: 'One Week',
      description: 'A full week of daily sketching.',
      emoji: '📓',
      color: Color(0xFF9AE6B4),
    ),
    BadgeDefinition(
      threshold: 14,
      name: 'Fortnight',
      description: 'Two weeks — the habit is taking root.',
      emoji: '🎨',
      color: Color(0xFFFAF089),
    ),
    BadgeDefinition(
      threshold: 30,
      name: 'Month of Marks',
      description: 'Thirty consecutive days. You\'re an artist now.',
      emoji: '🖌️',
      color: Color(0xFFFBD38D),
    ),
    BadgeDefinition(
      threshold: 60,
      name: 'Steady Hand',
      description: 'Sixty days. Muscle memory is real.',
      emoji: '✋',
      color: Color(0xFFF6AD55),
    ),
    BadgeDefinition(
      threshold: 100,
      name: 'Centurion',
      description: 'One hundred drawings. Remarkable.',
      emoji: '💯',
      color: Color(0xFFFC8181),
    ),
    BadgeDefinition(
      threshold: 180,
      name: 'Half-Year',
      description: 'Half a year of daily practice.',
      emoji: '🌓',
      color: Color(0xFFB794F4),
    ),
    BadgeDefinition(
      threshold: 365,
      name: 'Year of Art',
      description: 'A full year. Simply extraordinary.',
      emoji: '🏆',
      color: Color(0xFFE87A3A),
    ),
  ];

  static List<int> get thresholds =>
      all.map((b) => b.threshold).toList(growable: false);

  static BadgeDefinition? forThreshold(int threshold) {
    for (final b in all) {
      if (b.threshold == threshold) return b;
    }
    return null;
  }
}
