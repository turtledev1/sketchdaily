import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../streak/bloc/streak_bloc.dart';
import '../../streak/repository/streak_repository.dart';
import '../../streak/widgets/saved_session_dialog.dart';

/// A compact 30-day "did you sketch?" heatmap.
///
/// Sources the set of completed dates from [StreakBloc] rather than
/// [StreakRepository], so it repaints instantly after a session completes
/// without needing to re-read sqflite. The sqflite log remains the source
/// of truth for richer views (session length, timestamps) not rendered here.
class HistoryHeatmap extends StatelessWidget {
  const HistoryHeatmap({super.key, this.days = 30});

  final int days;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);

    return BlocBuilder<StreakBloc, StreakState>(
      buildWhen: (prev, curr) => prev.completedDates != curr.completedDates,
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Last $days days',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.8),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                // Pick a column count that keeps each tile around 16–22px.
                // On a phone width (~360dp padded), 10 cols → tiles ~28dp,
                // which reads clearly and lines up to 3 rows for 30 days.
                const cols = 10;
                final rows = (days + cols - 1) ~/ cols;
                final spacing = 4.0;
                final tileSize = (constraints.maxWidth - spacing * (cols - 1)) / cols;
                return Column(
                  children: [
                    for (int r = 0; r < rows; r++)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: r == rows - 1 ? 0 : spacing,
                        ),
                        child: Row(
                          children: [
                            for (int c = 0; c < cols; c++) ...[
                              if (c > 0) SizedBox(width: spacing),
                              _buildTile(
                                context: context,
                                index: r * cols + c,
                                tileSize: tileSize,
                                startOfToday: startOfToday,
                                completedDates: state.completedDates,
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            _Legend(colorScheme: colorScheme),
          ],
        );
      },
    );
  }

  Widget _buildTile({
    required BuildContext context,
    required int index,
    required double tileSize,
    required DateTime startOfToday,
    required Set<String> completedDates,
  }) {
    // Fill left-to-right, top-to-bottom, oldest → newest. So the last cell
    // (bottom-right) is always "today".
    final offsetFromToday = (days - 1) - index;
    final date = startOfToday.subtract(Duration(days: offsetFromToday));
    final key = StreakRepository.formatDate(date);
    final done = completedDates.contains(key);
    final isToday = offsetFromToday == 0;
    final colorScheme = Theme.of(context).colorScheme;

    final fill = done ? colorScheme.primary : colorScheme.surfaceContainerHighest;
    final border = isToday ? Border.all(color: colorScheme.primary, width: 1.5) : null;

    final tile = Container(
      width: tileSize,
      height: tileSize,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(4),
        border: border,
      ),
    );

    return Tooltip(
      message: '${DateFormat.yMMMd().format(date)} — ${done ? 'sketched' : 'missed'}',
      child: done
          // Wrap completed tiles so tapping replays the reference image.
          // Missed days have nothing to show, so they stay non-interactive.
          ? Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: () => showSavedSessionDialog(context, date: date),
                child: tile,
              ),
            )
          : tile,
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.colorScheme});
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurface.withValues(alpha: 0.6),
    );
    return Row(
      children: [
        _swatch(colorScheme.surfaceContainerHighest),
        const SizedBox(width: 4),
        Text('Missed', style: labelStyle),
        const SizedBox(width: 12),
        _swatch(colorScheme.primary),
        const SizedBox(width: 4),
        Text('Sketched', style: labelStyle),
      ],
    );
  }

  Widget _swatch(Color color) => Container(
    width: 12,
    height: 12,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(3),
    ),
  );
}
