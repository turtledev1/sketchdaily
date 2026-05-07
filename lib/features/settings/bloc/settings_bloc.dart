import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../notifications/notification_service.dart';

part 'settings_event.dart';
part 'settings_state.dart';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  SettingsBloc({
    required NotificationService notifications,
    required SharedPreferences prefs,
  })  : _notifications = notifications,
        _prefs = prefs,
        super(SettingsState.fromPrefs(prefs)) {
    on<SettingsLoaded>(_onLoaded);
    on<SettingsReminderTimeChanged>(_onReminderChanged);
    on<SettingsNotificationsToggled>(_onToggled);
  }

  final NotificationService _notifications;
  final SharedPreferences _prefs;

  static const _keyHour = 'reminder_hour';
  static const _keyMinute = 'reminder_minute';
  static const _keyEnabled = 'notifications_enabled';

  Future<void> _onLoaded(
    SettingsLoaded event,
    Emitter<SettingsState> emit,
  ) async {
    emit(SettingsState.fromPrefs(_prefs));
    await _applyScheduling(state);
  }

  Future<void> _onReminderChanged(
    SettingsReminderTimeChanged event,
    Emitter<SettingsState> emit,
  ) async {
    await _prefs.setInt(_keyHour, event.time.hour);
    await _prefs.setInt(_keyMinute, event.time.minute);
    emit(state.copyWith(reminderTime: event.time));
    await _applyScheduling(state);
  }

  Future<void> _onToggled(
    SettingsNotificationsToggled event,
    Emitter<SettingsState> emit,
  ) async {
    await _prefs.setBool(_keyEnabled, event.enabled);
    emit(state.copyWith(notificationsEnabled: event.enabled));
    if (event.enabled) {
      await _notifications.requestPermissionsIfNeeded();
    }
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
