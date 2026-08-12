import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A circular initials avatar, colored deterministically from the user's
/// id/name so the same person gets the same color everywhere (inbox, chat
/// thread, ...) — a lightweight stand-in for a real profile photo.
class UserAvatar extends StatelessWidget {
  final String name;
  final String? seed;
  final double radius;

  const UserAvatar({
    super.key,
    required this.name,
    this.seed,
    this.radius = 20,
  });

  static const List<Color> _palette = [
    Color(0xFF0F5238),
    Color(0xFF6D4C41),
    Color(0xFF1565C0),
    Color(0xFF8E24AA),
    Color(0xFFEF6C00),
    Color(0xFF00796B),
    Color(0xFFC2185B),
    Color(0xFF5D4037),
  ];

  String get _initials {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  Color get _color {
    final key = (seed?.isNotEmpty == true ? seed! : name);
    final hash = key.codeUnits.fold<int>(0, (sum, c) => sum + c);
    return _palette[hash % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.15),
      child: Text(
        _initials,
        style: GoogleFonts.inter(
          fontSize: radius * 0.7,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
