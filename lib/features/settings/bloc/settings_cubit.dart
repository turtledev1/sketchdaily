import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../notifications/notification_service.dart';
import 'settings_state.dart';

export 'settings_state.dart';

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit({
    required NotificationService notifications,
    required SharedPreferences prefs,
  }) : _notifications = notifications,
       _prefs = prefs,
       super(SettingsState.fromPrefs(prefs)) {
    // Apply the persisted schedule immediately on construction.
    _applyScheduling(state);
  }

  final NotificationService _notifications;
  final SharedPreferences _prefs;

  static const String _keyHour = 'reminder_hour';
  static const String _keyMinute = 'reminder_minute';
  static const String _keyEnabled = 'notifications_enabled';

  Future<void> setReminderTime(TimeOfDay time) async {
    await _prefs.setInt(_keyHour, time.hour);
    await _prefs.setInt(_keyMinute, time.minute);
    emit(state.copyWith(reminderTime: time));
    await _applyScheduling(state);
  }

  Future<void> toggleNotifications(bool enabled) async {
    await _prefs.setBool(_keyEnabled, enabled);
    emit(state.copyWith(notificationsEnabled: enabled));
    if (enabled) await _notifications.requestPermissionsIfNeeded();
    await _applyScheduling(state);
  }

  Future<void> _applyScheduling(SettingsState s) async {
    if (s.notificationsEnabled) {
      await _notifications.scheduleDailyReminder(
        hour: s.reminderTime.hour,
        minute: s.reminderTime.minute,
      );
    } else {
      await _notifications.cancelDailyReminder();
    }
  }
}
