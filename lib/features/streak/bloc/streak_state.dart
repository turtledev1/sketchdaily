import 'package:equatable/equatable.dart';

import '../repository/streak_repository.dart';

class StreakState extends Equatable {
  const StreakState({
    required this.currentStreak,
    required this.longestStreak,
    required this.completedDates,
    required this.lastMilestoneCelebrated,
    this.pendingMilestone,
  });

  const StreakState.initial()
    : currentStreak = 0,
      longestStreak = 0,
      completedDates = const <String>{},
      lastMilestoneCelebrated = 0,
      pendingMilestone = null;

  /// Consecutive-day streak ending today (or ending yesterday if today isn't done yet).
  final int currentStreak;

  /// Best streak ever achieved.
  final int longestStreak;

  /// All days the user has completed, as `yyyy-MM-dd` strings in local time.
  final Set<String> completedDates;

  /// Highest badge threshold the user has already seen the celebration for.
  final int lastMilestoneCelebrated;

  /// Set transiently after a session completion when a new milestone is crossed.
  /// The UI watches this to trigger the celebration dialog, then calls
  /// [StreakCubit.acknowledgeMilestone] to clear it.
  final int? pendingMilestone;

  StreakState copyWith({
    int? currentStreak,
    int? longestStreak,
    Set<String>? completedDates,
    int? lastMilestoneCelebrated,
    int? pendingMilestone,
    bool clearPendingMilestone = false,
  }) {
    return StreakState(
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      completedDates: completedDates ?? this.completedDates,
      lastMilestoneCelebrated: lastMilestoneCelebrated ?? this.lastMilestoneCelebrated,
      pendingMilestone: clearPendingMilestone ? null : (pendingMilestone ?? this.pendingMilestone),
    );
  }

  bool isCompletedOn(DateTime date) => completedDates.contains(StreakRepository.formatDate(date));

  @override
  List<Object?> get props => [
    currentStreak,
    longestStreak,
    completedDates,
    lastMilestoneCelebrated,
    pendingMilestone,
  ];
}
