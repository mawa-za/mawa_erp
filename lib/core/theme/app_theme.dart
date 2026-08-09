import 'package:flutter/material.dart';

import 'mawa_design.dart';

class AppTheme {
  AppTheme._();

  static const Color brandRed = MawaDesign.red;
  static const Color brandRedDark = MawaDesign.redDark;
  static const Color brandNavy = MawaDesign.navy;
  static const Color brandNavySoft = MawaDesign.navySoft;

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: MawaDesign.red,
      brightness: Brightness.light,
      primary: MawaDesign.red,
      onPrimary: Colors.white,
      secondary: MawaDesign.navy,
      onSecondary: Colors.white,
      surface: MawaDesign.surface,
      error: const Color(0xFFDC2626),
    ).copyWith(
      primaryContainer: MawaDesign.redSoft,
      onPrimaryContainer: MawaDesign.redDark,
      secondaryContainer: const Color(0xFFEAF0F6),
      onSecondaryContainer: MawaDesign.navy,
      surfaceContainerLowest: MawaDesign.surface,
      surfaceContainerLow: MawaDesign.surfaceMuted,
      surfaceContainer: const Color(0xFFF1F5F9),
      surfaceContainerHigh: const Color(0xFFEFF3F8),
      onSurface: MawaDesign.text,
      onSurfaceVariant: MawaDesign.textMuted,
      outline: MawaDesign.borderStrong,
      outlineVariant: MawaDesign.border,
    );

    OutlineInputBorder inputBorder(Color colour, {double width = 1}) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(MawaDesign.fieldRadius),
          borderSide: BorderSide(color: colour, width: width),
        );

    final baseTextTheme = ThemeData.light().textTheme.copyWith(
          displayLarge: const TextStyle(
            fontSize: 48,
            height: 1.08,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.6,
          ),
          displayMedium: const TextStyle(
            fontSize: 38,
            height: 1.1,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.2,
          ),
          headlineLarge: const TextStyle(
            fontSize: 30,
            height: 1.16,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
          headlineMedium: const TextStyle(
            fontSize: 25,
            height: 1.2,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.55,
          ),
          headlineSmall: const TextStyle(
            fontSize: 21,
            height: 1.25,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
          titleLarge: const TextStyle(
            fontSize: 19,
            height: 1.28,
            fontWeight: FontWeight.w700,
          ),
          titleMedium: const TextStyle(
            fontSize: 15.5,
            height: 1.3,
            fontWeight: FontWeight.w700,
          ),
          titleSmall: const TextStyle(
            fontSize: 13.5,
            height: 1.3,
            fontWeight: FontWeight.w700,
          ),
          bodyLarge: const TextStyle(fontSize: 15.5, height: 1.5),
          bodyMedium: const TextStyle(fontSize: 14, height: 1.48),
          bodySmall: const TextStyle(fontSize: 12.5, height: 1.45),
          labelLarge: const TextStyle(
            fontSize: 13.5,
            height: 1.2,
            fontWeight: FontWeight.w700,
          ),
          labelMedium: const TextStyle(
            fontSize: 12,
            height: 1.2,
            fontWeight: FontWeight.w700,
          ),
          labelSmall: const TextStyle(
            fontSize: 10.5,
            height: 1.2,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.15,
          ),
        ).apply(
          bodyColor: MawaDesign.text,
          displayColor: MawaDesign.text,
          fontFamily: 'Roboto',
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      fontFamily: 'Roboto',
      textTheme: baseTextTheme,
      primaryColor: MawaDesign.red,
      scaffoldBackgroundColor: MawaDesign.page,
      canvasColor: MawaDesign.page,
      cardColor: MawaDesign.surface,
      dividerColor: MawaDesign.border,
      visualDensity: VisualDensity.standard,
      splashFactory: InkRipple.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: MawaDesign.surface,
        foregroundColor: MawaDesign.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Color(0x180F172A),
        centerTitle: false,
        toolbarHeight: 68,
        titleTextStyle: TextStyle(
          color: MawaDesign.text,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.25,
        ),
        iconTheme: IconThemeData(color: MawaDesign.navySoft, size: 22),
        actionsIconTheme: IconThemeData(color: MawaDesign.navySoft, size: 22),
      ),
      cardTheme: CardThemeData(
        color: MawaDesign.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        shadowColor: const Color(0x160F172A),
        margin: const EdgeInsets.symmetric(vertical: 6),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MawaDesign.cardRadius),
          side: const BorderSide(color: MawaDesign.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: MawaDesign.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 18,
        shadowColor: const Color(0x380F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MawaDesign.dialogRadius),
        ),
        titleTextStyle: const TextStyle(
          color: MawaDesign.text,
          fontSize: 20,
          height: 1.25,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
        contentTextStyle: const TextStyle(
          color: MawaDesign.textMuted,
          fontSize: 14,
          height: 1.5,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: MawaDesign.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: MawaDesign.surface,
        elevation: 18,
        modalElevation: 18,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: MawaDesign.surface,
        hoverColor: MawaDesign.surfaceMuted,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        labelStyle: const TextStyle(
          color: MawaDesign.textMuted,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
        floatingLabelStyle: const TextStyle(
          color: MawaDesign.red,
          fontWeight: FontWeight.w700,
        ),
        hintStyle: const TextStyle(color: MawaDesign.textSubtle),
        helperStyle: const TextStyle(color: MawaDesign.textMuted),
        prefixIconColor: MawaDesign.textMuted,
        suffixIconColor: MawaDesign.textMuted,
        border: inputBorder(MawaDesign.borderStrong),
        enabledBorder: inputBorder(MawaDesign.borderStrong),
        focusedBorder: inputBorder(MawaDesign.red, width: 1.6),
        errorBorder: inputBorder(const Color(0xFFDC2626)),
        focusedErrorBorder: inputBorder(const Color(0xFFDC2626), width: 1.6),
        disabledBorder: inputBorder(MawaDesign.border),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(MawaDesign.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(8),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: MawaDesign.surface,
          border: inputBorder(MawaDesign.borderStrong),
          enabledBorder: inputBorder(MawaDesign.borderStrong),
          focusedBorder: inputBorder(MawaDesign.red, width: 1.6),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: MawaDesign.red,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFCBD5E1),
          disabledForegroundColor: const Color(0xFF64748B),
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: MawaDesign.red,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          elevation: 0,
          foregroundColor: MawaDesign.navy,
          backgroundColor: MawaDesign.surface,
          side: const BorderSide(color: MawaDesign.borderStrong),
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: MawaDesign.red,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: MawaDesign.navySoft,
          hoverColor: MawaDesign.surfaceMuted,
          highlightColor: MawaDesign.redSoft,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: MawaDesign.red,
        foregroundColor: Colors.white,
        elevation: 4,
        focusElevation: 5,
        hoverElevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF1F5F9),
        selectedColor: MawaDesign.redSoft,
        disabledColor: MawaDesign.border,
        labelStyle: const TextStyle(
          color: MawaDesign.text,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: const TextStyle(color: MawaDesign.text),
        side: const BorderSide(color: MawaDesign.border),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
      dividerTheme: const DividerThemeData(
        color: MawaDesign.border,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        tileColor: MawaDesign.surface,
        iconColor: MawaDesign.textMuted,
        textColor: MawaDesign.text,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minVerticalPadding: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: const WidgetStatePropertyAll(Color(0xFFF8FAFC)),
        dataRowColor: const WidgetStatePropertyAll(MawaDesign.surface),
        headingTextStyle: const TextStyle(
          color: MawaDesign.navySoft,
          fontWeight: FontWeight.w800,
          fontSize: 12.5,
        ),
        dataTextStyle: const TextStyle(
          color: MawaDesign.text,
          fontSize: 13.5,
        ),
        dividerThickness: 1,
        horizontalMargin: 18,
        columnSpacing: 24,
        headingRowHeight: 48,
        dataRowMinHeight: 52,
        dataRowMaxHeight: 64,
        decoration: BoxDecoration(
          color: MawaDesign.surface,
          border: Border.all(color: MawaDesign.border),
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        indicatorColor: MawaDesign.red,
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: MawaDesign.navy,
        unselectedLabelColor: MawaDesign.textMuted,
        dividerColor: MawaDesign.border,
        labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: MawaDesign.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 10,
        shadowColor: const Color(0x280F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(color: MawaDesign.text, fontSize: 13.5),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: MawaDesign.surface,
        indicatorColor: MawaDesign.redSoft,
        selectedIconTheme: IconThemeData(color: MawaDesign.red),
        selectedLabelTextStyle: TextStyle(
          color: MawaDesign.navy,
          fontWeight: FontWeight.w700,
        ),
        unselectedIconTheme: IconThemeData(color: MawaDesign.textMuted),
        unselectedLabelTextStyle: TextStyle(color: MawaDesign.textMuted),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: MawaDesign.surface,
        indicatorColor: MawaDesign.redSoft,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: MawaDesign.red),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: MawaDesign.navy,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13.5),
        actionTextColor: Colors.white,
        elevation: 8,
        insetPadding: const EdgeInsets.all(18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: MawaDesign.navy,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.hovered)
                ? MawaDesign.borderStrong
                : MawaDesign.border),
        radius: const Radius.circular(10),
        thickness: const WidgetStatePropertyAll(7),
        crossAxisMargin: 3,
      ),
    );
  }
}
