import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sketchdaily/features/streak/bloc/streak_cubit.dart';
import 'package:sketchdaily/features/streak/repository/streak_repository.dart';

class _MockStreakRepository extends Mock implements StreakRepository {}

class _InMemoryStorage implements Storage {
  final _box = <String, dynamic>{};

  @override
  dynamic read(String key) => _box[key];

  @override
  Future<void> write(String key, dynamic value) async => _box[key] = value;

  @override
  Future<void> delete(String key) async => _box.remove(key);

  @override
  Future<void> clear() async => _box.clear();

  @override
  Future<void> close() async {}
}

void main() {
  late _MockStreakRepository repository;

  setUpAll(() {
    HydratedBloc.storage = _InMemoryStorage();
  });

  setUp(() {
    repository = _MockStreakRepository();
    when(
      () => repository.recordSession(
        completedAt: any(named: 'completedAt'),
        durationSeconds: any(named: 'durationSeconds'),
        photoId: any(named: 'photoId'),
        imageUrl: any(named: 'imageUrl'),
        photographerName: any(named: 'photographerName'),
        photographerProfileUrl: any(named: 'photographerProfileUrl'),
      ),
    ).thenAnswer((_) async {});
    when(() => repository.clear()).thenAnswer((_) async {});
  });

  DateTime at(int y, int m, int d) => DateTime(y, m, d, 10);

  void completion(StreakCubit cubit, DateTime completedAt) => cubit.sessionCompleted(
    completedAt: completedAt,
    durationSeconds: 300,
    photoId: 'abc123',
    imageUrl: 'https://images.unsplash.com/photo-abc?ixid=test',
    photographerName: 'Ansel Example',
    photographerProfileUrl: 'https://unsplash.com/@ansel',
  );

  group('sessionCompleted', () {
    blocTest<StreakCubit, StreakState>(
      'first session starts a streak of 1',
      build: () => StreakCubit(repository: repository),
      act: (cubit) => completion(cubit, at(2026, 1, 1)),
      expect: () => [
        isA<StreakState>()
            .having((s) => s.currentStreak, 'current', 1)
            .having((s) => s.longestStreak, 'longest', 1)
            .having(
              (s) => s.completedDates.contains('2026-01-01'),
              'has today',
              true,
            ),
      ],
    );

    blocTest<StreakCubit, StreakState>(
      'consecutive day increments streak and sets pending milestone at 3',
      build: () => StreakCubit(repository: repository),
      seed: () => StreakState(
        currentStreak: 2,
        longestStreak: 2,
        completedDates: {'2025-12-30', '2025-12-31'},
        lastMilestoneCelebrated: 0,
      ),
      act: (cubit) => completion(cubit, at(2026, 1, 1)),
      expect: () => [
        isA<StreakState>()
            .having((s) => s.currentStreak, 'current', 3)
            .having((s) => s.longestStreak, 'longest', 3)
            .having((s) => s.pendingMilestone, 'pending milestone', 3),
      ],
    );

    blocTest<StreakCubit, StreakState>(
      'missed day resets current streak to 1 but keeps longest',
      build: () => StreakCubit(repository: repository),
      seed: () => StreakState(
        currentStreak: 5,
        longestStreak: 5,
        completedDates: {
          '2025-12-26',
          '2025-12-27',
          '2025-12-28',
          '2025-12-29',
          '2025-12-30',
        },
        lastMilestoneCelebrated: 3,
      ),
      act: (cubit) => completion(cubit, at(2026, 1, 1)), // gap after 2025-12-30
      expect: () => [
        isA<StreakState>().having((s) => s.currentStreak, 'current', 1).having((s) => s.longestStreak, 'longest', 5),
      ],
    );

    blocTest<StreakCubit, StreakState>(
      'same-day idempotent — no state change on duplicate completion',
      build: () => StreakCubit(repository: repository),
      seed: () => StreakState(
        currentStreak: 1,
        longestStreak: 1,
        completedDates: {'2026-01-01'},
        lastMilestoneCelebrated: 0,
      ),
      act: (cubit) => completion(cubit, at(2026, 1, 1)),
      expect: () => const <StreakState>[],
    );
  });

  group('reset', () {
    blocTest<StreakCubit, StreakState>(
      'clears state and repository',
      build: () => StreakCubit(repository: repository),
      seed: () => StreakState(
        currentStreak: 10,
        longestStreak: 10,
        completedDates: {'2026-01-01'},
        lastMilestoneCelebrated: 7,
      ),
      act: (cubit) => cubit.reset(),
      expect: () => [const StreakState.initial()],
      verify: (_) => verify(() => repository.clear()).called(1),
    );
  });
}
