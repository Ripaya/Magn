import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../models/app_settings.dart';
import '../../models/focus_mode.dart';
import '../../models/timer_state.dart';
import '../../providers/app_providers.dart';
import 'kinetic_dial_painter.dart';

/// Interactive wrapper around [KineticDialPainter] providing:
/// - Outer rim dragging when Idle (1-min or 5-min increments + haptic detents)
/// - Tapping the recessed cutout aperture when Idle to cycle modes with a damped spring tilt
/// - Double-tapping the dial center while Running for `+5 min` quick extension
/// - Tap-to-peek digits for 3 seconds when in Pure Analog / Tap-to-Peek mode
class KineticDialWidget extends ConsumerStatefulWidget {
  const KineticDialWidget({
    super.key,
    required this.size,
  });

  final double size;

  @override
  ConsumerState<KineticDialWidget> createState() => _KineticDialWidgetState();
}

class _KineticDialWidgetState extends ConsumerState<KineticDialWidget>
    with TickerProviderStateMixin {
  late final AnimationController _springController;
  late final AnimationController _digitsFadeController;
  late final AnimationController _underDiskDriftController;

  bool _isDraggingRim = false;
  double? _lastDragAngle;
  double _accumulatedMinutesDelta = 0.0;
  int _lastHapticMinute = -1;
  Timer? _peekHideTimer;
  double _baseUnderDiskAngle = 0.0;

  @override
  void initState() {
    super.initState();
    _springController = AnimationController.unbounded(vsync: this);

    _digitsFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      value: 1.0,
    );

    _underDiskDriftController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
  }

  @override
  void dispose() {
    _peekHideTimer?.cancel();
    _springController.dispose();
    _digitsFadeController.dispose();
    _underDiskDriftController.dispose();
    super.dispose();
  }

  void _triggerModeSwitchSpring() {
    const spring = SpringDescription(mass: 1.0, stiffness: 180.0, damping: 14.0);
    // Brief tactile twist (~14 degrees) settling smoothly back to horizontal 0°
    final sim = SpringSimulation(spring, 0.24, 0.0, -1.8);
    _springController.animateWith(sim);

    _baseUnderDiskAngle += math.pi / 2;
    _underDiskDriftController.forward(from: 0.0);
  }

  void _triggerPeekDigits() {
    final readoutMode = ref.read(settingsProvider).digitalReadoutMode;
    if (readoutMode == DigitalReadoutMode.alwaysOn) return;

    _peekHideTimer?.cancel();
    _digitsFadeController.forward();
    _peekHideTimer = Timer(AppConstants.peekDigitsDuration, () {
      if (mounted) {
        _digitsFadeController.reverse();
      }
    });
  }

  double _angleFromCenter(Offset localPos, double size) {
    final center = Offset(size / 2, size / 2);
    final dx = localPos.dx - center.dx;
    final dy = localPos.dy - center.dy;
    // 0 at 12 o'clock, increasing clockwise [0..2π)
    var angle = math.atan2(dy, dx) + math.pi / 2;
    if (angle < 0) angle += 2 * math.pi;
    return angle;
  }

  double _distanceFromCenter(Offset localPos, double size) {
    final center = Offset(size / 2, size / 2);
    return (localPos - center).distance;
  }

  bool _isInsideApertureSlot(Offset localPos, double size) {
    final center = Offset(size / 2, size / 2);
    final radius = size * 0.455;
    final slot = KineticDialPainter.buildApertureSlotRect(center, radius);
    return slot.inflate(10).contains(localPos);
  }

  void _handleTapUp(TapUpDetails details) {
    final timerState = ref.read(timerEngineProvider);
    final settings = ref.read(settingsProvider);
    final pos = details.localPosition;

    if (timerState.isIdle && _isInsideApertureSlot(pos, widget.size)) {
      if (settings.hapticRimTicks) {
        HapticFeedback.mediumImpact();
      }
      ref.read(timerEngineProvider.notifier).cycleMode();
      _triggerModeSwitchSpring();
      return;
    }

    // In Tap-to-Peek or Pure Analog mode, tapping anywhere on the dial reveals digits for 3s
    if (settings.digitalReadoutMode != DigitalReadoutMode.alwaysOn) {
      HapticFeedback.selectionClick();
      _triggerPeekDigits();
    }
  }

  void _handleDoubleTap() {
    final timerState = ref.read(timerEngineProvider);
    final settings = ref.read(settingsProvider);
    if (timerState.isRunning &&
        !timerState.isCountUp &&
        settings.doubleTapExtendEnabled) {
      ref.read(timerEngineProvider.notifier).extendCurrentSession();
      _triggerModeSwitchSpring();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('+5 min added to active session'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  void _handlePanStart(DragStartDetails details) {
    final timerState = ref.read(timerEngineProvider);
    if (!timerState.isIdle || timerState.mode == FocusMode.endless) return;

    final radius = widget.size * 0.455;
    final dist = _distanceFromCenter(details.localPosition, widget.size);

    // Outer rim manipulation ring (40% to 115% of dial radius)
    if (dist >= radius * 0.40 && dist <= radius * 1.15) {
      setState(() {
        _isDraggingRim = true;
        _lastDragAngle = _angleFromCenter(details.localPosition, widget.size);
        _accumulatedMinutesDelta = 0.0;
        _lastHapticMinute = timerState.plannedDurationMs ~/ 60000;
      });
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!_isDraggingRim || _lastDragAngle == null) return;
    final timerState = ref.read(timerEngineProvider);
    final settings = ref.read(settingsProvider);

    final newAngle = _angleFromCenter(details.localPosition, widget.size);
    var deltaAngle = newAngle - _lastDragAngle!;
    if (deltaAngle > math.pi) deltaAngle -= 2 * math.pi;
    if (deltaAngle < -math.pi) deltaAngle += 2 * math.pi;
    _lastDragAngle = newAngle;

    // 360° full turn = 60 minutes on the mechanical dial
    final deltaMinutes = (deltaAngle / (2 * math.pi)) * 60.0;
    _accumulatedMinutesDelta += deltaMinutes;

    final step = settings.rimDragStepMinutes.clamp(1, 5);
    if (_accumulatedMinutesDelta.abs() >= step) {
      final stepsCount = (_accumulatedMinutesDelta / step).truncate();
      _accumulatedMinutesDelta -= stepsCount * step;

      final currentMinutes = timerState.plannedDurationMs ~/ 60000;
      final snappedBase = (currentMinutes / step).round() * step;
      final targetMinutes = (snappedBase + stepsCount * step).clamp(
        AppConstants.minFocusMinutes,
        AppConstants.maxFocusMinutes,
      );

      if (targetMinutes != _lastHapticMinute) {
        _lastHapticMinute = targetMinutes;
        if (settings.hapticRimTicks) {
          HapticFeedback.selectionClick();
        }
        ref
            .read(timerEngineProvider.notifier)
            .setIdleFocusMinutes(targetMinutes);
      }
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    if (!_isDraggingRim) return;
    setState(() {
      _isDraggingRim = false;
      _lastDragAngle = null;
      _accumulatedMinutesDelta = 0.0;
    });
  }

  double _computeUnderDiskAngle(TimerState timerState) {
    // Smooth 180° sweep across a session (plus phase transition rotation & mode switch offset)
    final phaseBase = timerState.phase.isBreak ? math.pi : 0.0;
    final progressSweep = timerState.isIdle
        ? (timerState.liveHandAngleRad * 0.5)
        : (timerState.progress * math.pi);
    final modeDrift =
        Curves.easeOutCubic.transform(_underDiskDriftController.value) *
            (math.pi / 4);
    return _baseUnderDiskAngle + phaseBase + progressSweep + modeDrift;
  }

  @override
  Widget build(BuildContext context) {
    final timerState = ref.watch(timerEngineProvider);
    final settings = ref.watch(settingsProvider);
    final selectedLabel = ref.watch(selectedLabelProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ref.listen<DigitalReadoutMode>(
      settingsProvider.select((s) => s.digitalReadoutMode),
      (prev, next) {
        _peekHideTimer?.cancel();
        _peekHideTimer = null;
        if (next == DigitalReadoutMode.alwaysOn) {
          _digitsFadeController.forward();
        } else {
          _digitsFadeController.reverse();
        }
      },
    );

    final alwaysShowDigits =
        settings.digitalReadoutMode == DigitalReadoutMode.alwaysOn ||
            _isDraggingRim;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: _handleTapUp,
      onDoubleTap: _handleDoubleTap,
      onPanStart: _handlePanStart,
      onPanUpdate: _handlePanUpdate,
      onPanEnd: _handlePanEnd,
      onPanCancel: () => setState(() => _isDraggingRim = false),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _springController,
            _digitsFadeController,
            _underDiskDriftController,
          ]),
          builder: (context, _) {
            return CustomPaint(
              size: Size.square(widget.size),
              painter: KineticDialPainter(
                isDark: isDark,
                mode: timerState.mode,
                phase: timerState.phase,
                isIdle: timerState.isIdle,
                isRunning: timerState.isRunning,
                liveHandAngleRad: timerState.liveHandAngleRad,
                ghostMarkerAngleRad: timerState.ghostMarkerAngleRad,
                underDiskAngleRad: _computeUnderDiskAngle(timerState),
                maskSpringOffsetRad: _springController.value,
                hasSurpassedRecord: timerState.hasSurpassedEndlessBenchmark,
                endlessLaps: timerState.endlessLaps,
                isDraggingRim: _isDraggingRim,
                showRimMinutesHint: _isDraggingRim,
                apertureTitle: timerState.apertureTitle,
                formattedTime: timerState.formattedTime,
                digitsOpacity: alwaysShowDigits
                    ? 1.0
                    : _digitsFadeController.value,
                accentColor: selectedLabel.color,
                completedPomodoroRounds: timerState.completedPomodoroRounds,
                cyclesBeforeLongBreak: timerState.cyclesBeforeLongBreak,
              ),
            );
          },
        ),
      ),
    );
  }
}
