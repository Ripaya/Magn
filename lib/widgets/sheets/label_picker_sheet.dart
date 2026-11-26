import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/app_providers.dart';

/// Modular panel bottom sheet for picking or creating a session label.
class LabelPickerSheet extends ConsumerStatefulWidget {
  const LabelPickerSheet({super.key});

  @override
  ConsumerState<LabelPickerSheet> createState() => _LabelPickerSheetState();
}

class _LabelPickerSheetState extends ConsumerState<LabelPickerSheet> {
  final TextEditingController _nameController = TextEditingController();
  int _selectedColorValue = MagnColors.labelPalette.first;
  bool _creatingNew = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _toHex(int colorValue) {
    final rgb = colorValue & 0x00FFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  Future<void> _submitNewLabel() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final created = await ref.read(labelsProvider.notifier).createLabel(
          name: name,
          colorHex: _toHex(_selectedColorValue),
        );
    await ref
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(selectedLabelId: created.id));
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final labels = ref.watch(labelsProvider);
    final selectedId =
        ref.watch(settingsProvider.select((s) => s.selectedLabelId));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final headerColor =
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
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 3,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: MagnColors.borderColor(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Focus Label',
                    style: AppTheme.headingStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: headerColor,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _creatingNew = !_creatingNew),
                    icon: Icon(
                      _creatingNew ? Icons.close_rounded : Icons.add_rounded,
                      size: 18,
                    ),
                    label: Text(_creatingNew ? 'Cancel' : 'New Label'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_creatingNew) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: AppTheme.panelDecoration(
                    context,
                    active: true,
                    radius: AppTheme.panelRadius,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _nameController,
                        autofocus: true,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          hintText: 'e.g., Architecture, Reading, Deep Work',
                          filled: true,
                          fillColor: theme.scaffoldBackgroundColor,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.tightRadius,
                            ),
                            borderSide: BorderSide(
                              color: MagnColors.borderColor(context),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.tightRadius,
                            ),
                            borderSide: BorderSide(
                              color: MagnColors.borderColor(
                                context,
                                active: true,
                              ),
                              width: 1.5,
                            ),
                          ),
                        ),
                        onSubmitted: (_) => _submitNewLabel(),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: MagnColors.labelPalette.map((colorVal) {
                              final selected = _selectedColorValue == colorVal;
                              return GestureDetector(
                                onTap: () => setState(
                                  () => _selectedColorValue = colorVal,
                                ),
                                child: Container(
                                  width: 26,
                                  height: 26,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: Color(colorVal),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: selected
                                          ? theme.colorScheme.onSurface
                                          : MagnColors.borderColor(context),
                                      width: selected ? 2.0 : 1.0,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          FilledButton(
                            onPressed: _submitNewLabel,
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: labels.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final label = labels[index];
                    final isSelected = label.id == selectedId;
                    return InkWell(
                      borderRadius: BorderRadius.circular(AppTheme.panelRadius),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref.read(settingsProvider.notifier).update(
                              (s) => s.copyWith(selectedLabelId: label.id),
                            );
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                        decoration: AppTheme.panelDecoration(
                          context,
                          active: isSelected,
                          radius: AppTheme.panelRadius,
                          color: isSelected
                              ? MagnColors.deepMineralPine
                              : theme.colorScheme.surface,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: label.color,
                                borderRadius: BorderRadius.circular(3),
                                border: isSelected
                                    ? Border.all(
                                        color: MagnColors.warmSilkCream
                                            .withValues(alpha: 0.7),
                                        width: 1,
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                label.name,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: isSelected
                                      ? FontWeight.w500
                                      : FontWeight.w400,
                                  color: isSelected
                                      ? MagnColors.warmSilkCream
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_rounded,
                                size: 19,
                                color: MagnColors.warmSilkCream,
                              )
                            else if (label.id != 'label_general')
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 28,
                                  minHeight: 28,
                                ),
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                  color: MagnColors.cinnabarRed,
                                ),
                                onPressed: () {
                                  ref
                                      .read(labelsProvider.notifier)
                                      .archiveLabel(label.id);
                                },
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
