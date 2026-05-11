import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../badges/model/badge_definition.dart';
import '../../celebration/view/celebration_dialog.dart';
import '../../streak/bloc/streak_cubit.dart';
import '../bloc/settings_cubit.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute(builder: (_) => const SettingsPage());
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: context.read<SettingsCubit>(),
      child: BlocProvider.value(
        value: context.read<StreakCubit>(),
        child: const _SettingsView(),
      ),
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
              const Divider(),
              const _CategorySection(),
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

class _CategorySection extends StatelessWidget {
  const _CategorySection();

  static String _toLabel(String category) => category[0].toUpperCase() + category.substring(1);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      buildWhen: (prev, next) => prev.enabledCategories != next.enabledCategories,
      builder: (context, state) {
        final categories = state.enabledCategories;
        final isLast = categories.length == 1;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Drawing categories',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Subjects that appear in your daily prompt. Add your own or remove any.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final category in categories)
                    Chip(
                      label: Text(_toLabel(category)),
                      onDeleted: isLast ? null : () => context.read<SettingsCubit>().removeCategory(category),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 18),
                    label: const Text('Add'),
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => BlocProvider.value(
                        value: context.read<SettingsCubit>(),
                        child: const _AddCategoryDialog(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AddCategoryDialog extends StatefulWidget {
  const _AddCategoryDialog();

  @override
  State<_AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<_AddCategoryDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add category'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.none,
        decoration: const InputDecoration(hintText: 'e.g. bicycle, clouds, shoes…'),
        onSubmitted: (_) => _submit(context),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => _submit(context),
          child: const Text('Add'),
        ),
      ],
    );
  }

  void _submit(BuildContext context) {
    context.read<SettingsCubit>().addCategory(_controller.text);
    Navigator.of(context).pop();
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
