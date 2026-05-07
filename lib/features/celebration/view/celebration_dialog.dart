import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../badges/model/badge_definition.dart';

/// How intense the celebration should be.
///
/// Tied to the badge threshold so the user feels an escalating reward curve:
/// a 3-day milestone shouldn't feel the same as a 365-day milestone, otherwise
/// long streaks stop feeling earned.
enum CelebrationIntensity {
  /// No confetti, just the scale-in + single haptic. For the earliest badges.
  subtle,

  /// A modest burst (~20 particles, ~1s). For week / fortnight milestones.
  modest,

  /// A bigger burst (~50 particles, ~2s) with a heavier haptic. Monthly range.
  big,

  /// Full fireworks (~100 particles, 3s, extra haptic). Centurion and above.
  epic,
}

CelebrationIntensity _intensityFor(int threshold) {
  if (threshold < 7) return CelebrationIntensity.subtle;
  if (threshold < 30) return CelebrationIntensity.modest;
  if (threshold < 100) return CelebrationIntensity.big;
  return CelebrationIntensity.epic;
}

/// Full-screen celebration overlay shown when the user crosses a streak
/// milestone. Intensity scales with [threshold].
Future<void> showCelebrationDialog(
  BuildContext context, {
  required int threshold,
}) {
  final def = BadgeDefinitions.forThreshold(threshold);
  final intensity = _intensityFor(threshold);

  _playInitialHaptic(intensity);

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Celebration',
    transitionDuration: const Duration(milliseconds: 450),
    pageBuilder: (context, anim, _) => _CelebrationView(
      definition: def,
      threshold: threshold,
      intensity: intensity,
    ),
    transitionBuilder: (context, anim, _, child) {
      final curve = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
      return Opacity(
        opacity: anim.value,
        child: Transform.scale(scale: 0.6 + 0.4 * curve.value, child: child),
      );
    },
  );
}

void _playInitialHaptic(CelebrationIntensity intensity) {
  if (intensity == CelebrationIntensity.subtle) {
    HapticFeedback.mediumImpact();
  } else {
    HapticFeedback.heavyImpact();
  }
}

class _CelebrationView extends StatefulWidget {
  const _CelebrationView({
    required this.definition,
    required this.threshold,
    required this.intensity,
  });

  final BadgeDefinition? definition;
  final int threshold;
  final CelebrationIntensity intensity;

  @override
  State<_CelebrationView> createState() => _CelebrationViewState();
}

class _CelebrationViewState extends State<_CelebrationView> {
  ConfettiController? _primary;
  ConfettiController? _secondaryLeft;
  ConfettiController? _secondaryRight;

  /// Params tuned per intensity tier. Epic additionally gets two side cannons.
  static const Map<CelebrationIntensity, _ConfettiParams> _params = {
    CelebrationIntensity.subtle: _ConfettiParams.disabled(),
    CelebrationIntensity.modest: _ConfettiParams(
      duration: Duration(seconds: 1),
      particles: 20,
      minForce: 8,
      maxForce: 20,
      emissionFrequency: 0.05,
    ),
    CelebrationIntensity.big: _ConfettiParams(
      duration: Duration(milliseconds: 1500),
      particles: 40,
      minForce: 6,
      maxForce: 14,
      emissionFrequency: 0.08,
    ),
    CelebrationIntensity.epic: _ConfettiParams(
      duration: Duration(milliseconds: 2200),
      particles: 60,
      minForce: 7,
      maxForce: 16,
      emissionFrequency: 0.07,
      withSideCannons: true,
    ),
  };

  _ConfettiParams get _p => _params[widget.intensity]!;

  @override
  void initState() {
    super.initState();
    if (_p.enabled) {
      _primary = ConfettiController(duration: _p.duration);
      if (_p.withSideCannons) {
        _secondaryLeft = ConfettiController(duration: _p.duration);
        _secondaryRight = ConfettiController(duration: _p.duration);
      }
      // Fire after the scale-in transition settles so confetti doesn't
      // compete for frames with the dialog's own animation.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _primary?.play();
        _secondaryLeft?.play();
        _secondaryRight?.play();
        _playFollowUpHaptic();
      });
    }
  }

  /// Epic milestones get a single, softer follow-up tap to mark the moment
  /// without crossing into buzzy territory.
  void _playFollowUpHaptic() {
    if (widget.intensity == CelebrationIntensity.epic) {
      Future.delayed(
        const Duration(milliseconds: 450),
        HapticFeedback.mediumImpact,
      );
    }
  }

  @override
  void dispose() {
    _primary?.dispose();
    _secondaryLeft?.dispose();
    _secondaryRight?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final def = widget.definition;
    final colors = _paletteFor(context, def);

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Dialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          insetPadding: const EdgeInsets.all(24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(def?.emoji ?? '🎉', style: const TextStyle(fontSize: 72)),
                const SizedBox(height: 12),
                Text(
                  def?.name ?? 'Milestone',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  def?.description ?? 'You hit ${widget.threshold} days in a row.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Keep sketching'),
                ),
              ],
            ),
          ),
        ),
        // Primary burst sits in the upper third of the dialog so you see
        // the explosion happen (not clipped at the very top).
        if (_primary != null)
          Align(
            alignment: const Alignment(0, -0.6),
            child: ConfettiWidget(
              confettiController: _primary!,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: _p.emissionFrequency,
              numberOfParticles: _p.particles,
              minBlastForce: _p.minForce,
              maxBlastForce: _p.maxForce,
              gravity: 0.25,
              shouldLoop: false,
              colors: colors,
              minimumSize: const Size(6, 3),
              maximumSize: const Size(12, 6),
            ),
          ),
        // Side cannons fire upward-and-inward from mid-screen edges — they
        // arc up over the dialog and rain down, framing the badge.
        if (_secondaryLeft != null)
          Align(
            alignment: Alignment.centerLeft,
            child: ConfettiWidget(
              confettiController: _secondaryLeft!,
              blastDirection: -pi / 3, // up-and-right (−90° = up, 0° = right)
              blastDirectionality: BlastDirectionality.directional,
              emissionFrequency: _p.emissionFrequency,
              numberOfParticles: _p.particles ~/ 2,
              minBlastForce: _p.minForce,
              maxBlastForce: _p.maxForce,
              gravity: 0.25,
              shouldLoop: false,
              colors: colors,
              minimumSize: const Size(6, 3),
              maximumSize: const Size(12, 6),
            ),
          ),
        if (_secondaryRight != null)
          Align(
            alignment: Alignment.centerRight,
            child: ConfettiWidget(
              confettiController: _secondaryRight!,
              blastDirection: pi + pi / 3, // up-and-left
              blastDirectionality: BlastDirectionality.directional,
              emissionFrequency: _p.emissionFrequency,
              numberOfParticles: _p.particles ~/ 2,
              minBlastForce: _p.minForce,
              maxBlastForce: _p.maxForce,
              gravity: 0.25,
              shouldLoop: false,
              colors: colors,
              minimumSize: const Size(6, 3),
              maximumSize: const Size(12, 6),
            ),
          ),
      ],
    );
  }

  List<Color> _paletteFor(BuildContext context, BadgeDefinition? def) {
    final scheme = Theme.of(context).colorScheme;
    return [
      def?.color ?? scheme.primary,
      scheme.primary,
      scheme.secondary,
      scheme.tertiary,
      Colors.amber,
    ];
  }
}

/// Per-tier confetti tuning. Private to this file.
class _ConfettiParams {
  const _ConfettiParams({
    required this.duration,
    required this.particles,
    required this.minForce,
    required this.maxForce,
    required this.emissionFrequency,
    this.withSideCannons = false,
  }) : enabled = true;

  const _ConfettiParams.disabled()
    : duration = const Duration(milliseconds: 1),
      particles = 0,
      minForce = 0,
      maxForce = 0,
      emissionFrequency = 0,
      withSideCannons = false,
      enabled = false;

  final Duration duration;
  final int particles;
  final double minForce;
  final double maxForce;
  final double emissionFrequency;
  final bool withSideCannons;
  final bool enabled;
}
