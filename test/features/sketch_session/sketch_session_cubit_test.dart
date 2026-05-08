import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sketchdaily/features/prompts/repository/prompt_repository.dart';
import 'package:sketchdaily/features/sketch_session/bloc/sketch_session_cubit.dart';

class _MockPromptRepository extends Mock implements PromptRepository {}

class _FakePrompt extends Fake implements ImagePrompt {}

const _fakePrompt = ImagePrompt(
  photoId: 'abc123',
  imageUrl: 'https://images.unsplash.com/photo-abc?ixid=test',
  photographerName: 'Ansel Example',
  photographerProfileUrl: 'https://unsplash.com/@ansel',
  downloadLocation: 'https://api.unsplash.com/photos/abc123/download',
  description: 'A still life',
);

void main() {
  late _MockPromptRepository prompts;

  setUpAll(() {
    // mocktail needs a fallback so `any()` of type ImagePrompt can be matched.
    registerFallbackValue(_FakePrompt());
  });

  setUp(() {
    prompts = _MockPromptRepository();
    when(() => prompts.trackUsage(any())).thenAnswer((_) async {});
  });

  group('requestSession', () {
    blocTest<SketchSessionCubit, SketchSessionState>(
      'loads prompt and transitions loadingPrompt -> ready',
      setUp: () {
        when(() => prompts.getTodayPrompt()).thenAnswer((_) async => _fakePrompt);
      },
      build: () => SketchSessionCubit(promptRepository: prompts),
      act: (cubit) => cubit.requestSession(),
      expect: () => [
        // Initial state is already `loadingPrompt`, so the handler first
        // re-emits loadingPrompt with `clearError`, then emits `ready`.
        isA<SketchSessionState>()
            .having((s) => s.status, 'status', SketchSessionStatus.loadingPrompt)
            .having((s) => s.errorMessage, 'errorMessage', null),
        isA<SketchSessionState>()
            .having((s) => s.status, 'status', SketchSessionStatus.ready)
            .having((s) => s.prompt?.photoId, 'photoId', 'abc123')
            .having((s) => s.remainingSeconds, 'remaining', 300),
      ],
    );

    blocTest<SketchSessionCubit, SketchSessionState>(
      'emits error state when Unsplash fetch throws',
      setUp: () {
        when(() => prompts.getTodayPrompt()).thenThrow(Exception('boom'));
      },
      build: () => SketchSessionCubit(promptRepository: prompts),
      act: (cubit) => cubit.requestSession(),
      expect: () => [
        isA<SketchSessionState>().having((s) => s.status, 'status', SketchSessionStatus.loadingPrompt),
        isA<SketchSessionState>()
            .having((s) => s.status, 'status', SketchSessionStatus.error)
            .having((s) => s.errorMessage, 'errorMessage', isNotNull),
      ],
    );
  });

  group('start', () {
    blocTest<SketchSessionCubit, SketchSessionState>(
      'fires Unsplash usage ping and transitions ready -> running',
      setUp: () {
        when(() => prompts.getTodayPrompt()).thenAnswer((_) async => _fakePrompt);
      },
      build: () => SketchSessionCubit(promptRepository: prompts),
      act: (cubit) async {
        cubit.requestSession();
        // Let the async load settle before start() so state.prompt != null.
        await Future<void>.delayed(Duration.zero);
        cubit.start();
      },
      skip: 2, // skip the loadingPrompt + ready emissions
      expect: () => [
        isA<SketchSessionState>().having((s) => s.status, 'status', SketchSessionStatus.running),
      ],
      verify: (_) {
        verify(() => prompts.trackUsage(any(that: isA<ImagePrompt>()))).called(1);
      },
    );

    blocTest<SketchSessionCubit, SketchSessionState>(
      'no-op when prompt is not yet loaded',
      build: () => SketchSessionCubit(promptRepository: prompts),
      act: (cubit) => cubit.start(),
      expect: () => const <SketchSessionState>[],
      verify: (_) => verifyNever(() => prompts.trackUsage(any())),
    );
  });

  group('refreshPrompt', () {
    blocTest<SketchSessionCubit, SketchSessionState>(
      'transitions ready -> refreshingPrompt -> ready with a new prompt',
      setUp: () {
        when(() => prompts.getTodayPrompt()).thenAnswer((_) async => _fakePrompt);
      },
      build: () => SketchSessionCubit(promptRepository: prompts),
      act: (cubit) async {
        cubit.requestSession();
        await Future<void>.delayed(Duration.zero);
        cubit.refreshPrompt();
      },
      skip: 2, // initial loadingPrompt + ready
      expect: () => [
        // The previous prompt is preserved during the refresh so the UI
        // can keep its layout stable.
        isA<SketchSessionState>()
            .having((s) => s.status, 'status', SketchSessionStatus.refreshingPrompt)
            .having((s) => s.prompt?.photoId, 'photoId', 'abc123'),
        isA<SketchSessionState>()
            .having((s) => s.status, 'status', SketchSessionStatus.ready)
            .having((s) => s.prompt?.photoId, 'photoId', 'abc123'),
      ],
      verify: (_) {
        verify(() => prompts.getTodayPrompt()).called(2);
      },
    );

    blocTest<SketchSessionCubit, SketchSessionState>(
      'falls back to ready with the previous prompt when refresh fetch fails',
      setUp: () {
        var calls = 0;
        when(() => prompts.getTodayPrompt()).thenAnswer((_) async {
          calls++;
          // First call (initial load) succeeds; second (refresh) blows up.
          if (calls == 1) return _fakePrompt;
          throw Exception('network down');
        });
      },
      build: () => SketchSessionCubit(promptRepository: prompts),
      act: (cubit) async {
        cubit.requestSession();
        await Future<void>.delayed(Duration.zero);
        cubit.refreshPrompt();
      },
      skip: 2,
      expect: () => [
        isA<SketchSessionState>().having((s) => s.status, 'status', SketchSessionStatus.refreshingPrompt),
        // Refresh failure must be non-destructive: same prompt, status ready.
        isA<SketchSessionState>()
            .having((s) => s.status, 'status', SketchSessionStatus.ready)
            .having((s) => s.prompt?.photoId, 'photoId', 'abc123'),
      ],
    );

    blocTest<SketchSessionCubit, SketchSessionState>(
      'tapping Start mid-refresh locks the current image — '
      'late-arriving fetch is discarded',
      setUp: () {
        var calls = 0;
        when(() => prompts.getTodayPrompt()).thenAnswer((_) async {
          calls++;
          if (calls == 1) return _fakePrompt;
          // Refresh fetch finishes after the user has tapped Start.
          await Future<void>.delayed(const Duration(milliseconds: 30));
          return const ImagePrompt(
            photoId: 'should-be-discarded',
            imageUrl: 'https://images.unsplash.com/photo-xyz?ixid=test',
            photographerName: 'Late Arrival',
            photographerProfileUrl: 'https://unsplash.com/@late',
            downloadLocation: 'https://api.unsplash.com/photos/xyz/download',
          );
        });
      },
      build: () => SketchSessionCubit(promptRepository: prompts),
      act: (cubit) async {
        cubit.requestSession();
        await Future<void>.delayed(Duration.zero);
        cubit.refreshPrompt();
        await Future<void>.delayed(Duration.zero);
        // User taps Start while the refresh fetch is still in flight.
        cubit.start();
        // Let the late refresh fetch resolve.
        await Future<void>.delayed(const Duration(milliseconds: 60));
      },
      skip: 3, // loadingPrompt, ready, refreshingPrompt
      expect: () => [
        // Start moves us into running with the *original* prompt — the
        // refresh's late return must not swap it.
        isA<SketchSessionState>()
            .having((s) => s.status, 'status', SketchSessionStatus.running)
            .having((s) => s.prompt?.photoId, 'photoId', 'abc123'),
      ],
    );

    blocTest<SketchSessionCubit, SketchSessionState>(
      'is ignored once the session is running (image is locked)',
      setUp: () {
        when(() => prompts.getTodayPrompt()).thenAnswer((_) async => _fakePrompt);
      },
      build: () => SketchSessionCubit(promptRepository: prompts),
      act: (cubit) async {
        cubit.requestSession();
        await Future<void>.delayed(Duration.zero);
        cubit.start();
        await Future<void>.delayed(Duration.zero);
        cubit.refreshPrompt();
      },
      skip: 3, // loadingPrompt, ready, running
      expect: () => const <SketchSessionState>[],
      verify: (_) {
        verify(() => prompts.getTodayPrompt()).called(1);
      },
    );
  });

  group('pause / resume', () {
    blocTest<SketchSessionCubit, SketchSessionState>(
      'running -> paused -> running',
      setUp: () {
        when(() => prompts.getTodayPrompt()).thenAnswer((_) async => _fakePrompt);
      },
      build: () => SketchSessionCubit(promptRepository: prompts),
      act: (cubit) async {
        cubit.requestSession();
        await Future<void>.delayed(Duration.zero);
        cubit.start();
        await Future<void>.delayed(Duration.zero);
        cubit.pause();
        await Future<void>.delayed(Duration.zero);
        cubit.resume();
      },
      skip: 3, // loadingPrompt, ready, running
      expect: () => [
        isA<SketchSessionState>().having((s) => s.status, 'status', SketchSessionStatus.paused),
        isA<SketchSessionState>().having((s) => s.status, 'status', SketchSessionStatus.running),
      ],
    );

    blocTest<SketchSessionCubit, SketchSessionState>(
      'pause is ignored outside running',
      setUp: () {
        when(() => prompts.getTodayPrompt()).thenAnswer((_) async => _fakePrompt);
      },
      build: () => SketchSessionCubit(promptRepository: prompts),
      act: (cubit) async {
        cubit.requestSession();
        await Future<void>.delayed(Duration.zero);
        // Still in `ready` — pause should be a no-op.
        cubit.pause();
      },
      skip: 2,
      expect: () => const <SketchSessionState>[],
    );
  });

  group('finishEarly', () {
    blocTest<SketchSessionCubit, SketchSessionState>(
      'running -> completed without waiting for ticks',
      setUp: () {
        when(() => prompts.getTodayPrompt()).thenAnswer((_) async => _fakePrompt);
      },
      build: () => SketchSessionCubit(promptRepository: prompts),
      act: (cubit) async {
        cubit.requestSession();
        await Future<void>.delayed(Duration.zero);
        cubit.start();
        await Future<void>.delayed(Duration.zero);
        cubit.finishEarly();
      },
      skip: 3,
      expect: () => [
        isA<SketchSessionState>().having((s) => s.status, 'status', SketchSessionStatus.completed),
      ],
    );
  });

  group('tick', () {
    blocTest<SketchSessionCubit, SketchSessionState>(
      'reaches completed when timer hits zero',
      setUp: () {
        when(() => prompts.getTodayPrompt()).thenAnswer((_) async => _fakePrompt);
      },
      // Short session so we only need one real tick (~1s) to hit zero.
      build: () => SketchSessionCubit(promptRepository: prompts, totalSeconds: 1),
      act: (cubit) async {
        cubit.requestSession();
        await Future<void>.delayed(Duration.zero);
        cubit.start();
      },
      // Give the real Timer.periodic one shot to fire and the cubit to emit.
      wait: const Duration(milliseconds: 1200),
      skip: 3, // loadingPrompt, ready, running
      expect: () => [
        isA<SketchSessionState>()
            .having((s) => s.status, 'status', SketchSessionStatus.completed)
            .having((s) => s.remainingSeconds, 'remaining', 0),
      ],
    );
  });

  group('elapsedSeconds', () {
    test('reports totalSeconds - remainingSeconds', () async {
      when(() => prompts.getTodayPrompt()).thenAnswer((_) async => _fakePrompt);
      final cubit = SketchSessionCubit(promptRepository: prompts, totalSeconds: 300);
      cubit.requestSession();
      await Future<void>.delayed(Duration.zero);
      // Still at full remaining → elapsed == 0.
      expect(cubit.elapsedSeconds(), 0);
      await cubit.close();
    });
  });
}
