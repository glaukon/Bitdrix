import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';

/// A filter chip whose selected state is easy to see: purple border and
/// bold label, not just a faint tint.
class SelectableChip extends StatelessWidget {
  const SelectableChip({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.label,
    this.avatar,
  });

  final bool selected;
  final ValueChanged<bool> onSelected;
  final String label;
  final Widget? avatar;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: selected,
      showCheckmark: false,
      onSelected: onSelected,
      avatar: avatar,
      side: BorderSide(
        color: selected ? AppTheme.primary : const Color(0xFF333348),
        width: selected ? 1.5 : 1,
      ),
      label: Text(
        label,
        style: TextStyle(
          color: selected ? AppTheme.onBackground : AppTheme.onSurface,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
    );
  }
}
