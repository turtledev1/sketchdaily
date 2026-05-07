import 'package:hydrated_bloc/hydrated_bloc.dart';

import '../../badges/model/badge_definition.dart';
import '../repository/streak_repository.dart';
import 'streak_state.dart';

export 'streak_state.dart';

/// Owns the user's daily-sketching streak state.
///
/// Uses [HydratedCubit] so current/longest streak and the set of completed
/// dates survive cold starts instantly, without the async gap that a
/// sqflite-only approach would impose on the home screen.
class StreakCubit extends HydratedCubit<StreakState> {
  StreakCubit({required StreakRepository repository}) : _repository = repository, super(const StreakState.initial());

  final StreakRepository _repository;

  Future<void> sessionCompleted({
    required DateTime completedAt,
    required int durationSeconds,
    required String photoId,
    required String imageUrl,
    required String photographerName,
    required String photographerProfileUrl,
  }) async {
    final todayKey = StreakRepository.formatDate(completedAt);
    await _repository.recordSession(
      completedAt: completedAt,
      durationSeconds: durationSeconds,
      photoId: photoId,
      imageUrl: imageUrl,
      photographerName: photographerName,
      photographerProfileUrl: photographerProfileUrl,
    );

    if (state.completedDates.contains(todayKey)) return; // idempotent

    final yesterdayKey = StreakRepository.formatDate(
      DateTime(completedAt.year, completedAt.month, completedAt.day - 1),
    );
    final newStreak = state.completedDates.contains(yesterdayKey) ? state.currentStreak + 1 : 1;
    final newLongest = newStreak > state.longestStreak ? newStreak : state.longestStreak;

    emit(
      state.copyWith(
        currentStreak: newStreak,
        longestStreak: newLongest,
        completedDates: {...state.completedDates, todayKey},
        pendingMilestone: _milestoneCrossed(
          previous: state.longestStreak,
          current: newLongest,
        ),
      ),
    );
  }

  void acknowledgeMilestone(int threshold) {
    emit(
      state.copyWith(
        lastMilestoneCelebrated: threshold,
        clearPendingMilestone: true,
      ),
    );
  }

  Future<void> reset() async {
    await _repository.clear();
    emit(const StreakState.initial());
  }

  /// Returns the highest badge threshold that went from locked to unlocked
  /// this update, or null if no new badge was crossed.
  int? _milestoneCrossed({required int previous, required int current}) {
    int? crossed;
    for (final threshold in BadgeDefinitions.thresholds) {
      if (previous < threshold && current >= threshold) crossed = threshold;
    }
    return crossed;
  }

  // ---- HydratedCubit serialization ----

  @override
  StreakState? fromJson(Map<String, dynamic> json) {
    try {
      return StreakState(
        currentStreak: json['currentStreak'] as int? ?? 0,
        longestStreak: json['longestStreak'] as int? ?? 0,
        completedDates: ((json['completedDates'] as List?) ?? const []).cast<String>().toSet(),
        lastMilestoneCelebrated: json['lastMilestoneCelebrated'] as int? ?? 0,
        pendingMilestone: json['pendingMilestone'] as int?,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Map<String, dynamic>? toJson(StreakState state) => {
    'currentStreak': state.currentStreak,
    'longestStreak': state.longestStreak,
    'completedDates': state.completedDates.toList()..sort(),
    'lastMilestoneCelebrated': state.lastMilestoneCelebrated,
    'pendingMilestone': state.pendingMilestone,
  };
}
