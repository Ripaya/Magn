import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:magn/models/app_settings.dart';
import 'package:magn/models/focus_mode.dart';
import 'package:magn/models/focus_session.dart';
import 'package:magn/models/session_label.dart';
import 'package:magn/providers/app_providers.dart';
import 'package:magn/services/database_service.dart';
import 'package:magn/services/native_timer_bridge.dart';
import 'package:magn/services/stats_calculator.dart';

class _InMemoryDatabaseService extends DatabaseService {
  AppSettings _settings = const AppSettings();
  final List<FocusSession> _sessions = [];
  final List<SessionLabel> _labels = [
    const SessionLabel(
      id: 'label_general',
      name: 'General',
      colorHex: '#475569',
      createdAtMs: 0,
    ),
  ];

  @override
  Future<AppSettings> loadSettings() async => _settings;

  @override
  Future<void> saveSettings(AppSettings settings) async {
    _settings = settings;
  }

  @override
  Future<List<SessionLabel>> loadLabels({bool includeArchived = false}) async =>
      List.unmodifiable(_labels);

  @override
  Future<List<FocusSession>> loadSessions({int? limit}) async =>
      List.unmodifiable(_sessions);

  @override
  Future<void> upsertSession(FocusSession session) async {
    _sessions.removeWhere((s) => s.id == session.id);
    _sessions.insert(0, session);
  }

  @override
  Future<void> deleteSession(String id) async {
    _sessions.removeWhere((s) => s.id == id);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Drift-free TimerEngine', () {
    late int fakeClockUtcMs;
    late ProviderContainer container;
    late _InMemoryDatabaseService fakeDb;

    setUp(() {
      fakeClockUtcMs = DateTime.utc(2026, 11, 26, 10, 0, 0).millisecondsSinceEpoch;
      fakeDb = _InMemoryDatabaseService();

      container = ProviderContainer(
        overrides: [
          clockProvider.overrideWithValue(() => fakeClockUtcMs),
          databaseServiceProvider.overrideWithValue(fakeDb),
          nativeTimerBridgeProvider.overrideWithValue(NativeTimerBridge()),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('maintains zero drift across background pause and resume intervals', () async {
      final engine = container.read(timerEngineProvider.notifier);

      await engine.start();
      expect(container.read(timerEngineProvider).status, TimerStatus.running);

      // Advance clock by 10 minutes
      fakeClockUtcMs += 10 * 60 * 1000;
      engine.syncFromClock();
      expect(container.read(timerEngineProvider).elapsedMs, 10 * 60 * 1000);
      expect(container.read(timerEngineProvider).remainingMs, 15 * 60 * 1000);

      // Pause for 7 minutes
      await engine.pause();
      expect(container.read(timerEngineProvider).status, TimerStatus.paused);
      fakeClockUtcMs += 7 * 60 * 1000;

      // Resume and advance 5 more minutes
      await engine.resume();
      fakeClockUtcMs += 5 * 60 * 1000;
      engine.syncFromClock();

      // Elapsed must equal exactly 15 minutes (10 + 5), unaffected by 7m pause
      expect(container.read(timerEngineProvider).elapsedMs, 15 * 60 * 1000);
      expect(container.read(timerEngineProvider).remainingMs, 10 * 60 * 1000);
    });

    test('transitions Pomodoro focus completion into short break and logs session', () async {
      final engine = container.read(timerEngineProvider.notifier);
      await engine.start();

      // Jump past 25-minute focus block
      fakeClockUtcMs += 25 * 60 * 1000;
      engine.syncFromClock();
      await Future<void>.delayed(Duration.zero);

      final state = container.read(timerEngineProvider);
      expect(state.status, TimerStatus.phaseTransition);
      expect(state.phase, SessionPhase.shortBreak);
      expect(state.completedPomodoroRounds, 1);

      final logged = await fakeDb.loadSessions();
      expect(logged.length, 1);
      expect(logged.first.actualSec, 25 * 60);
      expect(logged.first.completed, isTrue);
    });

    test('Endless Flow tracks laps past 60m and offers 20% earned break on stop', () async {
      final engine = container.read(timerEngineProvider.notifier);
      engine.selectMode(FocusMode.endless);

      await engine.start();
      // Run for 75 minutes (1 full lap + 15 minutes)
      fakeClockUtcMs += 75 * 60 * 1000;
      engine.syncFromClock();

      final running = container.read(timerEngineProvider);
      expect(running.endlessLaps, 1);
      expect(running.hasSurpassedEndlessBenchmark, isTrue);

      await engine.skipOrStop();
      final afterStop = container.read(timerEngineProvider);
      expect(afterStop.status, TimerStatus.phaseTransition);
      expect(afterStop.phase, SessionPhase.earnedBreak);
      // 20% of 75 minutes = 15 minutes earned break
      expect(afterStop.earnedBreakOfferMs, 15 * 60 * 1000);
    });
  });

  group('StatsCalculator', () {
    test('computes consecutive daily streak, today focus total, and Endless personal best', () {
      final now = DateTime(2026, 11, 26, 14, 0);
      final yesterday = DateTime(2026, 11, 25, 11, 0);
      final twoDaysAgo = DateTime(2026, 11, 24, 9, 0);

      final sessions = [
        FocusSession(
          id: '1',
          mode: FocusMode.endless,
          labelId: 'label_coding',
          startedAtMs: now.millisecondsSinceEpoch,
          endedAtMs: now.add(const Duration(minutes: 40)).millisecondsSinceEpoch,
          plannedSec: 2400,
          actualSec: 2400,
          completed: true,
        ),
        FocusSession(
          id: '2',
          mode: FocusMode.pomodoro,
          labelId: 'label_coding',
          startedAtMs: yesterday.millisecondsSinceEpoch,
          endedAtMs: yesterday.add(const Duration(minutes: 25)).millisecondsSinceEpoch,
          plannedSec: 1500,
          actualSec: 1500,
          completed: true,
        ),
        FocusSession(
          id: '3',
          mode: FocusMode.endless,
          labelId: 'label_study',
          startedAtMs: twoDaysAgo.millisecondsSinceEpoch,
          endedAtMs: twoDaysAgo.add(const Duration(minutes: 55)).millisecondsSinceEpoch,
          plannedSec: 3300,
          actualSec: 3300,
          completed: true,
        ),
      ];

      final summary = StatsCalculator.compute(
        sessions: sessions,
        labels: const [
          SessionLabel(
            id: 'label_coding',
            name: 'Coding',
            colorHex: '#2563EB',
            createdAtMs: 0,
          ),
          SessionLabel(
            id: 'label_study',
            name: 'Study',
            colorHex: '#059669',
            createdAtMs: 1,
          ),
        ],
        nowOverride: now,
      );

      expect(summary.todayFocusSeconds, 2400);
      expect(summary.currentStreakDays, 3);
      expect(summary.totalCompletedSessions, 3);

      final pbMs = StatsCalculator.computeEndlessBenchmarkMs(
        sessions: sessions,
        target: EndlessGhostTarget.personalBest,
      );
      expect(pbMs, 55 * 60 * 1000);
    });
  });
}
