import 'package:equatable/equatable.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

import '../../badges/model/badge_definition.dart';
import '../repository/streak_repository.dart';

part 'streak_event.dart';
part 'streak_state.dart';

/// Owns the user's daily-sketching streak state.
///
/// Uses [HydratedBloc] so current/longest streak and the set of completed dates
/// survive cold starts instantly, without the async gap that a sqflite-only
/// approach would impose on the home screen.
class StreakBloc extends HydratedBloc<StreakEvent, StreakState> {
  StreakBloc({required StreakRepository repository}) : _repository = repository, super(const StreakState.initial()) {
    on<StreakSessionCompleted>(_onSessionCompleted);
    on<StreakMilestoneAcknowledged>(_onMilestoneAcknowledged);
    on<StreakResetRequested>(_onResetRequested);
  }

  final StreakRepository _repository;

  Future<void> _onSessionCompleted(
    StreakSessionCompleted event,
    Emitter<StreakState> emit,
  ) async {
    final todayKey = StreakRepository.formatDate(event.completedAt);
    await _repository.recordSession(
      completedAt: event.completedAt,
      durationSeconds: event.durationSeconds,
      photoId: event.photoId,
      imageUrl: event.imageUrl,
      photographerName: event.photographerName,
      photographerProfileUrl: event.photographerProfileUrl,
    );

    if (state.completedDates.contains(todayKey)) {
      // Already logged today — idempotent, no streak change.
      return;
    }

    final yesterdayKey = StreakRepository.formatDate(
      DateTime(
        event.completedAt.year,
        event.completedAt.month,
        event.completedAt.day - 1,
      ),
    );
    final continued = state.completedDates.contains(yesterdayKey);
    final newStreak = continued ? state.currentStreak + 1 : 1;
    final newLongest = newStreak > state.longestStreak ? newStreak : state.longestStreak;

    final updatedDates = {...state.completedDates, todayKey};

    final crossed = _milestoneCrossed(
      previous: state.longestStreak,
      current: newLongest,
    );

    emit(
      state.copyWith(
        currentStreak: newStreak,
        longestStreak: newLongest,
        completedDates: updatedDates,
        pendingMilestone: crossed,
      ),
    );
  }

  void _onMilestoneAcknowledged(
    StreakMilestoneAcknowledged event,
    Emitter<StreakState> emit,
  ) {
    emit(
      state.copyWith(
        lastMilestoneCelebrated: event.threshold,
        clearPendingMilestone: true,
      ),
    );
  }

  Future<void> _onResetRequested(
    StreakResetRequested event,
    Emitter<StreakState> emit,
  ) async {
    await _repository.clear();
    emit(const StreakState.initial());
  }

  /// Returns the highest badge threshold that went from "locked" to "unlocked"
  /// this update, or null if no new badge was crossed.
  int? _milestoneCrossed({required int previous, required int current}) {
    int? crossed;
    for (final threshold in BadgeDefinitions.thresholds) {
      if (previous < threshold && current >= threshold) {
        crossed = threshold;
      }
    }
    return crossed;
  }

  // ---- HydratedBloc serialization ----

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
