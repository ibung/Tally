import 'package:flutter/material.dart';

class ChartPalette {
  ChartPalette._();

  static const List<Color> lightColors = [
    Color(0xFF2563EB), // Blue
    Color(0xFF10B981), // Emerald
    Color(0xFFF59E0B), // Amber
    Color(0xFF8B5CF6), // Purple
    Color(0xFFEC4899), // Pink
    Color(0xFF06B6D4), // Cyan
    Color(0xFFF97316), // Orange
    Color(0xFF14B8A6), // Teal
    Color(0xFF6366F1), // Indigo
    Color(0xFF84CC16), // Lime
    Color(0xFFE11D48), // Rose
    Color(0xFF64748B), // Slate
  ];

  static const List<Color> darkColors = [
    Color(0xFF60A5FA), // Light Blue
    Color(0xFF34D399), // Mint Emerald
    Color(0xFFFBBF24), // Bright Amber
    Color(0xFFA78BFA), // Lavender
    Color(0xFFF472B6), // Bright Pink
    Color(0xFF22D3EE), // Bright Cyan
    Color(0xFFFB923C), // Bright Orange
    Color(0xFF2DD4BF), // Bright Teal
    Color(0xFF818CF8), // Bright Indigo
    Color(0xFFA3E635), // Bright Lime
    Color(0xFFFB7185), // Bright Rose
    Color(0xFF94A3B8), // Cool Gray
  ];

  static Color getColor(int index, bool isDark) {
    final list = isDark ? darkColors : lightColors;
    return list[index % list.length];
  }
}
