import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../badges/model/badge_definition.dart';
import '../../celebration/view/celebration_dialog.dart';
import '../../notifications/notification_service.dart';
import '../../streak/bloc/streak_cubit.dart';
import '../bloc/settings_cubit.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute(builder: (_) => const SettingsPage());
  }

  @override
  Widget build(BuildContext context) {
    final streakBloc = context.read<StreakCubit>();
    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return BlocProvider(
          create: (_) => SettingsCubit(
            notifications: NotificationService.instance,
            prefs: snapshot.data!,
          ),
          child: BlocProvider.value(value: streakBloc, child: const _SettingsView()),
        );
      },
    );
  }
}

class _SettingsView extends StatelessWidget {
  const _SettingsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          return ListView(
            children: [
              SwitchListTile(
                title: const Text('Daily reminder'),
                subtitle: const Text('Get a nudge to sketch today'),
                value: state.notificationsEnabled,
                onChanged: (v) => context.read<SettingsCubit>().toggleNotifications(v),
              ),
              ListTile(
                title: const Text('Reminder time'),
                subtitle: Text(state.reminderTime.format(context)),
                enabled: state.notificationsEnabled,
                trailing: const Icon(Icons.schedule),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: state.reminderTime,
                  );
                  if (picked != null && context.mounted) {
                    context.read<SettingsCubit>().setReminderTime(picked);
                  }
                },
              ),
              if (kDebugMode) ...[
                const Divider(),
                ListTile(
                  title: Text(
                    'Reset streak',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                  subtitle: const Text('Clear all progress. Useful for testing.'),
                  trailing: const Icon(Icons.delete_outline),
                  onTap: () => _confirmReset(context),
                ),
                const Divider(),
                const _DebugCelebrationSection(),
                const Divider(),
                const _DebugNotificationsSection(),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset streak?'),
        content: const Text(
          'This clears your current streak, longest streak, and history. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<StreakCubit>().reset();
    }
  }
}

class _DebugCelebrationSection extends StatelessWidget {
  const _DebugCelebrationSection();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Debug — Preview celebrations',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: colorScheme.secondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Fire each milestone dialog at its exact intensity tier. '
            'Does not affect your streak.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final def in BadgeDefinitions.all)
                ActionChip(
                  avatar: Text(def.emoji),
                  label: Text('${def.threshold}-day'),
                  onPressed: () => showCelebrationDialog(context, threshold: def.threshold),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DebugNotificationsSection extends StatelessWidget {
  const _DebugNotificationsSection();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Debug — Notifications',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: colorScheme.secondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Show a test notification immediately, or schedule one a few '
            'seconds out to verify the real scheduler path.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.notifications_active, size: 18),
                label: const Text('Show now'),
                onPressed: () async {
                  await NotificationService.instance.requestPermissionsIfNeeded();
                  await NotificationService.instance.showTestNotification();
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.schedule, size: 18),
                label: const Text('Schedule in 10s'),
                onPressed: () async {
                  await NotificationService.instance.requestPermissionsIfNeeded();
                  await NotificationService.instance.scheduleDebugReminderIn(
                    delay: const Duration(seconds: 10),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Scheduled in 10s — lock the screen or leave the app '
                          'to see it fire.',
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
