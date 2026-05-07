part of 'sketch_session_bloc.dart';

sealed class SketchSessionEvent extends Equatable {
  const SketchSessionEvent();
  @override
  List<Object?> get props => const [];
}

/// Fetches a prompt from Unsplash and moves to `ready` (or `error`).
class SketchSessionRequested extends SketchSessionEvent {
  const SketchSessionRequested();
}

/// User tapped "refresh image" before locking in (i.e. before Start).
/// Discards the current prompt and fetches a fresh one for today's theme.
/// Ignored once the session has moved past `ready` — once started, the
/// image is locked.
class SketchSessionPromptRefreshRequested extends SketchSessionEvent {
  const SketchSessionPromptRefreshRequested();
}

/// User tapped "Start": begin countdown.
class SketchSessionStarted extends SketchSessionEvent {
  const SketchSessionStarted();
}

class SketchSessionPaused extends SketchSessionEvent {
  const SketchSessionPaused();
}

class SketchSessionResumed extends SketchSessionEvent {
  const SketchSessionResumed();
}

/// User tapped "I'm done" before the timer ended.
class SketchSessionFinishedEarly extends SketchSessionEvent {
  const SketchSessionFinishedEarly();
}

/// 1-second internal tick from the bloc's Timer.periodic.
class _SketchSessionTick extends SketchSessionEvent {
  const _SketchSessionTick();
}
