import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../badges/view/badges_page.dart';
import '../../celebration/view/celebration_dialog.dart';
import '../../settings/view/settings_page.dart';
import '../../sketch_session/view/sketch_session_page.dart';
import '../../streak/bloc/streak_cubit.dart';
import '../../streak/widgets/saved_session_dialog.dart';
import '../widgets/history_heatmap.dart';
import '../widgets/streak_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _online = true;

  @override
  void initState() {
    super.initState();
    _refreshConnectivity();
    Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (mounted && online != _online) setState(() => _online = online);
    });
  }

  Future<void> _refreshConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    final online = results.any((r) => r != ConnectivityResult.none);
    if (mounted) setState(() => _online = online);
  }

  /// Pushes the session and, on successful completion, shows a toast.
  /// The milestone celebration is handled separately by the StreakCubit
  /// listener on [pendingMilestone], so we intentionally skip the SnackBar
  /// on milestone days — the dialog is the reward in that case.
  Future<void> _startSketch(BuildContext context) async {
    // Capture BuildContext-dependent objects before the await so we can use
    // them safely afterwards without a stale `context` reference.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final streakBloc = context.read<StreakCubit>();

    final completed = await navigator.push(SketchSessionPage.route());
    if (!mounted || completed != true) return;
    if (streakBloc.state.pendingMilestone != null) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Nice work — streak updated.'),
          duration: Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateFormat.yMMMMEEEEd().format(DateTime.now());
    return BlocListener<StreakCubit, StreakState>(
      listenWhen: (prev, curr) => curr.pendingMilestone != null && prev.pendingMilestone != curr.pendingMilestone,
      listener: (context, state) async {
        final threshold = state.pendingMilestone!;
        await showCelebrationDialog(context, threshold: threshold);
        if (context.mounted) {
          context.read<StreakCubit>().acknowledgeMilestone(threshold);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('SketchDaily'),
          actions: [
            IconButton(
              icon: const Icon(Icons.emoji_events_outlined),
              tooltip: 'Badges',
              onPressed: () => Navigator.of(context).push(BadgesPage.route()),
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Settings',
              onPressed: () => Navigator.of(context).push(SettingsPage.route()),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: BlocBuilder<StreakCubit, StreakState>(
              builder: (context, state) {
                final completedToday = state.isCompletedOn(DateTime.now());
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(today, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 16),
                    StreakCard(
                      currentStreak: state.currentStreak,
                      longestStreak: state.longestStreak,
                      completedToday: completedToday,
                    ),
                    const SizedBox(height: 24),
                    const HistoryHeatmap(),
                    const Spacer(),
                    if (!_online)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Offline — connect to start sketching.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    if (completedToday)
                      // Once today's sketch is locked in, we deliberately
                      // don't offer a "sketch again" action: the daily
                      // ritual is the product. Users can still re-view
                      // their reference to compare against what they drew.
                      OutlinedButton.icon(
                        onPressed: () => showSavedSessionDialog(
                          context,
                          date: DateTime.now(),
                        ),
                        icon: const Icon(Icons.image_outlined),
                        label: const Text('View today\'s sketch'),
                      )
                    else
                      FilledButton.icon(
                        onPressed: _online ? () => _startSketch(context) : null,
                        icon: const Icon(Icons.brush),
                        label: const Text('Start today\'s sketch'),
                      ),
                    const SizedBox(height: 12),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
