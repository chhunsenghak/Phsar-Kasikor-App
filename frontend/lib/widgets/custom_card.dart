import 'package:flutter/material.dart';
import '../constants/colors.dart';

class CustomCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final Color backgroundColor;
  final bool elevated;
  final int elevationLevel; // 1 or 2
  final EdgeInsetsGeometry padding;
  final BorderSide borderSide;
  final VoidCallback? onTap;

  const CustomCard({
    super.key,
    required this.child,
    this.borderRadius = AppDesign.borderRadiusDefault,
    this.backgroundColor = AppColors.surface,
    this.elevated = true,
    this.elevationLevel = 1,
    this.padding = const EdgeInsets.all(16.0),
    this.borderSide = BorderSide.none,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    List<BoxShadow> shadows = [];
    if (elevated) {
      shadows = elevationLevel == 2 ? AppDesign.level2Shadow : AppDesign.level1Shadow;
    }

    Widget container = Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: shadows,
        border: borderSide != BorderSide.none ? Border.fromBorderSide(borderSide) : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: container,
        ),
      );
    }

    return container;
  }
}
