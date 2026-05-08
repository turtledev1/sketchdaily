import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../prompts/repository/prompt_repository.dart';

class SettingsState extends Equatable {
  const SettingsState({
    required this.reminderTime,
    required this.notificationsEnabled,
    required this.enabledCategories,
  });

  static const String keyHour = 'reminder_hour';
  static const String keyMinute = 'reminder_minute';
  static const String keyEnabled = 'notifications_enabled';
  static const String keyEnabledCategories = 'enabled_categories';

  factory SettingsState.fromPrefs(SharedPreferences prefs) {
    final saved = prefs.getStringList(keyEnabledCategories);
    // Validate persisted values against the known list so stale entries
    // (e.g. after a category is removed in a future update) don't slip through.
    final enabledCategories = saved == null
        ? List<String>.from(PromptRepository.allCategories)
        : saved.where(PromptRepository.allCategories.contains).toList();

    return SettingsState(
      reminderTime: TimeOfDay(
        hour: prefs.getInt(keyHour) ?? 20,
        minute: prefs.getInt(keyMinute) ?? 0,
      ),
      notificationsEnabled: prefs.getBool(keyEnabled) ?? true,
      enabledCategories: enabledCategories.isEmpty
          ? List<String>.from(PromptRepository.allCategories)
          : enabledCategories,
    );
  }

  final TimeOfDay reminderTime;
  final bool notificationsEnabled;

  /// Subset of [PromptRepository.allCategories] the user wants to practice.
  /// Never empty — falls back to all categories if the user disables everything.
  final List<String> enabledCategories;

  SettingsState copyWith({
    TimeOfDay? reminderTime,
    bool? notificationsEnabled,
    List<String>? enabledCategories,
  }) {
    return SettingsState(
      reminderTime: reminderTime ?? this.reminderTime,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      enabledCategories: enabledCategories ?? this.enabledCategories,
    );
  }

  @override
  List<Object?> get props => [
    reminderTime.hour,
    reminderTime.minute,
    notificationsEnabled,
    enabledCategories,
  ];
}
