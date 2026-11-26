import 'dart:io';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/app_settings.dart';
import '../../models/focus_preset.dart';
import '../../providers/app_providers.dart';
import 'stats_history_sheet.dart';

/// Two-tier Options Architecture:
/// - Tier 1 (Always Visible): Smart Presets Strip + Core Toggles (DND, Keep Screen On, Ambient Sound)
/// - Tier 2 (Collapsible Accordions): Timing & Cycles, Dial & Visuals, Alerts & Notifications, Data & Backup
class OptionsSheet extends ConsumerStatefulWidget {
  const OptionsSheet({super.key});

  @override
  ConsumerState<OptionsSheet> createState() => _OptionsSheetState();
}

class _OptionsSheetState extends ConsumerState<OptionsSheet> {
  Future<void> _saveCurrentAsPreset() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Custom Preset'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'e.g., Thesis 45/10',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (name == null || name.isEmpty) return;
    final settings = ref.read(settingsProvider);
    final mode = ref.read(timerEngineProvider).mode;
    await ref.read(presetsProvider.notifier).saveCustomPreset(
          name: name,
          mode: mode,
          settings: settings,
        );
  }

  Future<void> _toggleDnd(bool enabled) async {
    final bridge = ref.read(nativeTimerBridgeProvider);
    if (enabled) {
      final hasPermission = await bridge.hasDndPermission();
      if (!hasPermission && mounted) {
        await bridge.requestDndPermission();
      }
    }
    await ref
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(autoDndEnabled: enabled));
  }

  Future<void> _exportFile({required bool asCsv}) async {
    final db = ref.read(databaseServiceProvider);
    final content = asCsv ? await db.exportAsCsv() : await db.exportAsJson();
    final ext = asCsv ? 'csv' : 'json';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'magn_focus_backup_$timestamp.$ext';

    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(content);
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Magn Focus Backup ($ext)',
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: content));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Copied $ext backup to clipboard'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _importBackupDialog() async {
    final controller = TextEditingController();
    final raw = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import JSON Backup'),
        content: TextField(
          controller: controller,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: 'Paste exported Magn JSON here...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (raw == null || raw.isEmpty) return;
    try {
      final count = await ref.read(databaseServiceProvider).importFromJson(raw);
      await ref.read(labelsProvider.notifier).refresh();
      await ref.read(sessionsProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imported $count sessions'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid backup JSON format'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final presets = ref.watch(presetsProvider);
    final timerState = ref.watch(timerEngineProvider);
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Options',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                children: [
                  // ── TIER 1: SMART PRESETS STRIP ─────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'SMART PRESETS',
                        style: theme.textTheme.labelSmall?.copyWith(
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.55),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _saveCurrentAsPreset,
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Save Current'),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 68,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: presets.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final preset = presets[index];
                        final isSelected = timerState.mode == preset.mode &&
                            settings.focusMinutes == (preset.focusSec ~/ 60);
                        return _PresetTile(
                          preset: preset,
                          selected: isSelected,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            ref
                                .read(timerEngineProvider.notifier)
                                .applyPreset(preset);
                          },
                          onDelete: preset.isBuiltIn
                              ? null
                              : () => ref
                                  .read(presetsProvider.notifier)
                                  .deletePreset(preset.id),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ── TIER 1: CORE TOGGLES ────────────────────────────────────
                  _SectionCard(
                    children: [
                      SwitchListTile(
                        title: const Text('Auto Do Not Disturb'),
                        subtitle: const Text(
                          'Activates Focus Mode Zen rule during sessions',
                        ),
                        secondary: const Icon(Icons.do_not_disturb_on_outlined),
                        value: settings.autoDndEnabled,
                        onChanged: _toggleDnd,
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Keep Screen On'),
                        subtitle: const Text(
                          'Prevent display sleep while dial is sweeping',
                        ),
                        secondary: const Icon(Icons.light_mode_outlined),
                        value: settings.keepScreenOn,
                        onChanged: (v) => ref
                            .read(settingsProvider.notifier)
                            .update((s) => s.copyWith(keepScreenOn: v)),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.graphic_eq_rounded,
                                  size: 20,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.72),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Ambient Sound',
                                  style: theme.textTheme.bodyLarge,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: AmbientSoundType.values.map((sound) {
                                final active = settings.ambientSound == sound;
                                return ChoiceChip(
                                  label: Text(sound.label),
                                  selected: active,
                                  onSelected: (_) {
                                    HapticFeedback.selectionClick();
                                    ref.read(settingsProvider.notifier).update(
                                          (s) => s.copyWith(ambientSound: sound),
                                        );
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── TIER 2: COLLAPSIBLE ADVANCED ACCORDIONS ─────────────────
                  _AccordionSection(
                    title: 'Timing & Cycles',
                    icon: Icons.timelapse_rounded,
                    children: [
                      _DurationSliderRow(
                        label: 'Focus Length',
                        value: settings.focusMinutes,
                        min: AppConstants.minFocusMinutes,
                        max: AppConstants.maxFocusMinutes,
                        unit: 'min',
                        onChanged: (val) => ref
                            .read(settingsProvider.notifier)
                            .update((s) => s.copyWith(focusMinutes: val)),
                      ),
                      _DurationSliderRow(
                        label: 'Short Break',
                        value: settings.shortBreakMinutes,
                        min: AppConstants.minShortBreakMinutes,
                        max: AppConstants.maxShortBreakMinutes,
                        unit: 'min',
                        onChanged: (val) => ref
                            .read(settingsProvider.notifier)
                            .update((s) => s.copyWith(shortBreakMinutes: val)),
                      ),
                      _DurationSliderRow(
                        label: 'Long Break',
                        value: settings.longBreakMinutes,
                        min: AppConstants.minLongBreakMinutes,
                        max: AppConstants.maxLongBreakMinutes,
                        unit: 'min',
                        onChanged: (val) => ref
                            .read(settingsProvider.notifier)
                            .update((s) => s.copyWith(longBreakMinutes: val)),
                      ),
                      _DurationSliderRow(
                        label: 'Sessions before Long Break',
                        value: settings.cyclesBeforeLongBreak,
                        min: AppConstants.minCyclesBeforeLongBreak,
                        max: AppConstants.maxCyclesBeforeLongBreak,
                        unit: 'rounds',
                        onChanged: (val) => ref
                            .read(settingsProvider.notifier)
                            .update(
                              (s) => s.copyWith(cyclesBeforeLongBreak: val),
                            ),
                      ),
                      SwitchListTile(
                        title: const Text('Auto-start Breaks'),
                        value: settings.autoStartBreaks,
                        onChanged: (v) => ref
                            .read(settingsProvider.notifier)
                            .update((s) => s.copyWith(autoStartBreaks: v)),
                      ),
                      SwitchListTile(
                        title: const Text('Auto-start Focus'),
                        value: settings.autoStartFocus,
                        onChanged: (v) => ref
                            .read(settingsProvider.notifier)
                            .update((s) => s.copyWith(autoStartFocus: v)),
                      ),
                      SwitchListTile(
                        title: const Text('Strict Mode'),
                        subtitle: const Text(
                          'Disables pausing during active focus blocks',
                        ),
                        value: settings.strictMode,
                        onChanged: (v) => ref
                            .read(settingsProvider.notifier)
                            .update((s) => s.copyWith(strictMode: v)),
                      ),
                      SwitchListTile(
                        title: const Text('Double-Tap +5 min Extension'),
                        subtitle: const Text(
                          'Double-tap dial center while running to add 5 min',
                        ),
                        value: settings.doubleTapExtendEnabled,
                        onChanged: (v) => ref
                            .read(settingsProvider.notifier)
                            .update(
                              (s) => s.copyWith(doubleTapExtendEnabled: v),
                            ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  _AccordionSection(
                    title: 'Dial & Visuals',
                    icon: Icons.radio_button_checked_rounded,
                    children: [
                      _OptionPickerTile<AppThemePreference>(
                        title: 'Appearance',
                        values: AppThemePreference.values,
                        selected: settings.themePreference,
                        labelOf: (v) => v.label,
                        onSelected: (v) => ref
                            .read(settingsProvider.notifier)
                            .update((s) => s.copyWith(themePreference: v)),
                      ),
                      _OptionPickerTile<DigitalReadoutMode>(
                        title: 'Digital Readout (MM:SS)',
                        values: DigitalReadoutMode.values,
                        selected: settings.digitalReadoutMode,
                        labelOf: (v) => v.label,
                        onSelected: (v) => ref
                            .read(settingsProvider.notifier)
                            .update((s) => s.copyWith(digitalReadoutMode: v)),
                      ),
                      _OptionPickerTile<EndlessGhostTarget>(
                        title: 'Endless Ghost Benchmark',
                        values: EndlessGhostTarget.values,
                        selected: settings.endlessGhostTarget,
                        labelOf: (v) => v.label,
                        onSelected: (v) => ref
                            .read(settingsProvider.notifier)
                            .update((s) => s.copyWith(endlessGhostTarget: v)),
                      ),
                      _OptionPickerTile<int>(
                        title: 'Rim Drag Increment',
                        values: const [1, 5],
                        selected: settings.rimDragStepMinutes,
                        labelOf: (v) => '$v min',
                        onSelected: (v) => ref
                            .read(settingsProvider.notifier)
                            .update((s) => s.copyWith(rimDragStepMinutes: v)),
                      ),
                      SwitchListTile(
                        title: const Text('Haptic Rim Ticks'),
                        subtitle: const Text(
                          'Tactile detents while rotating the dial rim',
                        ),
                        value: settings.hapticRimTicks,
                        onChanged: (v) => ref
                            .read(settingsProvider.notifier)
                            .update((s) => s.copyWith(hapticRimTicks: v)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  _AccordionSection(
                    title: 'Alerts & Notifications',
                    icon: Icons.notifications_none_rounded,
                    children: [
                      _OptionPickerTile<CompletionSound>(
                        title: 'Completion Sound',
                        values: CompletionSound.values,
                        selected: settings.completionSound,
                        labelOf: (v) => v.label,
                        onSelected: (v) => ref
                            .read(settingsProvider.notifier)
                            .update((s) => s.copyWith(completionSound: v)),
                      ),
                      _OptionPickerTile<VibrationPattern>(
                        title: 'Vibration Pattern',
                        values: VibrationPattern.values,
                        selected: settings.vibrationPattern,
                        labelOf: (v) => v.label,
                        onSelected: (v) => ref
                            .read(settingsProvider.notifier)
                            .update((s) => s.copyWith(vibrationPattern: v)),
                      ),
                      _OptionPickerTile<NotificationStyle>(
                        title: 'Persistent Notification Style',
                        values: NotificationStyle.values,
                        selected: settings.notificationStyle,
                        labelOf: (v) => v.label,
                        onSelected: (v) => ref
                            .read(settingsProvider.notifier)
                            .update((s) => s.copyWith(notificationStyle: v)),
                      ),
                      SwitchListTile(
                        title: const Text('Screen Flash Alert'),
                        subtitle: const Text(
                          'Subtle visual pulse for silent study spaces',
                        ),
                        value: settings.screenFlashAlert,
                        onChanged: (v) => ref
                            .read(settingsProvider.notifier)
                            .update((s) => s.copyWith(screenFlashAlert: v)),
                      ),
                      ListTile(
                        leading: const Icon(Icons.alarm_on_outlined),
                        title: const Text('Exact Alarm Permission'),
                        subtitle: const Text(
                          'Ensure Doze-safe phase chimes on Android 14+',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => ref
                            .read(nativeTimerBridgeProvider)
                            .requestExactAlarmPermission(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  _AccordionSection(
                    title: 'Data & Backup',
                    icon: Icons.storage_rounded,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.add_circle_outline_rounded),
                        title: const Text('Manual Session Entry'),
                        subtitle: const Text('Log an offline focus block'),
                        onTap: () async {
                          Navigator.of(context).pop();
                          await showManualSessionDialog(context, ref);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.table_chart_outlined),
                        title: const Text('Export History to CSV'),
                        onTap: () => _exportFile(asCsv: true),
                      ),
                      ListTile(
                        leading: const Icon(Icons.data_object_rounded),
                        title: const Text('Export Backup to JSON'),
                        onTap: () => _exportFile(asCsv: false),
                      ),
                      ListTile(
                        leading: const Icon(Icons.download_rounded),
                        title: const Text('Import Local JSON Backup'),
                        onTap: _importBackupDialog,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({
    required this.preset,
    required this.selected,
    required this.onTap,
    this.onDelete,
  });

  final FocusPreset preset;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withValues(alpha: 0.06);
    final fg = selected
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onDelete,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              preset.name,
              style: theme.textTheme.labelLarge?.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              preset.subtitle,
              style: AppTheme.monoStyle(
                fontSize: 11,
                color: fg.withValues(alpha: 0.72),
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.6),
        ),
      ),
      child: Column(children: children),
    );
  }
}

class _AccordionSection extends StatelessWidget {
  const _AccordionSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.55),
        ),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(icon, size: 20),
          title: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          childrenPadding: const EdgeInsets.only(bottom: 10),
          children: children,
        ),
      ),
    );
  }
}

class _DurationSliderRow extends StatelessWidget {
  const _DurationSliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final String unit;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: theme.textTheme.bodyMedium),
              Text(
                '$value $unit',
                style: AppTheme.monoStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          Slider(
            value: value.clamp(min, max).toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            onChanged: (v) => onChanged(v.round()),
          ),
        ],
      ),
    );
  }
}

class _OptionPickerTile<T> extends StatelessWidget {
  const _OptionPickerTile({
    required this.title,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  final String title;
  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: values.map((item) {
              final isSelected = item == selected;
              return ChoiceChip(
                label: Text(labelOf(item)),
                selected: isSelected,
                onSelected: (_) {
                  HapticFeedback.selectionClick();
                  onSelected(item);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
