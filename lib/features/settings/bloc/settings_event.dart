part of 'settings_bloc.dart';

sealed class SettingsEvent extends Equatable {
  const SettingsEvent();
  @override
  List<Object?> get props => const [];
}

class SettingsReminderTimeChanged extends SettingsEvent {
  const SettingsReminderTimeChanged(this.time);
  final TimeOfDay time;
  @override
  List<Object?> get props => [time.hour, time.minute];
}

class SettingsNotificationsToggled extends SettingsEvent {
  const SettingsNotificationsToggled(this.enabled);
  final bool enabled;
  @override
  List<Object?> get props => [enabled];
}
