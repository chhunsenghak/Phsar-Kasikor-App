import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/colors.dart';
import 'auth_hero.dart';

/// The minimal, bottom-border-only text field used on the redesigned auth
/// screens — a lighter alternative to [CustomInput]'s filled box, scoped to
/// login/register so the app's other forms are untouched.
class AuthUnderlineField extends StatelessWidget {
  final String label;
  final String hintText;
  final TextEditingController? controller;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;

  const AuthUnderlineField({
    super.key,
    required this.label,
    required this.hintText,
    this.controller,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            color: authLabelText,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          inputFormatters: inputFormatters,
          style: GoogleFonts.inter(fontSize: 15, color: AppColors.onSurface),
          cursorColor: AppColors.primary,
          decoration: InputDecoration(
            isDense: true,
            hintText: hintText,
            hintStyle: GoogleFonts.inter(fontSize: 15, color: authFaintText),
            suffixIcon: suffixIcon,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            border: const UnderlineInputBorder(borderSide: BorderSide(color: authHairline, width: 1.5)),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: authHairline, width: 1.5)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
            errorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.error, width: 1.5)),
            focusedErrorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.error, width: 1.5)),
            errorStyle: GoogleFonts.inter(fontSize: 11.5, color: AppColors.error),
          ),
        ),
      ],
    );
  }
}
