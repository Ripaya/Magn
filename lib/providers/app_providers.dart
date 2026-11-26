import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/constants/app_constants.dart';
import '../models/app_settings.dart';
import '../models/focus_mode.dart';
import '../models/focus_preset.dart';
import '../models/focus_session.dart';
import '../models/session_label.dart';
import '../models/timer_state.dart';
import '../services/database_service.dart';
import '../services/native_timer_bridge.dart';
import '../services/stats_calculator.dart';

const _uuid = Uuid();

/// Core infrastructure providers
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

final nativeTimerBridgeProvider = Provider<NativeTimerBridge>((ref) {
  return NativeTimerBridge();
});

/// Clock abstraction for deterministic unit testing and drift-free UTC timestamps.
typedef ClockProvider = int Function();

final clockProvider = Provider<ClockProvider>((ref) {
  return () => DateTime.now().toUtc().millisecondsSinceEpoch;
});

// ── Settings Notifier ─────────────────────────────────────────────────────────

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier(ref.watch(databaseServiceProvider));
});

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier(this._db) : super(const AppSettings()) {
    _load();
  }

  final DatabaseService _db;

  Future<void> _load() async {
    try {
      state = await _db.loadSettings();
    } catch (_) {}
  }

  Future<void> update(AppSettings Function(AppSettings current) transform) async {
    state = transform(state);
    try {
      await _db.saveSettings(state);
    } catch (_) {}
  }

  Future<void> applyPreset(FocusPreset preset) async {
    await update(
      (s) => s.copyWith(
        focusMinutes: (preset.focusSec ~/ 60)
            .clamp(AppConstants.minFocusMinutes, AppConstants.maxFocusMinutes),
        shortBreakMinutes: (preset.shortBreakSec ~/ 60).clamp(
          AppConstants.minShortBreakMinutes,
          AppConstants.maxShortBreakMinutes,
        ),
        longBreakMinutes: (preset.longBreakSec ~/ 60).clamp(
          AppConstants.minLongBreakMinutes,
          AppConstants.maxLongBreakMinutes,
        ),
        cyclesBeforeLongBreak: preset.cyclesBeforeLongBreak.clamp(
          AppConstants.minCyclesBeforeLongBreak,
          AppConstants.maxCyclesBeforeLongBreak,
        ),
        autoStartBreaks: preset.autoStartBreak,
        autoStartFocus: preset.autoStartFocus,
      ),
    );
  }
}

// ── Labels Notifier ───────────────────────────────────────────────────────────

final labelsProvider =
    StateNotifierProvider<LabelsNotifier, List<SessionLabel>>((ref) {
  return LabelsNotifier(ref.watch(databaseServiceProvider));
});

class LabelsNotifier extends StateNotifier<List<SessionLabel>> {
  LabelsNotifier(this._db) : super(const []) {
    refresh();
  }

  final DatabaseService _db;

  Future<void> refresh() async {
    try {
      state = await _db.loadLabels();
    } catch (_) {}
  }

  Future<SessionLabel> createLabel({
    required String name,
    required String colorHex,
  }) async {
    final label = SessionLabel(
      id: _uuid.v4(),
      name: name.trim(),
      colorHex: colorHex,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _db.upsertLabel(label);
    state = [...state, label];
    return label;
  }

  Future<void> archiveLabel(String id) async {
    if (id == 'label_general') return;
    await _db.archiveLabel(id);
    state = state.where((l) => l.id != id).toList();
  }
}

final selectedLabelProvider = Provider<SessionLabel>((ref) {
  final labels = ref.watch(labelsProvider);
  final selectedId = ref.watch(settingsProvider.select((s) => s.selectedLabelId));
  return labels.firstWhere(
    (l) => l.id == selectedId,
    orElse: () => labels.isNotEmpty
        ? labels.first
        : const SessionLabel(
            id: 'label_general',
            name: 'General',
            colorHex: '#475569',
            createdAtMs: 0,
          ),
  );
});

// ── Presets Notifier ──────────────────────────────────────────────────────────

final presetsProvider =
    StateNotifierProvider<PresetsNotifier, List<FocusPreset>>((ref) {
  return PresetsNotifier(ref.watch(databaseServiceProvider));
});

class PresetsNotifier extends StateNotifier<List<FocusPreset>> {
  PresetsNotifier(this._db) : super(FocusPreset.defaults) {
    refresh();
  }

  final DatabaseService _db;

  Future<void> refresh() async {
    try {
      final loaded = await _db.loadPresets();
      if (loaded.isNotEmpty) {
        state = loaded;
      }
    } catch (_) {}
  }

  Future<void> saveCustomPreset({
    required String name,
    required FocusMode mode,
    required AppSettings settings,
  }) async {
    final preset = FocusPreset(
      id: _uuid.v4(),
      name: name.trim(),
      mode: mode,
      focusSec: settings.focusMinutes * 60,
      shortBreakSec: settings.shortBreakMinutes * 60,
      longBreakSec: settings.longBreakMinutes * 60,
      cyclesBeforeLongBreak: settings.cyclesBeforeLongBreak,
      autoStartBreak: settings.autoStartBreaks,
      autoStartFocus: settings.autoStartFocus,
      isBuiltIn: false,
    );
    await _db.upsertPreset(preset);
    state = [...state, preset];
  }

  Future<void> deletePreset(String id) async {
    await _db.deletePreset(id);
    state = state.where((p) => p.id != id).toList();
  }
}

// ── Sessions Notifier & Derived Stats ─────────────────────────────────────────

final sessionsProvider =
    StateNotifierProvider<SessionsNotifier, List<FocusSession>>((ref) {
  return SessionsNotifier(ref.watch(databaseServiceProvider));
});

class SessionsNotifier extends StateNotifier<List<FocusSession>> {
  SessionsNotifier(this._db) : super(const []) {
    refresh();
  }

  final DatabaseService _db;

  Future<void> refresh() async {
    try {
      state = await _db.loadSessions();
    } catch (_) {}
  }

  Future<void> addOrUpdateSession(FocusSession session) async {
    await _db.upsertSession(session);
    await refresh();
  }

  Future<void> deleteSession(String id) async {
    await _db.deleteSession(id);
    state = state.where((s) => s.id != id).toList();
  }
}

final statsSummaryProvider = Provider<FocusStatsSummary>((ref) {
  final sessions = ref.watch(sessionsProvider);
  final labels = ref.watch(labelsProvider);
  return StatsCalculator.compute(sessions: sessions, labels: labels);
});

// ── Drift-Free Timer Engine ───────────────────────────────────────────────────

final timerEngineProvider =
    StateNotifierProvider<TimerEngine, TimerState>((ref) {
  final engine = TimerEngine(
    ref: ref,
    bridge: ref.watch(nativeTimerBridgeProvider),
    nowUtcMs: ref.watch(clockProvider),
  );
  ref.onDispose(engine.dispose);
  return engine;
});

/// Deterministic 5-state drift-free timer engine.
/// Never decrements a counter per second; all elapsed and remaining values are
/// computed purely from `sessionStartUtcMs`, `pauseStartUtcMs`, and `totalPausedMs`.
class TimerEngine extends StateNotifier<TimerState> {
  TimerEngine({
    required Ref ref,
    required NativeTimerBridge bridge,
    required ClockProvider nowUtcMs,
  })  : _ref = ref,
        _bridge = bridge,
        _nowUtcMs = nowUtcMs,
        super(
          const TimerState(
            mode: FocusMode.pomodoro,
            phase: SessionPhase.focus,
            status: TimerStatus.idle,
            plannedDurationMs: 25 * 60 * 1000,
          ),
        ) {
    _initListeners();
  }

  final Ref _ref;
  final NativeTimerBridge _bridge;
  final ClockProvider _nowUtcMs;

  Timer? _uiTickTimer;
  StreamSubscription<String>? _nativeActionSub;

  AppSettings get _settings => _ref.read(settingsProvider);

  void _initListeners() {
    // Sync idle duration & endless benchmark when settings or sessions load/update
    _ref.listen<AppSettings>(settingsProvider, (prev, next) {
      _syncSettingsToIdleState(next);
    });

    _ref.listen<List<FocusSession>>(sessionsProvider, (prev, next) {
      _refreshEndlessBenchmark();
    });

    // Listen to inline notification shade actions (Pause / Resume / Skip / Alarm)
    _nativeActionSub = _bridge.nativeActions.listen((action) {
      switch (action) {
        case 'pause':
          pause();
          break;
        case 'resume':
          resume();
          break;
        case 'skip':
          skipOrStop();
          break;
        case 'alarm_fired':
          syncFromClock();
          break;
      }
    });
  }

  void _syncSettingsToIdleState(AppSettings settings) {
    final benchmark = StatsCalculator.computeEndlessBenchmarkMs(
      sessions: _ref.read(sessionsProvider),
      target: settings.endlessGhostTarget,
    );

    if (state.isIdle) {
      final plannedMs = state.mode == FocusMode.endless
          ? AppConstants.endlessLapSeconds * 1000
          : settings.focusMinutes * 60 * 1000;
      state = state.copyWith(
        plannedDurationMs: plannedMs,
        cyclesBeforeLongBreak: settings.cyclesBeforeLongBreak,
        endlessBenchmarkMs: benchmark,
      );
    } else {
      state = state.copyWith(
        cyclesBeforeLongBreak: settings.cyclesBeforeLongBreak,
        endlessBenchmarkMs: benchmark,
      );
      _updateWakelock(state.isRunning && settings.keepScreenOn);
      if (state.isRunning) {
        _bridge.setAmbientSound(settings.ambientSound);
      }
    }
  }

  void _refreshEndlessBenchmark() {
    final benchmark = StatsCalculator.computeEndlessBenchmarkMs(
      sessions: _ref.read(sessionsProvider),
      target: _settings.endlessGhostTarget,
    );
    state = state.copyWith(endlessBenchmarkMs: benchmark);
  }

  /// Switch focus mode when Idle (tapping the cutout aperture slot).
  void cycleMode() {
    if (!state.isIdle) return;
    selectMode(state.mode.next);
  }

  void selectMode(FocusMode mode) {
    if (!state.isIdle) return;
    final settings = _settings;
    final plannedMs = mode == FocusMode.endless
        ? AppConstants.endlessLapSeconds * 1000
        : settings.focusMinutes * 60 * 1000;
    state = state.copyWith(
      mode: mode,
      phase: SessionPhase.focus,
      status: TimerStatus.idle,
      plannedDurationMs: plannedMs,
      elapsedMs: 0,
      totalPausedMs: 0,
      completedPomodoroRounds: 0,
      earnedBreakOfferMs: 0,
      clearStartUtc: true,
      clearPauseUtc: true,
      clearCompletedMessage: true,
    );
  }

  /// Apply a smart preset from Tier 1 Options.
  Future<void> applyPreset(FocusPreset preset) async {
    await _ref.read(settingsProvider.notifier).applyPreset(preset);
    if (state.isIdle) {
      selectMode(preset.mode);
    }
  }

  /// Adjust planned duration by dragging the outer dial rim when Idle.
  void setIdleFocusMinutes(int minutes) {
    if (!state.isIdle || state.mode == FocusMode.endless) return;
    final clamped =
        minutes.clamp(AppConstants.minFocusMinutes, AppConstants.maxFocusMinutes);
    if (clamped * 60 * 1000 == state.plannedDurationMs) return;

    state = state.copyWith(
      plannedDurationMs: clamped * 60 * 1000,
      clearCompletedMessage: true,
    );
    _ref.read(settingsProvider.notifier).update(
          (s) => s.copyWith(focusMinutes: clamped),
        );
  }

  /// Start a fresh session from IDLE or begin the queued phase from PHASE_TRANSITION.
  Future<void> start() async {
    if (state.isRunning) return;
    if (state.isPaused) {
      await resume();
      return;
    }

    final now = _nowUtcMs();
    final settings = _settings;
    final isCountUp = state.mode == FocusMode.endless &&
        state.phase == SessionPhase.focus;

    state = state.copyWith(
      status: TimerStatus.running,
      sessionStartUtcMs: now,
      clearPauseUtc: true,
      totalPausedMs: 0,
      elapsedMs: 0,
      earnedBreakOfferMs: 0,
      clearCompletedMessage: true,
    );

    _startTicker();
    _updateWakelock(settings.keepScreenOn);

    if (settings.autoDndEnabled && !state.phase.isBreak) {
      await _bridge.setDndActive(true);
    }

    if (!state.phase.isBreak) {
      await _bridge.setAmbientSound(settings.ambientSound);
    }

    final labelName = _ref.read(selectedLabelProvider).name;
    await _bridge.startForegroundSession(
      title: '${state.apertureTitle} · $labelName',
      subtitle: isCountUp ? 'Flowing in Endless mode' : 'Focus session active',
      startUtcMs: now,
      targetEndUtcMs: isCountUp ? null : now + state.plannedDurationMs,
      isCountUp: isCountUp,
      notificationStyle: settings.notificationStyle,
      completionSound: settings.completionSound,
      vibrationPattern: settings.vibrationPattern,
    );
  }

  /// Pause an active session (disabled when Strict Mode is enabled).
  Future<void> pause() async {
    if (!state.isRunning) return;
    if (_settings.strictMode && !state.phase.isBreak) {
      HapticFeedback.heavyImpact();
      return;
    }

    final now = _nowUtcMs();
    final elapsed = _computeElapsedMs(now);
    _stopTicker();

    state = state.copyWith(
      status: TimerStatus.paused,
      pauseStartUtcMs: now,
      elapsedMs: elapsed,
    );

    _updateWakelock(false);
    await _bridge.setAmbientSound(AmbientSoundType.off);
    await _bridge.pauseForegroundSession(
      title: '${state.apertureTitle} (Paused)',
      formattedTime: state.formattedTime,
    );
  }

  /// Resume a paused session while preserving drift-free timestamp accuracy.
  Future<void> resume() async {
    if (!state.isPaused) return;
    final now = _nowUtcMs();
    final pauseDelta =
        state.pauseStartUtcMs != null ? math.max(0, now - state.pauseStartUtcMs!) : 0;
    final newTotalPaused = state.totalPausedMs + pauseDelta;
    final settings = _settings;

    state = state.copyWith(
      status: TimerStatus.running,
      totalPausedMs: newTotalPaused,
      clearPauseUtc: true,
    );

    _startTicker();
    _updateWakelock(settings.keepScreenOn);
    if (!state.phase.isBreak) {
      await _bridge.setAmbientSound(settings.ambientSound);
    }

    final startUtc = state.sessionStartUtcMs ?? now;
    final targetEnd = state.isCountUp
        ? null
        : startUtc + state.plannedDurationMs + newTotalPaused;
    final labelName = _ref.read(selectedLabelProvider).name;

    await _bridge.startForegroundSession(
      title: '${state.apertureTitle} · $labelName',
      subtitle: 'Focus session active',
      startUtcMs: startUtc + newTotalPaused,
      targetEndUtcMs: targetEnd,
      isCountUp: state.isCountUp,
      notificationStyle: settings.notificationStyle,
      completionSound: settings.completionSound,
      vibrationPattern: settings.vibrationPattern,
    );
  }

  /// Toggle Play / Pause from the primary dock button.
  Future<void> togglePlayPause() async {
    if (state.isRunning) {
      await pause();
    } else if (state.isPaused) {
      await resume();
    } else {
      await start();
    }
  }

  /// Quick `+5 min` extension on double-tapping the dial center while running.
  Future<void> extendCurrentSession() async {
    if (!state.isRunning || state.isCountUp) return;
    if (!_settings.doubleTapExtendEnabled) return;

    const addMs = AppConstants.quickExtendMinutes * 60 * 1000;
    final updatedPlanned = state.plannedDurationMs + addMs;
    state = state.copyWith(plannedDurationMs: updatedPlanned);

    HapticFeedback.mediumImpact();

    final now = _nowUtcMs();
    final startUtc = state.sessionStartUtcMs ?? now;
    final targetEnd = startUtc + updatedPlanned + state.totalPausedMs;
    final labelName = _ref.read(selectedLabelProvider).name;
    await _bridge.startForegroundSession(
      title: '${state.apertureTitle} · $labelName',
      subtitle: '+${AppConstants.quickExtendMinutes} min extended',
      startUtcMs: startUtc + state.totalPausedMs,
      targetEndUtcMs: targetEnd,
      isCountUp: false,
      notificationStyle: _settings.notificationStyle,
      completionSound: _settings.completionSound,
      vibrationPattern: _settings.vibrationPattern,
    );
  }

  /// Hold-to-Skip / Stop action (0.8s hold prevents accidental resets).
  Future<void> skipOrStop() async {
    if (state.isIdle) return;

    final now = _nowUtcMs();
    final elapsedMs = state.isRunning ? _computeElapsedMs(now) : state.elapsedMs;
    final elapsedSec = elapsedMs ~/ 1000;

    _stopTicker();
    _updateWakelock(false);
    await _bridge.setAmbientSound(AmbientSoundType.off);
    await _bridge.setDndActive(false);
    await _bridge.stopForegroundSession();

    // Endless Flow manual stop: log session and offer 20% earned break
    if (state.mode == FocusMode.endless && state.phase == SessionPhase.focus) {
      final logged = await _persistSessionIfEligible(
        elapsedSec: elapsedSec,
        completed: true,
        endedAtUtcMs: now,
      );

      final earnedBreakSec =
          (elapsedSec * AppConstants.earnedBreakRatio).round();
      if (earnedBreakSec >= 60) {
        state = state.copyWith(
          status: TimerStatus.phaseTransition,
          phase: SessionPhase.earnedBreak,
          plannedDurationMs: earnedBreakSec * 1000,
          earnedBreakOfferMs: earnedBreakSec * 1000,
          elapsedMs: 0,
          totalPausedMs: 0,
          clearStartUtc: true,
          clearPauseUtc: true,
          lastCompletedMessage: logged
              ? 'Logged ${StatsCalculator.formatDurationCompact(elapsedSec)} flow · ${earnedBreakSec ~/ 60}m break earned'
              : null,
        );
      } else {
        _resetToIdle(
          message: logged
              ? 'Logged ${StatsCalculator.formatDurationCompact(elapsedSec)} flow session'
              : 'Session under 1m discarded',
        );
      }
      return;
    }

    // Pomodoro skip: advance cleanly to next phase
    if (state.mode == FocusMode.pomodoro) {
      if (!state.phase.isBreak) {
        await _persistSessionIfEligible(
          elapsedSec: elapsedSec,
          completed: false,
          endedAtUtcMs: now,
        );
        _prepareNextPomodoroBreak(autoStart: false, completedFocus: false);
      } else {
        _prepareNextPomodoroFocus(autoStart: false);
      }
      return;
    }

    // Single Focus session or Earned Break stop
    if (state.phase == SessionPhase.focus) {
      final logged = await _persistSessionIfEligible(
        elapsedSec: elapsedSec,
        completed: false,
        endedAtUtcMs: now,
      );
      _resetToIdle(
        message: logged
            ? 'Saved ${StatsCalculator.formatDurationCompact(elapsedSec)} session'
            : 'Session under 1m discarded',
      );
    } else {
      _resetToIdle();
    }
  }

  /// Dismisses an earned break or phase transition back to Idle.
  Future<void> dismissPhaseTransition() async {
    await _bridge.stopForegroundSession();
    await _bridge.setDndActive(false);
    _resetToIdle();
  }

  /// Called on every UI tick AND immediately on `AppLifecycleState.resumed`
  /// to guarantee zero drift even after long Doze/background intervals.
  void syncFromClock() {
    if (!state.isRunning) return;
    final now = _nowUtcMs();
    final elapsed = _computeElapsedMs(now);

    if (!state.isCountUp && elapsed >= state.plannedDurationMs) {
      _handleNaturalPhaseCompletion(now);
      return;
    }

    if (elapsed != state.elapsedMs) {
      state = state.copyWith(elapsedMs: elapsed);
    }
  }

  int _computeElapsedMs(int nowUtcMs) {
    final start = state.sessionStartUtcMs;
    if (start == null) return state.elapsedMs;
    return math.max(0, nowUtcMs - start - state.totalPausedMs);
  }

  Future<void> _handleNaturalPhaseCompletion(int nowUtcMs) async {
    _stopTicker();
    _updateWakelock(false);
    await _bridge.setAmbientSound(AmbientSoundType.off);
    await _bridge.setDndActive(false);
    await _bridge.stopForegroundSession();

    final settings = _settings;
    await _bridge.triggerCompletionAlert(
      sound: settings.completionSound,
      vibration: settings.vibrationPattern,
      title: '${state.apertureTitle} complete',
    );

    final nextFlashNonce =
        settings.screenFlashAlert ? state.screenFlashNonce + 1 : state.screenFlashNonce;

    final plannedSec = state.plannedDurationMs ~/ 1000;

    if (state.mode == FocusMode.pomodoro) {
      if (!state.phase.isBreak) {
        await _persistSessionIfEligible(
          elapsedSec: plannedSec,
          completed: true,
          endedAtUtcMs: nowUtcMs,
        );
        state = state.copyWith(screenFlashNonce: nextFlashNonce);
        _prepareNextPomodoroBreak(
          autoStart: settings.autoStartBreaks,
          completedFocus: true,
        );
      } else {
        state = state.copyWith(screenFlashNonce: nextFlashNonce);
        _prepareNextPomodoroFocus(autoStart: settings.autoStartFocus);
      }
      return;
    }

    if (state.mode == FocusMode.focus && !state.phase.isBreak) {
      await _persistSessionIfEligible(
        elapsedSec: plannedSec,
        completed: true,
        endedAtUtcMs: nowUtcMs,
      );
      state = state.copyWith(screenFlashNonce: nextFlashNonce);
      _resetToIdle(
        message: 'Focus complete · ${StatsCalculator.formatDurationCompact(plannedSec)} logged',
      );
      return;
    }

    // Earned break finished
    state = state.copyWith(screenFlashNonce: nextFlashNonce);
    _resetToIdle(message: 'Break complete · Ready to focus');
  }

  void _prepareNextPomodoroBreak({
    required bool autoStart,
    required bool completedFocus,
  }) {
    final settings = _settings;
    final nextRounds = completedFocus
        ? state.completedPomodoroRounds + 1
        : state.completedPomodoroRounds;
    final isLongBreak =
        nextRounds > 0 && nextRounds % settings.cyclesBeforeLongBreak == 0;
    final breakPhase =
        isLongBreak ? SessionPhase.longBreak : SessionPhase.shortBreak;
    final breakMs = (isLongBreak
            ? settings.longBreakMinutes
            : settings.shortBreakMinutes) *
        60 *
        1000;

    state = state.copyWith(
      phase: breakPhase,
      status: TimerStatus.phaseTransition,
      plannedDurationMs: breakMs,
      elapsedMs: 0,
      totalPausedMs: 0,
      completedPomodoroRounds: nextRounds,
      clearStartUtc: true,
      clearPauseUtc: true,
      lastCompletedMessage: completedFocus
          ? (isLongBreak
              ? 'Cycle complete · Long break ready'
              : 'Focus complete · Short break ready')
          : 'Skipped to break',
    );

    if (autoStart) {
      start();
    }
  }

  void _prepareNextPomodoroFocus({required bool autoStart}) {
    final settings = _settings;
    final resetRounds =
        state.completedPomodoroRounds >= settings.cyclesBeforeLongBreak
            ? 0
            : state.completedPomodoroRounds;

    state = state.copyWith(
      phase: SessionPhase.focus,
      status: TimerStatus.phaseTransition,
      plannedDurationMs: settings.focusMinutes * 60 * 1000,
      elapsedMs: 0,
      totalPausedMs: 0,
      completedPomodoroRounds: resetRounds,
      clearStartUtc: true,
      clearPauseUtc: true,
      lastCompletedMessage: 'Break finished · Ready for focus',
    );

    if (autoStart) {
      start();
    }
  }

  void _resetToIdle({String? message}) {
    final settings = _settings;
    final plannedMs = state.mode == FocusMode.endless
        ? AppConstants.endlessLapSeconds * 1000
        : settings.focusMinutes * 60 * 1000;

    state = state.copyWith(
      phase: SessionPhase.focus,
      status: TimerStatus.idle,
      plannedDurationMs: plannedMs,
      elapsedMs: 0,
      totalPausedMs: 0,
      earnedBreakOfferMs: 0,
      clearStartUtc: true,
      clearPauseUtc: true,
      lastCompletedMessage: message,
      clearCompletedMessage: message == null,
    );
  }

  Future<bool> _persistSessionIfEligible({
    required int elapsedSec,
    required bool completed,
    required int endedAtUtcMs,
  }) async {
    if (elapsedSec < AppConstants.minLoggableSeconds) {
      return false;
    }

    final startedAt = state.sessionStartUtcMs ?? (endedAtUtcMs - elapsedSec * 1000);
    final session = FocusSession(
      id: _uuid.v4(),
      mode: state.mode,
      labelId: _settings.selectedLabelId,
      startedAtMs: startedAt,
      endedAtMs: endedAtUtcMs,
      plannedSec: state.mode == FocusMode.endless
          ? elapsedSec
          : state.plannedDurationMs ~/ 1000,
      actualSec: elapsedSec,
      completed: completed,
    );

    await _ref.read(sessionsProvider.notifier).addOrUpdateSession(session);
    return true;
  }

  void _startTicker() {
    _uiTickTimer?.cancel();
    // 16ms–50ms UI sync cadence for smooth 60fps hand sweep; actual math is UTC timestamp-derived
    _uiTickTimer = Timer.periodic(
      const Duration(milliseconds: 50),
      (_) => syncFromClock(),
    );
  }

  void _stopTicker() {
    _uiTickTimer?.cancel();
    _uiTickTimer = null;
  }

  void _updateWakelock(bool enable) {
    try {
      final Future<void> op =
          enable ? WakelockPlus.enable() : WakelockPlus.disable();
      unawaited(op.catchError((_) {}));
    } catch (_) {}
  }

  @override
  void dispose() {
    _stopTicker();
    _nativeActionSub?.cancel();
    super.dispose();
  }
}
