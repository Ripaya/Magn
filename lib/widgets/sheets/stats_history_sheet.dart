import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_theme.dart';
import '../../models/focus_mode.dart';
import '../../models/focus_session.dart';
import '../../models/session_label.dart';
import '../../providers/app_providers.dart';
import '../../services/stats_calculator.dart';
import 'stats_charts.dart';

const _uuid = Uuid();

/// Reusable dialog for adding a manual offline session or editing an existing log entry.
Future<void> showManualSessionDialog(
  BuildContext context,
  WidgetRef ref, {
  FocusSession? existing,
}) async {
  final labels = ref.read(labelsProvider);
  final defaultLabelId =
      existing?.labelId ?? ref.read(settingsProvider).selectedLabelId;

  FocusMode selectedMode = existing?.mode ?? FocusMode.focus;
  String selectedLabelId = defaultLabelId;
  int durationMinutes =
      existing != null ? (existing.actualSec / 60).round().clamp(1, 240) : 25;
  final notesController = TextEditingController(text: existing?.notes ?? '');

  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          return AlertDialog(
            title: Text(existing == null ? 'Log Manual Session' : 'Edit Session'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mode', style: Theme.of(ctx).textTheme.labelMedium),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: FocusMode.values.map((m) {
                      return ChoiceChip(
                        label: Text(m.displayLabel),
                        selected: selectedMode == m,
                        onSelected: (_) =>
                            setModalState(() => selectedMode = m),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  Text('Label', style: Theme.of(ctx).textTheme.labelMedium),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: labels.any((l) => l.id == selectedLabelId)
                        ? selectedLabelId
                        : (labels.isNotEmpty ? labels.first.id : null),
                    items: labels
                        .map(
                          (l) => DropdownMenuItem(
                            value: l.id,
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: l.color,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                Text(l.name),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setModalState(() => selectedLabelId = v);
                    },
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Duration',
                        style: Theme.of(ctx).textTheme.labelMedium,
                      ),
                      Text(
                        '$durationMinutes min',
                        style: AppTheme.monoStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: durationMinutes.toDouble(),
                    min: 1,
                    max: 180,
                    divisions: 179,
                    onChanged: (v) =>
                        setModalState(() => durationMinutes = v.round()),
                  ),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );

  if (saved == true) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final sec = durationMinutes * 60;
    final session = existing != null
        ? existing.copyWith(
            mode: selectedMode,
            labelId: selectedLabelId,
            actualSec: sec,
            plannedSec: sec,
            notes: notesController.text.trim(),
          )
        : FocusSession(
            id: _uuid.v4(),
            mode: selectedMode,
            labelId: selectedLabelId,
            startedAtMs: nowMs - sec * 1000,
            endedAtMs: nowMs,
            plannedSec: sec,
            actualSec: sec,
            completed: true,
            notes: notesController.text.trim(),
          );
    await ref.read(sessionsProvider.notifier).addOrUpdateSession(session);
  }
  notesController.dispose();
}

/// Statistics & History bottom sheet arranged as Minimal Editorial & Webtoon Panels:
/// - Modular Summary Strip (Today / Daily Streak / Completed Sessions)
/// - 7-day Bar Chart & Time-per-Label Ring Chart panels
/// - Reverse-chronological Session Log panels with Cinnabar Red swipe-to-delete
class StatsHistorySheet extends ConsumerStatefulWidget {
  const StatsHistorySheet({super.key});

  @override
  ConsumerState<StatsHistorySheet> createState() => _StatsHistorySheetState();
}

class _StatsHistorySheetState extends ConsumerState<StatsHistorySheet> {
  bool _showDetailedMetrics = false;

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(statsSummaryProvider);
    final sessions = ref.watch(sessionsProvider);
    final labels = ref.watch(labelsProvider);
    final labelMap = <String, SessionLabel>{for (final l in labels) l.id: l};
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final keyHeaderColor =
        isDark ? MagnColors.warmSilkCream : MagnColors.deepMineralPine;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.sheetRadius),
        ),
        border: Border(
          top: BorderSide(color: MagnColors.borderColor(context), width: 1),
        ),
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        minChildSize: 0.50,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 3,
                decoration: BoxDecoration(
                  color: MagnColors.borderColor(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 14, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Focus Insights',
                      style: AppTheme.headingStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        color: keyHeaderColor,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Add Manual Session',
                          onPressed: () => showManualSessionDialog(context, ref),
                          icon: const Icon(Icons.add_rounded),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 32),
                  children: [
                    // ── SUMMARY STRIP ─────────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _MetricTile(
                            label: 'TODAY',
                            value: StatsCalculator.formatDurationCompact(
                              stats.todayFocusSeconds,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MetricTile(
                            label: 'STREAK',
                            value: '${stats.currentStreakDays}d',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MetricTile(
                            label: 'SESSIONS',
                            value: '${stats.totalCompletedSessions}',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ── 7-DAY BAR CHART ───────────────────────────────────────
                    _ChartCard(
                      title: 'LAST 7 DAYS',
                      trailing: TextButton(
                        onPressed: () => setState(
                          () => _showDetailedMetrics = !_showDetailedMetrics,
                        ),
                        child: Text(
                          _showDetailedMetrics ? 'Compact' : 'Detailed View',
                        ),
                      ),
                      child: Column(
                        children: [
                          SevenDayBarChart(buckets: stats.last7Days),
                          if (_showDetailedMetrics) ...[
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _InlineDetail(
                                  label: 'All-Time Total',
                                  value: StatsCalculator.formatDurationCompact(
                                    stats.totalAllTimeSeconds,
                                  ),
                                ),
                                _InlineDetail(
                                  label: 'Avg Session',
                                  value: StatsCalculator.formatDurationCompact(
                                    stats.averageSessionSeconds,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ── TIME PER LABEL RING CHART ─────────────────────────────
                    _ChartCard(
                      title: 'TIME BY LABEL',
                      child: LabelRingChart(
                        buckets: stats.labelBreakdown,
                        totalSeconds: stats.totalAllTimeSeconds,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── SESSION LOG ───────────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'SESSION LOG',
                          style: AppTheme.headingStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: keyHeaderColor,
                          ).copyWith(letterSpacing: 1.4),
                        ),
                        Text(
                          'Swipe to delete · Tap to edit',
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (sessions.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 30,
                          horizontal: 16,
                        ),
                        decoration: AppTheme.panelDecoration(
                          context,
                          radius: AppTheme.panelRadius,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'No sessions recorded yet.\nStart the dial to log your first focus block.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall,
                        ),
                      )
                    else
                      ...sessions.map((session) {
                        final label = labelMap[session.labelId];
                        final dateStr = DateFormat('MMM d · HH:mm')
                            .format(session.startedAt);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Dismissible(
                            key: ValueKey(session.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                color: MagnColors.cinnabarRed,
                                borderRadius: BorderRadius.circular(
                                  AppTheme.panelRadius,
                                ),
                              ),
                              child: const Icon(
                                Icons.delete_outline_rounded,
                                color: MagnColors.warmSilkCream,
                              ),
                            ),
                            onDismissed: (_) {
                              ref
                                  .read(sessionsProvider.notifier)
                                  .deleteSession(session.id);
                            },
                            child: InkWell(
                              borderRadius: BorderRadius.circular(
                                AppTheme.panelRadius,
                              ),
                              onTap: () => showManualSessionDialog(
                                context,
                                ref,
                                existing: session,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: AppTheme.panelDecoration(
                                  context,
                                  radius: AppTheme.panelRadius,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 9,
                                      height: 9,
                                      decoration: BoxDecoration(
                                        color: label?.color ??
                                            MagnColors.deepMineralPine,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                label?.name ?? 'General',
                                                style: theme.textTheme.bodyMedium
                                                    ?.copyWith(
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                session.mode.displayLabel,
                                                style: theme.textTheme.labelSmall
                                                    ?.copyWith(
                                                  letterSpacing: 0.9,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            session.notes.isNotEmpty
                                                ? '$dateStr · ${session.notes}'
                                                : dateStr,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      StatsCalculator.formatDurationCompact(
                                        session.actualSec,
                                      ),
                                      style: AppTheme.monoStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: AppTheme.panelDecoration(
        context,
        radius: AppTheme.panelRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTheme.headingStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? MagnColors.darkInkSecondary
                  : MagnColors.deepMineralPine,
            ).copyWith(letterSpacing: 1.2),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTheme.monoStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.panelDecoration(
        context,
        radius: AppTheme.panelRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: AppTheme.headingStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? MagnColors.warmSilkCream
                      : MagnColors.deepMineralPine,
                ).copyWith(letterSpacing: 1.3),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _InlineDetail extends StatelessWidget {
  const _InlineDetail({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall,
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: AppTheme.monoStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
