import '../models/app_settings.dart';
import '../models/focus_mode.dart';
import '../models/focus_session.dart';
import '../models/session_label.dart';

class DayFocusBucket {
  const DayFocusBucket({
    required this.date,
    required this.totalSeconds,
  });

  final DateTime date;
  final int totalSeconds;

  double get totalMinutes => totalSeconds / 60.0;
}

class LabelFocusBucket {
  const LabelFocusBucket({
    required this.label,
    required this.totalSeconds,
    required this.fraction,
  });

  final SessionLabel label;
  final int totalSeconds;
  final double fraction;
}

class FocusStatsSummary {
  const FocusStatsSummary({
    required this.todayFocusSeconds,
    required this.currentStreakDays,
    required this.totalCompletedSessions,
    required this.last7Days,
    required this.labelBreakdown,
    required this.totalAllTimeSeconds,
    required this.averageSessionSeconds,
  });

  final int todayFocusSeconds;
  final int currentStreakDays;
  final int totalCompletedSessions;
  final List<DayFocusBucket> last7Days;
  final List<LabelFocusBucket> labelBreakdown;
  final int totalAllTimeSeconds;
  final int averageSessionSeconds;
}

/// Pure Dart statistics and benchmark calculator.
class StatsCalculator {
  const StatsCalculator._();

  static FocusStatsSummary compute({
    required List<FocusSession> sessions,
    required List<SessionLabel> labels,
    DateTime? nowOverride,
  }) {
    final now = nowOverride ?? DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    int todaySeconds = 0;
    int completedCount = 0;
    int totalSeconds = 0;

    final activeDays = <DateTime>{};
    final dayBucketsMap = <DateTime, int>{};
    final labelTotals = <String, int>{};

    for (var i = 6; i >= 0; i--) {
      final day = todayStart.subtract(Duration(days: i));
      dayBucketsMap[day] = 0;
    }

    for (final s in sessions) {
      totalSeconds += s.actualSec;
      if (s.completed) completedCount++;

      final started = s.startedAt;
      final dayKey = DateTime(started.year, started.month, started.day);
      if (s.actualSec > 0) {
        activeDays.add(dayKey);
      }
      if (dayKey == todayStart) {
        todaySeconds += s.actualSec;
      }
      if (dayBucketsMap.containsKey(dayKey)) {
        dayBucketsMap[dayKey] = (dayBucketsMap[dayKey] ?? 0) + s.actualSec;
      }

      final lid = s.labelId ?? 'label_general';
      labelTotals[lid] = (labelTotals[lid] ?? 0) + s.actualSec;
    }

    // Calculate current consecutive daily streak (counting today or yesterday if today is still in progress)
    int streak = 0;
    DateTime cursor = activeDays.contains(todayStart)
        ? todayStart
        : todayStart.subtract(const Duration(days: 1));
    while (activeDays.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    final last7Days = dayBucketsMap.entries
        .map((e) => DayFocusBucket(date: e.key, totalSeconds: e.value))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final labelById = {for (final l in labels) l.id: l};
    final fallbackLabel = SessionLabel(
      id: 'label_general',
      name: 'General',
      colorHex: '#475569',
      createdAtMs: 0,
    );

    final labelBuckets = <LabelFocusBucket>[];
    if (totalSeconds > 0) {
      labelTotals.forEach((lid, sec) {
        if (sec <= 0) return;
        labelBuckets.add(
          LabelFocusBucket(
            label: labelById[lid] ?? fallbackLabel,
            totalSeconds: sec,
            fraction: sec / totalSeconds,
          ),
        );
      });
      labelBuckets.sort((a, b) => b.totalSeconds.compareTo(a.totalSeconds));
    }

    final avgSec = sessions.isEmpty ? 0 : (totalSeconds ~/ sessions.length);

    return FocusStatsSummary(
      todayFocusSeconds: todaySeconds,
      currentStreakDays: streak,
      totalCompletedSessions: completedCount,
      last7Days: last7Days,
      labelBreakdown: labelBuckets,
      totalAllTimeSeconds: totalSeconds,
      averageSessionSeconds: avgSec,
    );
  }

  /// Calculates the Endless Flow Ghost Marker benchmark in milliseconds
  /// according to user preference (Last Session / Personal Best / Daily Average).
  static int computeEndlessBenchmarkMs({
    required List<FocusSession> sessions,
    required EndlessGhostTarget target,
  }) {
    const defaultMs = 25 * 60 * 1000;
    final endlessSessions =
        sessions.where((s) => s.mode == FocusMode.endless && s.actualSec >= 60).toList();

    switch (target) {
      case EndlessGhostTarget.lastSession:
        if (endlessSessions.isEmpty) return defaultMs;
        endlessSessions.sort((a, b) => b.startedAtMs.compareTo(a.startedAtMs));
        return endlessSessions.first.actualSec * 1000;

      case EndlessGhostTarget.personalBest:
        if (endlessSessions.isEmpty) return defaultMs;
        final best = endlessSessions
            .map((s) => s.actualSec)
            .reduce((a, b) => a > b ? a : b);
        return best * 1000;

      case EndlessGhostTarget.dailyAverage:
        if (sessions.isEmpty) return defaultMs;
        final byDay = <String, int>{};
        for (final s in sessions) {
          final d = s.startedAt;
          final key = '${d.year}-${d.month}-${d.day}';
          byDay[key] = (byDay[key] ?? 0) + s.actualSec;
        }
        if (byDay.isEmpty) return defaultMs;
        final total = byDay.values.reduce((a, b) => a + b);
        final avgSec = total ~/ byDay.length;
        return avgSec > 0 ? avgSec * 1000 : defaultMs;
    }
  }

  static String formatDurationCompact(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    if (hours > 0 && minutes > 0) return '${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h';
    if (minutes > 0) return '${minutes}m';
    return '${totalSeconds}s';
  }
}
