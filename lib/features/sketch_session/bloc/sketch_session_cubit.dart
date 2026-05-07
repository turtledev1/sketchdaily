import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../prompts/repository/prompt_repository.dart';
import 'sketch_session_state.dart';

export 'sketch_session_state.dart';

/// Drives a single 5-minute sketching session:
///   loadingPrompt -> (ready | error)
///   ready -> running
///   running <-> paused
///   running -> completed (timer hit zero OR user tapped "I'm done")
class SketchSessionCubit extends Cubit<SketchSessionState> {
  SketchSessionCubit({
    required PromptRepository promptRepository,
    int totalSeconds = 300,
  }) : _prompts = promptRepository,
       super(SketchSessionState.initial(totalSeconds: totalSeconds));

  final PromptRepository _prompts;
  Timer? _ticker;

  Future<void> requestSession() async {
    emit(state.copyWith(status: SketchSessionStatus.loadingPrompt, clearError: true));
    try {
      final prompt = await _prompts.getTodayPrompt();
      emit(
        state.copyWith(
          status: SketchSessionStatus.ready,
          prompt: prompt,
          remainingSeconds: state.totalSeconds,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: SketchSessionStatus.error,
          errorMessage: 'Could not fetch a reference image. Check your connection.',
        ),
      );
    }
  }

  Future<void> refreshPrompt() async {
    // Lock the image once the user has committed to it. Refresh is a
    // pre-Start affordance only — refreshing mid-session would discard
    // the user's in-progress sketch and leak their session timer.
    if (state.status != SketchSessionStatus.ready) return;
    emit(state.copyWith(status: SketchSessionStatus.refreshingPrompt));
    try {
      final prompt = await _prompts.getTodayPrompt();
      // Guard: if the user tapped Start while we were awaiting, the
      // status has moved past refreshingPrompt and they've locked in the
      // image they could see. Don't stomp on that with the new fetch.
      if (state.status != SketchSessionStatus.refreshingPrompt) return;
      emit(state.copyWith(status: SketchSessionStatus.ready, prompt: prompt));
    } catch (_) {
      // Refresh failure is non-destructive: keep the existing prompt and
      // drop back to ready. Punishing the user with an error screen for
      // a failed *replacement* fetch would be worse UX than just keeping
      // the image they already had.
      if (state.status != SketchSessionStatus.refreshingPrompt) return;
      emit(state.copyWith(status: SketchSessionStatus.ready));
    }
  }

  void start() {
    if (state.prompt == null) return;
    // Fire-and-forget the Unsplash usage ping — required by their guidelines
    // whenever a photo is "used". We don't await because a slow tracker shouldn't
    // delay the user's timer starting.
    unawaited(_prompts.trackUsage(state.prompt!));
    emit(state.copyWith(status: SketchSessionStatus.running));
    _startTicker();
  }

  void pause() {
    if (state.status != SketchSessionStatus.running) return;
    _stopTicker();
    emit(state.copyWith(status: SketchSessionStatus.paused));
  }

  void resume() {
    if (state.status != SketchSessionStatus.paused) return;
    emit(state.copyWith(status: SketchSessionStatus.running));
    _startTicker();
  }

  void finishEarly() {
    _stopTicker();
    emit(state.copyWith(status: SketchSessionStatus.completed));
  }

  void _tick() {
    if (state.status != SketchSessionStatus.running) return;
    final next = state.remainingSeconds - 1;
    if (next <= 0) {
      _stopTicker();
      emit(state.copyWith(remainingSeconds: 0, status: SketchSessionStatus.completed));
    } else {
      emit(state.copyWith(remainingSeconds: next));
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  /// How much of the session the user actually sat through, in seconds.
  int elapsedSeconds() => state.totalSeconds - state.remainingSeconds;

  @override
  Future<void> close() {
    _stopTicker();
    return super.close();
  }
}
