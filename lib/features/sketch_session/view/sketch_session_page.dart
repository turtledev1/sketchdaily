import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../prompts/repository/prompt_repository.dart';
import '../../streak/bloc/streak_bloc.dart';
import '../bloc/sketch_session_bloc.dart';
import '../widgets/countdown_ring.dart';

class SketchSessionPage extends StatefulWidget {
  const SketchSessionPage({super.key});

  /// Returns `true` if the user completed the session (timer hit zero or
  /// they tapped "I'm done"), `null` if they backed out without finishing.
  static Route<bool> route() {
    return MaterialPageRoute<bool>(
      builder: (context) => BlocProvider(
        create: (ctx) => SketchSessionBloc(
          promptRepository: ctx.read<PromptRepository>(),
        )..add(const SketchSessionRequested()),
        child: const SketchSessionPage(),
      ),
    );
  }

  @override
  State<SketchSessionPage> createState() => _SketchSessionPageState();
}

class _SketchSessionPageState extends State<SketchSessionPage> {
  @override
  void initState() {
    super.initState();
    // Keep the display awake while sketching — paper sessions run 5 min
    // of "looking at the phone without tapping it", which would otherwise
    // hit the system screen-off timeout. Released in dispose, so backing
    // out or finishing both restore default screen behavior.
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SketchSessionBloc, SketchSessionState>(
      listenWhen: (prev, curr) =>
          prev.status != curr.status &&
          curr.status == SketchSessionStatus.completed,
      listener: (context, state) {
        final sessionBloc = context.read<SketchSessionBloc>();
        // Completion is only reachable from running/paused, which both
        // require a loaded prompt — so the bang here is a true invariant.
        final lockedPrompt = state.prompt!;
        context.read<StreakBloc>().add(
              StreakSessionCompleted(
                completedAt: DateTime.now(),
                durationSeconds: sessionBloc.elapsedSeconds(),
                photoId: lockedPrompt.photoId,
                imageUrl: lockedPrompt.imageUrl,
                photographerName: lockedPrompt.photographerName,
                photographerProfileUrl: lockedPrompt.photographerProfileUrl,
              ),
            );
        // `true` signals to the home page that a session just completed so
        // it can show the "nice work" SnackBar there (away from this page,
        // which is about to be disposed).
        Navigator.of(context).pop(true);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Today\'s sketch'),
          actions: [
            BlocBuilder<SketchSessionBloc, SketchSessionState>(
              // The button is enabled in pre-Start states (ready and
              // refreshingPrompt) and disabled once the timer starts.
              // Treating `refreshingPrompt` as "enabled" avoids the
              // enable→disable→enable color flicker on fast refreshes;
              // tapping refresh again during a refresh is a harmless
              // no-op (the bloc handler ignores it).
              buildWhen: (prev, curr) =>
                  _canRefresh(prev.status) != _canRefresh(curr.status),
              builder: (context, state) {
                final canRefresh = _canRefresh(state.status);
                return IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: canRefresh
                      ? 'Get a different image'
                      : 'Image locked — already started',
                  onPressed: canRefresh
                      ? () => context
                          .read<SketchSessionBloc>()
                          .add(const SketchSessionPromptRefreshRequested())
                      : null,
                );
              },
            ),
          ],
        ),
        body: SafeArea(
          child: BlocBuilder<SketchSessionBloc, SketchSessionState>(
            builder: (context, state) {
              switch (state.status) {
                case SketchSessionStatus.loadingPrompt:
                  return const Center(child: CircularProgressIndicator());
                case SketchSessionStatus.error:
                  return _ErrorView(message: state.errorMessage);
                case SketchSessionStatus.ready:
                case SketchSessionStatus.refreshingPrompt:
                case SketchSessionStatus.running:
                case SketchSessionStatus.paused:
                case SketchSessionStatus.completed:
                  return _ActiveSession(state: state);
              }
            },
          ),
        ),
      ),
    );
  }
}

/// Refresh is allowed before the user locks in a prompt by tapping Start.
/// Both `ready` and `refreshingPrompt` count: tapping refresh while a
/// refresh is already in flight is a no-op at the bloc level.
bool _canRefresh(SketchSessionStatus status) =>
    status == SketchSessionStatus.ready ||
    status == SketchSessionStatus.refreshingPrompt;

class _ErrorView extends StatelessWidget {
  const _ErrorView({this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, size: 64),
          const SizedBox(height: 16),
          Text(
            message ?? 'Something went wrong.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context
                .read<SketchSessionBloc>()
                .add(const SketchSessionRequested()),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _ActiveSession extends StatelessWidget {
  const _ActiveSession({required this.state});
  final SketchSessionState state;

  @override
  Widget build(BuildContext context) {
    final prompt = state.prompt!;
    final refreshing = state.status == SketchSessionStatus.refreshingPrompt;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: prompt.imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    // When the URL changes (refresh), keep the previously
                    // loaded image painted as the "placeholder" so we don't
                    // flash the spinner before the new image finishes
                    // downloading. The dim overlay above is what tells the
                    // user "a swap is happening".
                    useOldImageOnUrlChange: true,
                    placeholder: (_, _) =>
                        const Center(child: CircularProgressIndicator()),
                  ),
                  // Subtle "fetching a new image" overlay during refresh.
                  // The old image stays visible behind it so the layout
                  // doesn't collapse — only the prompt is being swapped.
                  if (refreshing)
                    const ColoredBox(
                      color: Color(0x66000000),
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _Attribution(prompt: prompt),
          const SizedBox(height: 16),
          CountdownRing(
            remainingSeconds: state.remainingSeconds,
            progress: state.progress,
          ),
          const SizedBox(height: 16),
          _Controls(state: state),
        ],
      ),
    );
  }
}

class _Attribution extends StatelessWidget {
  const _Attribution({required this.prompt});
  final ImagePrompt prompt;

  Future<void> _open(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodySmall;
    final linkStyle = textStyle?.copyWith(
      decoration: TextDecoration.underline,
      color: Theme.of(context).colorScheme.primary,
    );
    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        Text('Photo by ', style: textStyle),
        GestureDetector(
          onTap: () => _open(prompt.photographerUri()),
          child: Text(prompt.photographerName, style: linkStyle),
        ),
        Text(' on ', style: textStyle),
        GestureDetector(
          onTap: () => _open(prompt.unsplashAttributionUri()),
          child: Text('Unsplash', style: linkStyle),
        ),
      ],
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.state});
  final SketchSessionState state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<SketchSessionBloc>();
    switch (state.status) {
      case SketchSessionStatus.ready:
      case SketchSessionStatus.refreshingPrompt:
        // Keep the Start button visually identical during refresh.
        // Toggling onPressed enabled↔disabled triggers Material's color
        // transition, which plays back-and-forth on fast refreshes and
        // reads as flicker. The bloc's _onStarted handles a Start tap
        // mid-refresh by locking in the currently displayed image.
        return FilledButton.icon(
          onPressed: () => bloc.add(const SketchSessionStarted()),
          icon: const Icon(Icons.play_arrow),
          label: const Text('Start 5-minute sketch'),
        );
      case SketchSessionStatus.running:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: () => bloc.add(const SketchSessionPaused()),
              icon: const Icon(Icons.pause),
              label: const Text('Pause'),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: () => bloc.add(const SketchSessionFinishedEarly()),
              icon: const Icon(Icons.check),
              label: const Text('I\'m done'),
            ),
          ],
        );
      case SketchSessionStatus.paused:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: () => bloc.add(const SketchSessionResumed()),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Resume'),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () => bloc.add(const SketchSessionFinishedEarly()),
              icon: const Icon(Icons.check),
              label: const Text('I\'m done'),
            ),
          ],
        );
      case SketchSessionStatus.completed:
      case SketchSessionStatus.loadingPrompt:
      case SketchSessionStatus.error:
        return const SizedBox.shrink();
    }
  }
}
