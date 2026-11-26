import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/app_providers.dart';

/// Fast bottom sheet for picking or creating a colored session label without
/// cluttering the main timer screen.
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

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          12,
          24,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Focus Label',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => _creatingNew = !_creatingNew),
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
              TextField(
                controller: _nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'e.g., Architecture, Reading, Deep Work',
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
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
                        onTap: () =>
                            setState(() => _selectedColorValue = colorVal),
                        child: Container(
                          width: 28,
                          height: 28,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: Color(colorVal),
                            shape: BoxShape.circle,
                            border: selected
                                ? Border.all(
                                    color: theme.colorScheme.onSurface,
                                    width: 2.5,
                                  )
                                : null,
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
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
            ],
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: labels.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final label = labels[index];
                  final isSelected = label.id == selectedId;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    selected: isSelected,
                    selectedTileColor:
                        theme.colorScheme.onSurface.withValues(alpha: 0.06),
                    leading: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: label.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    title: Text(
                      label.name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSelected)
                          Icon(
                            Icons.check_rounded,
                            size: 20,
                            color: theme.colorScheme.onSurface,
                          ),
                        if (label.id != 'label_general' && !isSelected)
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.45),
                            ),
                            onPressed: () {
                              ref
                                  .read(labelsProvider.notifier)
                                  .archiveLabel(label.id);
                            },
                          ),
                      ],
                    ),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref.read(settingsProvider.notifier).update(
                            (s) => s.copyWith(selectedLabelId: label.id),
                          );
                      Navigator.of(context).pop();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
