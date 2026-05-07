part of 'streak_bloc.dart';

sealed class StreakEvent extends Equatable {
  const StreakEvent();

  @override
  List<Object?> get props => const [];
}

/// Fired when the user completes (or skips to "done") a sketch session.
///
/// The `photo*` fields capture the reference image the user "locked in"
/// by tapping Start, so it can be replayed later from the calendar view.
class StreakSessionCompleted extends StreakEvent {
  const StreakSessionCompleted({
    required this.completedAt,
    required this.durationSeconds,
    required this.photoId,
    required this.imageUrl,
    required this.photographerName,
    required this.photographerProfileUrl,
  });

  final DateTime completedAt;
  final int durationSeconds;
  final String photoId;
  final String imageUrl;
  final String photographerName;
  final String photographerProfileUrl;

  @override
  List<Object?> get props => [
        completedAt,
        durationSeconds,
        photoId,
        imageUrl,
        photographerName,
        photographerProfileUrl,
      ];
}

/// Acknowledges a celebration so it doesn't re-trigger.
class StreakMilestoneAcknowledged extends StreakEvent {
  const StreakMilestoneAcknowledged(this.threshold);

  final int threshold;

  @override
  List<Object?> get props => [threshold];
}

/// Debug / "reset streak" action from Settings.
class StreakResetRequested extends StreakEvent {
  const StreakResetRequested();
}
