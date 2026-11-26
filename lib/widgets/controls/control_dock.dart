import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../models/focus_mode.dart';
import '../../providers/app_providers.dart';
import 'hold_to_skip_button.dart';

/// Minimal Editorial 3-action Bottom Control Dock (flat panels, 10-12px corners,
/// crisp 1px/1.5px borders, zero drop shadows):
/// - Left: Options panel button
/// - Center: Deep Mineral Pine primary Play / Pause panel button
/// - Right: 0.8s Hold-to-Skip / Stop panel button with Cinnabar Red trigger ring
class ControlDock extends ConsumerStatefulWidget {
  const ControlDock({
    super.key,
    required this.onOpenOptions,
  });

  final VoidCallback onOpenOptions;

  @override
  ConsumerState<ControlDock> createState() => _ControlDockState();
}

class _ControlDockState extends ConsumerState<ControlDock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _playPauseIconController;

  @override
  void initState() {
    super.initState();
    _playPauseIconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      value: ref.read(timerEngineProvider).isRunning ? 1.0 : 0.0,
    );
  }

  @override
  void dispose() {
    _playPauseIconController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timerState = ref.watch(timerEngineProvider);
    final strictMode = ref.watch(settingsProvider.select((s) => s.strictMode));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    ref.listen<bool>(
      timerEngineProvider.select((s) => s.isRunning),
      (prev, isRunning) {
        if (isRunning) {
          _playPauseIconController.forward();
        } else {
          _playPauseIconController.reverse();
        }
      },
    );

    final pauseLocked =
        strictMode && timerState.isRunning && !timerState.phase.isBreak;
    final skipIcon = timerState.mode == FocusMode.pomodoro
        ? Icons.skip_next_rounded
        : Icons.stop_rounded;
    final skipTooltip = timerState.mode == FocusMode.pomodoro
        ? 'Skip Phase'
        : 'End Session';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Left — Options Panel Button
          Tooltip(
            message: 'Options & Presets',
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                widget.onOpenOptions();
              },
              borderRadius: BorderRadius.circular(AppTheme.panelRadius),
              child: Container(
                width: 48,
                height: 48,
                decoration: AppTheme.panelDecoration(
                  context,
                  radius: AppTheme.panelRadius,
                ),
                child: Icon(
                  Icons.tune_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),

          // Center — Deep Mineral Pine Primary Play / Pause Panel
          GestureDetector(
            onTap: () {
              if (pauseLocked) {
                HapticFeedback.heavyImpact();
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text('Strict Mode active · Hold stop to abort'),
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                return;
              }
              HapticFeedback.mediumImpact();
              ref.read(timerEngineProvider.notifier).togglePlayPause();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              width: timerState.isRunning ? 92 : 124,
              height: 54,
              decoration: BoxDecoration(
                color: pauseLocked
                    ? theme.colorScheme.surface
                    : MagnColors.deepMineralPine,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: pauseLocked
                      ? MagnColors.cinnabarRed
                      : (isDark
                          ? MagnColors.warmSilkCream.withValues(alpha: 0.35)
                          : MagnColors.inkOak.withValues(alpha: 0.25)),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: pauseLocked
                    ? const Icon(
                        Icons.lock_rounded,
                        size: 22,
                        color: MagnColors.cinnabarRed,
                      )
                    : AnimatedIcon(
                        icon: AnimatedIcons.play_pause,
                        progress: _playPauseIconController,
                        size: 28,
                        color: MagnColors.warmSilkCream,
                      ),
              ),
            ),
          ),

          // Right — Hold-to-Skip / Stop Panel Button (0.8s Cinnabar Red progress border)
          HoldToSkipButton(
            enabled: timerState.isActive,
            icon: skipIcon,
            tooltip: skipTooltip,
            onCompleted: () {
              ref.read(timerEngineProvider.notifier).skipOrStop();
            },
          ),
        ],
      ),
    );
  }
}
