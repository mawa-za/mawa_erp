import 'package:flutter/material.dart';

/// Shared MAWA visual language used by the ERP application.
///
/// Keep feature pages dependent on these semantic tokens rather than hardcoded
/// colours so that the entire application remains visually consistent.
class MawaDesign {
  MawaDesign._();

  static const Color red = Color(0xFFF20D1A);
  static const Color redDark = Color(0xFFC9000B);
  static const Color redSoft = Color(0xFFFFECEE);
  static const Color navy = Color(0xFF0B1F33);
  static const Color navySoft = Color(0xFF17344F);
  static const Color page = Color(0xFFF4F7FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF8FAFC);
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderStrong = Color(0xFFCBD5E1);
  static const Color text = navy;
  static const Color textMuted = Color(0xFF64748B);
  static const Color textSubtle = Color(0xFF94A3B8);
  static const Color success = Color(0xFF3FAE5A);
  static const Color successSoft = Color(0xFFEAF8EE);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningSoft = Color(0xFFFFF7E6);
  static const Color info = Color(0xFF2F80ED);
  static const Color infoSoft = Color(0xFFEAF3FF);

  static const double pageMaxWidth = 1560;
  static const double contentMaxWidth = 1320;
  static const double desktopSidebarWidth = 224;
  static const double cardRadius = 16;
  static const double dialogRadius = 20;
  static const double fieldRadius = 10;

  static const EdgeInsets pagePadding = EdgeInsets.fromLTRB(28, 24, 28, 32);
  static const EdgeInsets compactPagePadding = EdgeInsets.fromLTRB(16, 16, 16, 24);

  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x120F172A),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> floatingShadow = [
    BoxShadow(
      color: Color(0x240F172A),
      blurRadius: 36,
      offset: Offset(0, 16),
    ),
  ];

  static EdgeInsets responsivePagePadding(double width) =>
      width < 700 ? compactPagePadding : pagePadding;

  static int responsiveGridCount(
    double width, {
    double minimumCardWidth = 250,
    int maxColumns = 5,
  }) {
    final count = (width / minimumCardWidth).floor();
    return count.clamp(1, maxColumns).toInt();
  }

  static Color iconTint(int index) {
    const colours = <Color>[
      red,
      info,
      success,
      Color(0xFFF97316),
      Color(0xFF8B5CF6),
      Color(0xFF0EA5A8),
      warning,
      Color(0xFF475569),
    ];
    return colours[index % colours.length];
  }

  static Color iconBackground(Color colour) => Color.alphaBlend(
        colour.withValues(alpha: 0.11),
        surface,
      );
}
