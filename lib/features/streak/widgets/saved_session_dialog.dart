import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/unsplash_config.dart';
import '../repository/streak_repository.dart';

/// Looks up the saved sketch session for [date] and shows it in a dialog.
/// Used both from the heatmap (tap a past day) and the home page
/// (tap "view today's sketch" after completing).
Future<void> showSavedSessionDialog(
  BuildContext context, {
  required DateTime date,
}) async {
  final repository = context.read<StreakRepository>();
  final record = await repository.sessionForDate(date);
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) => SavedSessionDialog(date: date, record: record),
  );
}

class SavedSessionDialog extends StatelessWidget {
  const SavedSessionDialog({super.key, required this.date, required this.record});

  final DateTime date;
  final SketchSessionRecord? record;

  Future<void> _open(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateLabel = DateFormat.yMMMMd().format(date);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dateLabel, style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              if (record == null)
                // Defensive: heatmap said "done" but DB has no row. Can
                // happen if the user wipes the DB without resetting the
                // hydrated streak state.
                const Text('No saved session for this day.')
              else
                _SavedImage(record: record!, onOpenLink: _open),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedImage extends StatelessWidget {
  const _SavedImage({required this.record, required this.onOpenLink});

  final SketchSessionRecord record;
  final Future<void> Function(Uri) onOpenLink;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final linkStyle = theme.textTheme.bodySmall?.copyWith(
      decoration: TextDecoration.underline,
      color: theme.colorScheme.primary,
    );

    final photographerUri = Uri.parse(
      '${record.photographerProfileUrl}'
      '?utm_source=${UnsplashConfig.utmSource}'
      '&utm_medium=${UnsplashConfig.utmMedium}',
    );
    final unsplashUri = Uri.parse(
      'https://unsplash.com/?utm_source=${UnsplashConfig.utmSource}'
      '&utm_medium=${UnsplashConfig.utmMedium}',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: CachedNetworkImage(
              imageUrl: record.imageUrl,
              fit: BoxFit.cover,
              placeholder: (_, _) =>
                  const Center(child: CircularProgressIndicator()),
              errorWidget: (_, _, _) => const Center(
                child: Icon(Icons.broken_image_outlined),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Sketched for '
          '${(record.durationSeconds / 60).toStringAsFixed(1)} min',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          children: [
            Text('Photo by ', style: theme.textTheme.bodySmall),
            GestureDetector(
              onTap: () => onOpenLink(photographerUri),
              child: Text(record.photographerName, style: linkStyle),
            ),
            Text(' on ', style: theme.textTheme.bodySmall),
            GestureDetector(
              onTap: () => onOpenLink(unsplashUri),
              child: Text('Unsplash', style: linkStyle),
            ),
          ],
        ),
      ],
    );
  }
}
