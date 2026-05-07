part of 'sketch_session_bloc.dart';

enum SketchSessionStatus {
  /// First-time prompt load. No prompt is available yet — UI shows a
  /// full-page spinner.
  loadingPrompt,

  /// Prompt is loaded and the user can either start the session or refresh
  /// the image.
  ready,

  /// User asked for a different image after the first one loaded. The
  /// previous prompt is still in `state.prompt` so the layout can stay put
  /// while a new one is fetched.
  refreshingPrompt,

  running,
  paused,
  completed,
  error,
}

class SketchSessionState extends Equatable {
  const SketchSessionState({
    required this.status,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.prompt,
    this.errorMessage,
  });

  const SketchSessionState.initial({this.totalSeconds = 300})
    : status = SketchSessionStatus.loadingPrompt,
      remainingSeconds = totalSeconds,
      prompt = null,
      errorMessage = null;

  final SketchSessionStatus status;
  final int remainingSeconds;
  final int totalSeconds;
  final ImagePrompt? prompt;
  final String? errorMessage;

  double get progress => totalSeconds == 0 ? 0 : 1 - (remainingSeconds / totalSeconds);

  SketchSessionState copyWith({
    SketchSessionStatus? status,
    int? remainingSeconds,
    int? totalSeconds,
    ImagePrompt? prompt,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SketchSessionState(
      status: status ?? this.status,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      prompt: prompt ?? this.prompt,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
    status,
    remainingSeconds,
    totalSeconds,
    prompt?.photoId,
    errorMessage,
  ];
}
