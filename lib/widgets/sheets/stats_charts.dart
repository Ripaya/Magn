import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../services/stats_calculator.dart';

/// Editorial 7-day bar chart displaying daily focus minutes with crisp bars
/// and Deep Mineral Pine fill for today's bar.
class SevenDayBarChart extends StatelessWidget {
  const SevenDayBarChart({
    super.key,
    required this.buckets,
  });

  final List<DayFocusBucket> buckets;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final maxMinutes = buckets.isEmpty
        ? 60.0
        : math.max(
            30.0,
            buckets.map((b) => b.totalMinutes).reduce(math.max),
          );

    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: buckets.map((bucket) {
          final ratio = (bucket.totalMinutes / maxMinutes).clamp(0.0, 1.0);
          final isToday = _isSameDay(bucket.date, DateTime.now());
          final dayLabel = DateFormat('E').format(bucket.date).substring(0, 1);

          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (bucket.totalSeconds > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '${bucket.totalMinutes.round()}m',
                      style: AppTheme.monoStyle(
                        fontSize: 10,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                        color: isToday
                            ? (isDark
                                ? MagnColors.warmSilkCream
                                : MagnColors.deepMineralPine)
                            : theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      heightFactor: math.max(0.06, ratio),
                      child: Container(
                        width: 22,
                        decoration: BoxDecoration(
                          color: isToday
                              ? MagnColors.deepMineralPine
                              : theme.scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: isToday
                                ? (isDark
                                    ? MagnColors.warmSilkCream
                                        .withValues(alpha: 0.45)
                                    : MagnColors.deepMineralPine)
                                : MagnColors.borderColor(context),
                            width: isToday ? 1.5 : 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  dayLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                    color: isToday
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Crisp geometric ring chart showing time-per-label distribution.
class LabelRingChart extends StatelessWidget {
  const LabelRingChart({
    super.key,
    required this.buckets,
    required this.totalSeconds,
  });

  final List<LabelFocusBucket> buckets;
  final int totalSeconds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (buckets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Text(
            'Complete a focus session to see label distribution',
            style: theme.textTheme.bodySmall,
          ),
        ),
      );
    }

    return Row(
      children: [
        SizedBox(
          width: 112,
          height: 112,
          child: CustomPaint(
            painter: _RingPainter(
              buckets: buckets,
              emptyTrackColor: MagnColors.borderColor(context),
            ),
            child: Center(
              child: Text(
                StatsCalculator.formatDurationCompact(totalSeconds),
                style: AppTheme.monoStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: buckets.take(5).map((b) {
              final pct = (b.fraction * 100).round();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: b.label.color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        b.label.name,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      '${StatsCalculator.formatDurationCompact(b.totalSeconds)} · $pct%',
                      style: AppTheme.monoStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.buckets,
    required this.emptyTrackColor,
  });

  final List<LabelFocusBucket> buckets;
  final Color emptyTrackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) - 8;
    const strokeWidth = 10.0;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = emptyTrackColor,
    );

    double startAngle = -math.pi / 2;
    const gapRad = 0.05;

    for (final b in buckets) {
      final rawSweep = b.fraction * 2 * math.pi;
      final sweep = math.max(0.03, rawSweep - (buckets.length > 1 ? gapRad : 0));
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt
        ..color = b.label.color;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        false,
        paint,
      );
      startAngle += rawSweep;
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.buckets != buckets ||
      oldDelegate.emptyTrackColor != emptyTrackColor;
}
