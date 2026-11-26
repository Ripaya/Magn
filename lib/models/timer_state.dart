import 'dart:math' as math;
import '../core/constants/app_constants.dart';
import 'focus_mode.dart';

/// Immutable snapshot of the drift-free Kinetic Focus Dial timer state.
class TimerState {
  const TimerState({
    required this.mode,
    required this.phase,
    required this.status,
    required this.plannedDurationMs,
    this.sessionStartUtcMs,
    this.pauseStartUtcMs,
    this.totalPausedMs = 0,
    this.elapsedMs = 0,
    this.completedPomodoroRounds = 0,
    this.cyclesBeforeLongBreak = 4,
    this.endlessBenchmarkMs = 25 * 60 * 1000,
    this.earnedBreakOfferMs = 0,
    this.screenFlashNonce = 0,
    this.lastCompletedMessage,
  });

  final FocusMode mode;
  final SessionPhase phase;
  final TimerStatus status;

  /// Planned block duration in milliseconds (for Pomodoro, Focus, or Earned Break).
  final int plannedDurationMs;

  /// Drift-free UTC timestamp anchors.
  final int? sessionStartUtcMs;
  final int? pauseStartUtcMs;
  final int totalPausedMs;

  /// Purely derived elapsed milliseconds from timestamps.
  final int elapsedMs;

  /// Pomodoro completed focus rounds within the current cycle (0..cyclesBeforeLongBreak).
  final int completedPomodoroRounds;
  final int cyclesBeforeLongBreak;

  /// Benchmark target in ms for Endless Flow ghost marker (previous / PB / daily avg).
  final int endlessBenchmarkMs;

  /// Earned break duration offered after stopping an Endless Flow session (20%).
  final int earnedBreakOfferMs;

  /// Increments whenever a screen flash alert should trigger.
  final int screenFlashNonce;

  /// Optional subtle toast message after completing/logging a block.
  final String? lastCompletedMessage;

  bool get isIdle => status == TimerStatus.idle;
  bool get isRunning => status == TimerStatus.running;
  bool get isPaused => status == TimerStatus.paused;
  bool get isPhaseTransition => status == TimerStatus.phaseTransition;
  bool get isActive => isRunning || isPaused || isPhaseTransition;

  bool get isCountUp =>
      mode == FocusMode.endless && phase == SessionPhase.focus;

  /// Remaining milliseconds for countdown modes.
  int get remainingMs {
    if (isCountUp) return 0;
    return math.max(0, plannedDurationMs - elapsedMs);
  }

  /// Display milliseconds: counts down for Pomodoro/Focus/Break, counts up for Endless Flow.
  int get displayMs {
    if (isIdle) {
      return isCountUp ? 0 : plannedDurationMs;
    }
    return isCountUp ? elapsedMs : remainingMs;
  }

  /// Normalized progress [0.0..1.0] for countdown modes, or lap progress for Endless.
  double get progress {
    if (isCountUp) {
      const lapMs = AppConstants.endlessLapSeconds * 1000;
      return (elapsedMs % lapMs) / lapMs;
    }
    if (plannedDurationMs <= 0) return 0.0;
    return (elapsedMs / plannedDurationMs).clamp(0.0, 1.0);
  }

  /// Number of completed 60-minute laps in Endless Flow mode.
  int get endlessLaps {
    if (!isCountUp) return 0;
    return elapsedMs ~/ (AppConstants.endlessLapSeconds * 1000);
  }

  /// True once the live hand passes the ghost benchmark in Endless Flow mode.
  bool get hasSurpassedEndlessBenchmark {
    if (!isCountUp || endlessBenchmarkMs <= 0) return false;
    return elapsedMs >= endlessBenchmarkMs;
  }

  /// Live Hand angle in radians (`0` = 12 o'clock, sweeping clockwise up to `2π`).
  double get liveHandAngleRad {
    if (isIdle) {
      if (isCountUp) return 0.0;
      // When idle, show planned duration proportionally on a 60-minute dial face
      // so dragging the rim physically rotates the primary hand!
      final mins = plannedDurationMs / 60000.0;
      final fraction = (mins % 60.0) / 60.0;
      final normalized = (mins > 0 && fraction == 0.0) ? 1.0 : fraction;
      return normalized * 2 * math.pi;
    }
    return progress * 2 * math.pi;
  }

  /// Ghost Marker angle in radians (`0` = 12 o'clock).
  double get ghostMarkerAngleRad {
    if (mode == FocusMode.pomodoro) {
      // Marks full cycle end at 12 o'clock.
      return 0.0;
    }
    if (mode == FocusMode.focus) {
      // Marks planned end time on the dial (full sweep at 12 o'clock when running,
      // or target proportion on 60m face when idle).
      if (isIdle) return liveHandAngleRad;
      return 0.0;
    }
    // Endless Flow: anchored at benchmark duration on the 60-minute dial scale.
    const lapMs = AppConstants.endlessLapSeconds * 1000;
    final clamped = (endlessBenchmarkMs % lapMs) / lapMs;
    final normalized =
        (endlessBenchmarkMs > 0 && clamped == 0.0) ? 1.0 : clamped;
    return normalized * 2 * math.pi;
  }

  /// Formatted MM:SS (or H:MM:SS when >= 60 minutes).
  String get formattedTime {
    final totalSeconds = isCountUp
        ? (displayMs ~/ 1000)
        : ((displayMs + 999) ~/ 1000); // ceiling for smooth countdown ticks
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$mm:$ss';
    }
    return '$mm:$ss';
  }

  /// Title rendered inside the aperture slot.
  String get apertureTitle {
    if (phase.isBreak) return phase.label;
    return mode.displayLabel;
  }

  TimerState copyWith({
    FocusMode? mode,
    SessionPhase? phase,
    TimerStatus? status,
    int? plannedDurationMs,
    int? sessionStartUtcMs,
    bool clearStartUtc = false,
    int? pauseStartUtcMs,
    bool clearPauseUtc = false,
    int? totalPausedMs,
    int? elapsedMs,
    int? completedPomodoroRounds,
    int? cyclesBeforeLongBreak,
    int? endlessBenchmarkMs,
    int? earnedBreakOfferMs,
    int? screenFlashNonce,
    String? lastCompletedMessage,
    bool clearCompletedMessage = false,
  }) {
    return TimerState(
      mode: mode ?? this.mode,
      phase: phase ?? this.phase,
      status: status ?? this.status,
      plannedDurationMs: plannedDurationMs ?? this.plannedDurationMs,
      sessionStartUtcMs: clearStartUtc
          ? null
          : (sessionStartUtcMs ?? this.sessionStartUtcMs),
      pauseStartUtcMs:
          clearPauseUtc ? null : (pauseStartUtcMs ?? this.pauseStartUtcMs),
      totalPausedMs: totalPausedMs ?? this.totalPausedMs,
      elapsedMs: elapsedMs ?? this.elapsedMs,
      completedPomodoroRounds:
          completedPomodoroRounds ?? this.completedPomodoroRounds,
      cyclesBeforeLongBreak:
          cyclesBeforeLongBreak ?? this.cyclesBeforeLongBreak,
      endlessBenchmarkMs: endlessBenchmarkMs ?? this.endlessBenchmarkMs,
      earnedBreakOfferMs: earnedBreakOfferMs ?? this.earnedBreakOfferMs,
      screenFlashNonce: screenFlashNonce ?? this.screenFlashNonce,
      lastCompletedMessage: clearCompletedMessage
          ? null
          : (lastCompletedMessage ?? this.lastCompletedMessage),
    );
  }
}
