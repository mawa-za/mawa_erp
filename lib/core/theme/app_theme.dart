import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const Color _primary = Color(0xFF4F46E5);
  static const Color _pageBackground = Color(0xFFF3F5FA);
  static const Color _containerBackground = Color(0xFFFFFFFF);
  static const Color _fieldBackground = Color(0xFFFBFCFF);
  static const Color _fieldBorder = Color(0xFFCBD5E1);
  static const Color _fieldFocusedBorder = Color(0xFF4F46E5);
  static const Color _text = Color(0xFF0F172A);
  static const Color _mutedText = Color(0xFF475569);
  static const Color _divider = Color(0xFFE2E8F0);

  static ThemeData get light {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: _primary,
      brightness: Brightness.light,
      primary: _primary,
      surface: _containerBackground,
      error: const Color(0xFFDC2626),
    ).copyWith(
      onSurface: _text,
      surfaceContainerLowest: _containerBackground,
      surfaceContainerLow: const Color(0xFFF8FAFC),
      surfaceContainer: const Color(0xFFF1F5F9),
      surfaceContainerHigh: const Color(0xFFEFF3F8),
      outline: _fieldBorder,
      outlineVariant: _divider,
    );

    OutlineInputBorder fieldBorder(Color color, {double width = 1.2}) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _pageBackground,
      canvasColor: _pageBackground,
      cardColor: _containerBackground,
      dividerColor: _divider,
      primaryColor: _primary,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: _containerBackground,
        foregroundColor: _text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Color(0x1A0F172A),
      ),
      cardTheme: CardTheme(
        color: _containerBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        shadowColor: const Color(0x1A0F172A),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _divider),
        ),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: _containerBackground,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: _containerBackground,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _fieldBackground,
        hoverColor: const Color(0xFFF8FAFC),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        labelStyle: const TextStyle(color: _mutedText, fontWeight: FontWeight.w500),
        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
        helperStyle: const TextStyle(color: _mutedText),
        prefixIconColor: _mutedText,
        suffixIconColor: _mutedText,
        border: fieldBorder(_fieldBorder),
        enabledBorder: fieldBorder(_fieldBorder),
        focusedBorder: fieldBorder(_fieldFocusedBorder, width: 1.8),
        errorBorder: fieldBorder(const Color(0xFFDC2626)),
        focusedErrorBorder: fieldBorder(const Color(0xFFDC2626), width: 1.8),
        disabledBorder: fieldBorder(const Color(0xFFE2E8F0)),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _fieldBackground,
          border: fieldBorder(_fieldBorder),
          enabledBorder: fieldBorder(_fieldBorder),
          focusedBorder: fieldBorder(_fieldFocusedBorder, width: 1.8),
        ),
      ),
      textTheme: ThemeData.light().textTheme.apply(
            bodyColor: _text,
            displayColor: _text,
          ),
      dividerTheme: const DividerThemeData(
        color: _divider,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        tileColor: _containerBackground,
        iconColor: _mutedText,
        textColor: _text,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF1F5F9),
        selectedColor: const Color(0xFFE0E7FF),
        disabledColor: const Color(0xFFE2E8F0),
        labelStyle: const TextStyle(color: _text),
        secondaryLabelStyle: const TextStyle(color: _text),
        side: const BorderSide(color: _divider),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFCBD5E1),
          disabledForegroundColor: const Color(0xFF64748B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _primary,
          side: const BorderSide(color: _fieldBorder),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      dataTableTheme: const DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(Color(0xFFF1F5F9)),
        dataRowColor: WidgetStatePropertyAll(_containerBackground),
        dividerThickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0F172A),
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
