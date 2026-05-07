part of 'settings_bloc.dart';

class SettingsState extends Equatable {
  const SettingsState({
    required this.reminderTime,
    required this.notificationsEnabled,
  });

  factory SettingsState.fromPrefs(SharedPreferences prefs) {
    return SettingsState(
      reminderTime: TimeOfDay(
        hour: prefs.getInt(SettingsBloc._keyHour) ?? 20,
        minute: prefs.getInt(SettingsBloc._keyMinute) ?? 0,
      ),
      notificationsEnabled: prefs.getBool(SettingsBloc._keyEnabled) ?? true,
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
