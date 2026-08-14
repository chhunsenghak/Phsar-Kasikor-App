import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/colors.dart';
import 'auth_hero.dart';

class AuthRoleOption {
  final String value;
  final String label;
  const AuthRoleOption(this.value, this.label);
}

/// Two-way segmented control replacing the old tab-button role picker on
/// registration — a quieter way to choose Buyer vs Farmer.
class AuthRoleSegment extends StatelessWidget {
  final List<AuthRoleOption> options;
  final String selected;
  final ValueChanged<String> onChanged;

  const AuthRoleSegment({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: options.map((option) {
          final isSelected = option.value == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(option.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  option.label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? AppColors.onPrimary : authMutedText,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
