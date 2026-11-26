import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../models/focus_mode.dart';
import '../models/timer_state.dart';
import '../providers/app_providers.dart';
import '../services/stats_calculator.dart';
import '../widgets/controls/control_dock.dart';
import '../widgets/kinetic_dial/kinetic_dial_widget.dart';
import '../widgets/sheets/label_picker_sheet.dart';
import '../widgets/sheets/options_sheet.dart';
import '../widgets/sheets/stats_history_sheet.dart';

/// Main single-screen home view for Magn — Kinetic Focus Dial.
/// Layout:
/// - Minimal Top Bar: Left colored Label Chip, Right Stats Icon
/// - Center Stage (~70% viewport): Sculpted 3-Layer Kinetic Dial + Pomodoro round dots
/// - Bottom Control Dock: Options · Play/Pause · Hold-to-Skip/Stop
class HomeTimerScreen extends ConsumerStatefulWidget {
  const HomeTimerScreen({super.key});

  @override
  ConsumerState<HomeTimerScreen> createState() => _HomeTimerScreenState();
}

class _HomeTimerScreenState extends ConsumerState<HomeTimerScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final AnimationController _flashController;
  int _lastFlashNonce = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flashController.dispose();
    super.dispose();
  }

  /// Drift-free lifecycle sync: immediately recalculates exact dial position
  /// from UTC timestamp anchors upon returning from background/lockscreen.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(timerEngineProvider.notifier).syncFromClock();
    }
  }

  void _openLabelPicker() {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const LabelPickerSheet(),
    );
  }

  void _openOptions() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const OptionsSheet(),
    );
  }

  void _openStats() {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const StatsHistorySheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timerState = ref.watch(timerEngineProvider);
    final selectedLabel = ref.watch(selectedLabelProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Trigger subtle screen flash alert when enabled for silent study spaces
    if (timerState.screenFlashNonce != _lastFlashNonce) {
      _lastFlashNonce = timerState.screenFlashNonce;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _flashController.forward(from: 0.0).then((_) {
            if (mounted) _flashController.reverse();
          });
        }
      });
    }

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final dialSize = math.min(
                  constraints.maxWidth * 0.84,
                  constraints.maxHeight * 0.56,
                ).clamp(240.0, 380.0);

                return Column(
                  children: [
                    // ── MINIMAL TOP BAR ───────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 12, 18, 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Left: Colored Label Chip
                          GestureDetector(
                            onTap: _openLabelPicker,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF15171C)
                                    : Colors.white.withValues(alpha: 0.82),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: theme.colorScheme.outline
                                      .withValues(alpha: isDark ? 0.55 : 0.7),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: selectedLabel.color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    selectedLabel.name,
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.1,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    size: 16,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Right: Minimal Stats Icon
                          IconButton(
                            tooltip: 'Statistics & History',
                            onPressed: _openStats,
                            icon: Icon(
                              Icons.bar_chart_rounded,
                              size: 24,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── CENTER STAGE (~70% VIEWPORT) ──────────────────────────
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Centerpiece 3-Layer Kinetic Dial
                          KineticDialWidget(size: dialSize),

                          const SizedBox(height: 22),

                          // Pomodoro Round Dots or Endless Lap / Benchmark Caption
                          _DialSubCaption(timerState: timerState),

                          // Contextual Phase Transition / Earned Break Prompt
                          if (timerState.isPhaseTransition) ...[
                            const SizedBox(height: 16),
                            _PhaseTransitionBanner(timerState: timerState),
                          ] else if (timerState.lastCompletedMessage != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              timerState.lastCompletedMessage!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.58),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // ── BOTTOM CONTROL DOCK ───────────────────────────────────
                    ControlDock(onOpenOptions: _openOptions),
                    const SizedBox(height: 26),
                  ],
                );
              },
            ),
          ),

          // ── SUBTLE SILENT SCREEN FLASH ALERT OVERLAY ────────────────────────
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _flashController,
              builder: (context, _) {
                if (_flashController.value <= 0.001) {
                  return const SizedBox.shrink();
                }
                return Container(
                  color: Colors.white.withValues(
                    alpha: _flashController.value * 0.35,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DialSubCaption extends StatelessWidget {
  const _DialSubCaption({required this.timerState});

  final TimerState timerState;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.48);

    if (timerState.mode == FocusMode.pomodoro) {
      final total = timerState.cyclesBeforeLongBreak;
      final completed = timerState.completedPomodoroRounds % (total + 1);
      return Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(total, (index) {
              final filled = index < completed;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                width: filled ? 9 : 7.5,
                height: filled ? 9 : 7.5,
                margin: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: filled
                      ? theme.colorScheme.onSurface
                      : Colors.transparent,
                  border: Border.all(
                    color: theme.colorScheme.onSurface
                        .withValues(alpha: filled ? 1.0 : 0.32),
                    width: 1.5,
                  ),
                ),
              );
            }),
          ),
          if (timerState.isIdle) ...[
            const SizedBox(height: 10),
            Text(
              'Drag rim to adjust · Tap slot to switch mode',
              style: theme.textTheme.labelSmall?.copyWith(
                color: muted,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ],
      );
    }

    if (timerState.mode == FocusMode.endless) {
      final benchmarkStr = StatsCalculator.formatDurationCompact(
        timerState.endlessBenchmarkMs ~/ 1000,
      );
      final text = timerState.hasSurpassedEndlessBenchmark
          ? 'Passed benchmark ($benchmarkStr)${timerState.endlessLaps > 0 ? ' · Lap ${timerState.endlessLaps + 1}' : ''}'
          : 'Ghost target · $benchmarkStr';
      return Text(
        text,
        style: AppTheme.monoStyle(
          fontSize: 12,
          color: timerState.hasSurpassedEndlessBenchmark
              ? const Color(0xFFD97706)
              : muted,
          letterSpacing: 0.5,
        ),
      );
    }

    return Text(
      timerState.isIdle
          ? 'Drag rim to set focus length'
          : 'Uninterrupted Focus Block',
      style: theme.textTheme.labelSmall?.copyWith(
        color: muted,
        letterSpacing: 0.25,
      ),
    );
  }
}

class _PhaseTransitionBanner extends ConsumerWidget {
  const _PhaseTransitionBanner({required this.timerState});

  final TimerState timerState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final label = timerState.phase == SessionPhase.earnedBreak
        ? 'Take ${timerState.plannedDurationMs ~/ 60000}m Earned Break'
        : 'Start ${timerState.phase.label}';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton.tonal(
          onPressed: () {
            HapticFeedback.mediumImpact();
            ref.read(timerEngineProvider.notifier).start();
          },
          child: Text(label),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: () =>
              ref.read(timerEngineProvider.notifier).dismissPhaseTransition(),
          child: Text(
            'Skip',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
      ],
    );
  }
}
