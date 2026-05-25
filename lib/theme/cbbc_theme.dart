import 'package:flutter/material.dart';

/// Paleta institucional inspirada na identidade visual da CBBC
/// (Confederação Brasileira de Basquetebol em Cadeira de Rodas).
///
/// - azul cobalto do logo como cor primária;
/// - laranja-basquete como accent secundário;
/// - fundo off-white claro;
/// - vermelho institucional para alerta de limite excedido.
abstract class CbbcColors {
  CbbcColors._();

  /// Azul cobalto principal — usado em logo, botões primários, bordas.
  static const Color blue = Color(0xFF1F66B6);

  /// Variante mais escura — borda/contraste.
  static const Color blueDeep = Color(0xFF154B82);

  /// Variante translúcida — fundos sutis (cards selecionados).
  static const Color blueSoft = Color(0xFFDCE9F5);

  /// Laranja basquete — accent secundário (bola do logo).
  static const Color orange = Color(0xFFE87B2B);

  /// Off-white de fundo geral.
  static const Color offWhite = Color(0xFFFAFAFA);

  /// Superfícies elevadas (cards, headers).
  static const Color offWhiteElevated = Color(0xFFF1F4F8);

  /// Texto principal.
  static const Color textPrimary = Color(0xFF1A1A1A);

  /// Texto secundário.
  static const Color textSecondary = Color(0xFF5A6068);

  /// Vermelho institucional usado no alerta "Limite de pontos excedido.".
  static const Color alertRed = Color(0xFFB3261E);

  /// Fundo levemente avermelhado quando o limite é excedido.
  static const Color alertRedSurface = Color(0xFFFDECEC);
}

/// Tema Material 3 do app, com paleta CBBC.
ThemeData buildCbbcTheme() {
  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: CbbcColors.blue,
    brightness: Brightness.light,
    primary: CbbcColors.blue,
    onPrimary: Colors.white,
    secondary: CbbcColors.orange,
    onSecondary: Colors.white,
    surface: CbbcColors.offWhite,
    onSurface: CbbcColors.textPrimary,
    error: CbbcColors.alertRed,
    onError: Colors.white,
  );

  final TextTheme baseText = ThemeData(brightness: Brightness.light).textTheme;
  final TextTheme textTheme = baseText.apply(
    bodyColor: CbbcColors.textPrimary,
    displayColor: CbbcColors.textPrimary,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: CbbcColors.offWhite,
    textTheme: textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: CbbcColors.blue,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      iconTheme: IconThemeData(color: Colors.white),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: CbbcColors.blue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: CbbcColors.blueDeep,
        side: const BorderSide(color: CbbcColors.blueDeep, width: 1.2),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: CbbcColors.blueDeep,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    dropdownMenuTheme: const DropdownMenuThemeData(
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll<Color>(CbbcColors.offWhite),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color?>(
        (Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) return CbbcColors.blue;
          return Colors.transparent;
        },
      ),
      checkColor: const WidgetStatePropertyAll<Color>(Colors.white),
      side: const BorderSide(color: CbbcColors.blueDeep, width: 1.4),
    ),
    cardTheme: CardThemeData(
      color: CbbcColors.offWhiteElevated,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0x22000000)),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0x1A000000),
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: CbbcColors.textPrimary,
      contentTextStyle: TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: CbbcColors.offWhite,
      surfaceTintColor: Colors.transparent,
    ),
  );
}
