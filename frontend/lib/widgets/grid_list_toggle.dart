import 'package:flutter/material.dart';
import '../constants/colors.dart';

class GridListToggle extends StatelessWidget {
  final bool isGridView;
  final ValueChanged<bool> onChanged;

  const GridListToggle({
    super.key,
    required this.isGridView,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            Icons.grid_view_rounded,
            color: isGridView ? AppColors.primary : AppColors.outline,
            size: 20,
          ),
          onPressed: () => onChanged(true),
        ),
        IconButton(
          icon: Icon(
            Icons.view_list_rounded,
            color: !isGridView ? AppColors.primary : AppColors.outline,
            size: 20,
          ),
          onPressed: () => onChanged(false),
        ),
      ],
    );
  }
}
