import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState extends Equatable {
  const SettingsState({
    required this.reminderTime,
    required this.notificationsEnabled,
  });

  static const String _keyHour = 'reminder_hour';
  static const String _keyMinute = 'reminder_minute';
  static const String _keyEnabled = 'notifications_enabled';

  factory SettingsState.fromPrefs(SharedPreferences prefs) {
    return SettingsState(
      reminderTime: TimeOfDay(
        hour: prefs.getInt(_keyHour) ?? 20,
        minute: prefs.getInt(_keyMinute) ?? 0,
      ),
      notificationsEnabled: prefs.getBool(_keyEnabled) ?? true,
    );
  }

  final TimeOfDay reminderTime;
  final bool notificationsEnabled;

  SettingsState copyWith({
    TimeOfDay? reminderTime,
    bool? notificationsEnabled,
  }) {
    return SettingsState(
      reminderTime: reminderTime ?? this.reminderTime,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }

  @override
  List<Object?> get props => [
    reminderTime.hour,
    reminderTime.minute,
    notificationsEnabled,
  ];
}
