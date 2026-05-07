import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sketchdaily/features/prompts/repository/prompt_repository.dart';
import 'package:sketchdaily/features/sketch_session/bloc/sketch_session_bloc.dart';

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

  group('SketchSessionRequested', () {
    blocTest<SketchSessionBloc, SketchSessionState>(
      'loads prompt and transitions loadingPrompt -> ready',
      setUp: () {
        when(() => prompts.getTodayPrompt())
            .thenAnswer((_) async => _fakePrompt);
      },
      build: () => SketchSessionBloc(promptRepository: prompts),
      act: (bloc) => bloc.add(const SketchSessionRequested()),
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

    blocTest<SketchSessionBloc, SketchSessionState>(
      'emits error state when Unsplash fetch throws',
      setUp: () {
        when(() => prompts.getTodayPrompt())
            .thenThrow(Exception('boom'));
      },
      build: () => SketchSessionBloc(promptRepository: prompts),
      act: (bloc) => bloc.add(const SketchSessionRequested()),
      expect: () => [
        isA<SketchSessionState>()
            .having((s) => s.status, 'status', SketchSessionStatus.loadingPrompt),
        isA<SketchSessionState>()
            .having((s) => s.status, 'status', SketchSessionStatus.error)
            .having((s) => s.errorMessage, 'errorMessage', isNotNull),
      ],
    );
  });

  group('SketchSessionStarted', () {
    blocTest<SketchSessionBloc, SketchSessionState>(
      'fires Unsplash usage ping and transitions ready -> running',
      setUp: () {
        when(() => prompts.getTodayPrompt())
            .thenAnswer((_) async => _fakePrompt);
      },
      build: () => SketchSessionBloc(promptRepository: prompts),
      act: (bloc) async {
        bloc.add(const SketchSessionRequested());
        // Let the async load settle before Started so state.prompt != null.
        await Future<void>.delayed(Duration.zero);
        bloc.add(const SketchSessionStarted());
      },
      skip: 2, // skip the loadingPrompt + ready emissions
      expect: () => [
        isA<SketchSessionState>()
            .having((s) => s.status, 'status', SketchSessionStatus.running),
      ],
      verify: (_) {
        verify(() => prompts.trackUsage(any(that: isA<ImagePrompt>()))).called(1);
      },
    );

    blocTest<SketchSessionBloc, SketchSessionState>(
      'no-op when prompt is not yet loaded',
      build: () => SketchSessionBloc(promptRepository: prompts),
      act: (bloc) => bloc.add(const SketchSessionStarted()),
      expect: () => const <SketchSessionState>[],
      verify: (_) => verifyNever(() => prompts.trackUsage(any())),
    );
  });

  group('SketchSessionPromptRefreshRequested', () {
    blocTest<SketchSessionBloc, SketchSessionState>(
      'transitions ready -> refreshingPrompt -> ready with a new prompt',
      setUp: () {
        when(() => prompts.getTodayPrompt())
            .thenAnswer((_) async => _fakePrompt);
      },
      build: () => SketchSessionBloc(promptRepository: prompts),
      act: (bloc) async {
        bloc.add(const SketchSessionRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const SketchSessionPromptRefreshRequested());
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

    blocTest<SketchSessionBloc, SketchSessionState>(
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
      build: () => SketchSessionBloc(promptRepository: prompts),
      act: (bloc) async {
        bloc.add(const SketchSessionRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const SketchSessionPromptRefreshRequested());
      },
      skip: 2,
      expect: () => [
        isA<SketchSessionState>()
            .having((s) => s.status, 'status', SketchSessionStatus.refreshingPrompt),
        // Refresh failure must be non-destructive: same prompt, status ready.
        isA<SketchSessionState>()
            .having((s) => s.status, 'status', SketchSessionStatus.ready)
            .having((s) => s.prompt?.photoId, 'photoId', 'abc123'),
      ],
    );

    blocTest<SketchSessionBloc, SketchSessionState>(
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
            downloadLocation:
                'https://api.unsplash.com/photos/xyz/download',
          );
        });
      },
      build: () => SketchSessionBloc(promptRepository: prompts),
      act: (bloc) async {
        bloc.add(const SketchSessionRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const SketchSessionPromptRefreshRequested());
        await Future<void>.delayed(Duration.zero);
        // User taps Start while the refresh fetch is still in flight.
        bloc.add(const SketchSessionStarted());
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

    blocTest<SketchSessionBloc, SketchSessionState>(
      'is ignored once the session is running (image is locked)',
      setUp: () {
        when(() => prompts.getTodayPrompt())
            .thenAnswer((_) async => _fakePrompt);
      },
      build: () => SketchSessionBloc(promptRepository: prompts),
      act: (bloc) async {
        bloc.add(const SketchSessionRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const SketchSessionStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const SketchSessionPromptRefreshRequested());
      },
      skip: 3, // loadingPrompt, ready, running
      expect: () => const <SketchSessionState>[],
      verify: (_) {
        verify(() => prompts.getTodayPrompt()).called(1);
      },
    );
  });

  group('pause / resume', () {
    blocTest<SketchSessionBloc, SketchSessionState>(
      'running -> paused -> running',
      setUp: () {
        when(() => prompts.getTodayPrompt())
            .thenAnswer((_) async => _fakePrompt);
      },
      build: () => SketchSessionBloc(promptRepository: prompts),
      act: (bloc) async {
        bloc.add(const SketchSessionRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const SketchSessionStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const SketchSessionPaused());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const SketchSessionResumed());
      },
      skip: 3, // loadingPrompt, ready, running
      expect: () => [
        isA<SketchSessionState>()
            .having((s) => s.status, 'status', SketchSessionStatus.paused),
        isA<SketchSessionState>()
            .having((s) => s.status, 'status', SketchSessionStatus.running),
      ],
    );

    blocTest<SketchSessionBloc, SketchSessionState>(
      'pause is ignored outside running',
      setUp: () {
        when(() => prompts.getTodayPrompt())
            .thenAnswer((_) async => _fakePrompt);
      },
      build: () => SketchSessionBloc(promptRepository: prompts),
      act: (bloc) async {
        bloc.add(const SketchSessionRequested());
        await Future<void>.delayed(Duration.zero);
        // Still in `ready` — pause should be a no-op.
        bloc.add(const SketchSessionPaused());
      },
      skip: 2,
      expect: () => const <SketchSessionState>[],
    );
  });

  group('SketchSessionFinishedEarly', () {
    blocTest<SketchSessionBloc, SketchSessionState>(
      'running -> completed without waiting for ticks',
      setUp: () {
        when(() => prompts.getTodayPrompt())
            .thenAnswer((_) async => _fakePrompt);
      },
      build: () => SketchSessionBloc(promptRepository: prompts),
      act: (bloc) async {
        bloc.add(const SketchSessionRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const SketchSessionStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const SketchSessionFinishedEarly());
      },
      skip: 3,
      expect: () => [
        isA<SketchSessionState>()
            .having((s) => s.status, 'status', SketchSessionStatus.completed),
      ],
    );
  });

  group('tick', () {
    blocTest<SketchSessionBloc, SketchSessionState>(
      'reaches completed when timer hits zero',
      setUp: () {
        when(() => prompts.getTodayPrompt())
            .thenAnswer((_) async => _fakePrompt);
      },
      // Short session so we only need one real tick (~1s) to hit zero.
      build: () => SketchSessionBloc(promptRepository: prompts, totalSeconds: 1),
      act: (bloc) async {
        bloc.add(const SketchSessionRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const SketchSessionStarted());
      },
      // Give the real Timer.periodic one shot to fire and the bloc to emit.
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
      when(() => prompts.getTodayPrompt())
          .thenAnswer((_) async => _fakePrompt);
      final bloc = SketchSessionBloc(promptRepository: prompts, totalSeconds: 300);
      bloc.add(const SketchSessionRequested());
      await Future<void>.delayed(Duration.zero);
      // Still at full remaining → elapsed == 0.
      expect(bloc.elapsedSeconds(), 0);
      await bloc.close();
    });
  });
}
