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

/// Main single-screen home view for Magn — Minimal Editorial & Clean Webtoon Panel layout:
/// - Top Editorial Bar: Focus Label panel (with live Cinnabar Red dot only when running) + Stats panel
/// - Center Stage: 3-Layer Kinetic Dial + modular Pomodoro round cells
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
                    // ── TOP EDITORIAL BAR ─────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Left: Modular Label Panel
                          InkWell(
                            onTap: _openLabelPicker,
                            borderRadius: BorderRadius.circular(
                              AppTheme.panelRadius,
                            ),
                            child: Container(
                              height: 40,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: AppTheme.panelDecoration(
                                context,
                                active: timerState.isRunning,
                                radius: AppTheme.panelRadius,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: timerState.isRunning
                                          ? MagnColors.cinnabarRed
                                          : selectedLabel.color,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 9),
                                  Text(
                                    selectedLabel.name,
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    size: 17,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Right: Modular Stats Panel Button
                          Tooltip(
                            message: 'Statistics & History',
                            child: InkWell(
                              onTap: _openStats,
                              borderRadius: BorderRadius.circular(
                                AppTheme.panelRadius,
                              ),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: AppTheme.panelDecoration(
                                  context,
                                  radius: AppTheme.panelRadius,
                                ),
                                child: Icon(
                                  Icons.bar_chart_rounded,
                                  size: 20,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── CENTER STAGE ──────────────────────────────────────────
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          KineticDialWidget(size: dialSize),

                          const SizedBox(height: 24),

                          _DialSubCaption(timerState: timerState),

                          if (timerState.isPhaseTransition) ...[
                            const SizedBox(height: 16),
                            _PhaseTransitionBanner(timerState: timerState),
                          ] else if (timerState.lastCompletedMessage != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: AppTheme.panelDecoration(
                                context,
                                radius: AppTheme.tightRadius,
                              ),
                              child: Text(
                                timerState.lastCompletedMessage!,
                                style: theme.textTheme.labelMedium,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // ── BOTTOM CONTROL DOCK ───────────────────────────────────
                    ControlDock(onOpenOptions: _openOptions),
                    const SizedBox(height: 28),
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
                  color: MagnColors.cinnabarRed.withValues(
                    alpha: _flashController.value * 0.18,
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
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;

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
                duration: const Duration(milliseconds: 220),
                width: 18,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: filled
                      ? MagnColors.deepMineralPine
                      : theme.colorScheme.surface,
                  border: Border.all(
                    color: filled
                        ? (isDark
                            ? MagnColors.warmSilkCream.withValues(alpha: 0.45)
                            : MagnColors.deepMineralPine)
                        : MagnColors.borderColor(context),
                    width: 1.0,
                  ),
                ),
              );
            }),
          ),
          if (timerState.isIdle) ...[
            const SizedBox(height: 12),
            Text(
              'Drag rim to adjust · Tap slot to switch mode',
              style: theme.textTheme.labelSmall?.copyWith(color: muted),
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
          ? 'PASSED BENCHMARK ($benchmarkStr)${timerState.endlessLaps > 0 ? ' · LAP ${timerState.endlessLaps + 1}' : ''}'
          : 'GHOST TARGET · $benchmarkStr';
      return Text(
        text,
        style: AppTheme.monoStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: timerState.hasSurpassedEndlessBenchmark
              ? MagnColors.cinnabarRed
              : muted,
          letterSpacing: 0.5,
        ),
      );
    }

    return Text(
      timerState.isIdle
          ? 'Drag rim to set focus length'
          : 'Uninterrupted Focus Block',
      style: theme.textTheme.labelSmall?.copyWith(color: muted),
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

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: AppTheme.panelDecoration(
        context,
        active: true,
        radius: AppTheme.panelRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              ref.read(timerEngineProvider.notifier).start();
            },
            child: Text(label),
          ),
          const SizedBox(width: 6),
          TextButton(
            onPressed: () =>
                ref.read(timerEngineProvider.notifier).dismissPhaseTransition(),
            child: Text(
              'Skip',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
