import 'package:flutter/material.dart';

/// Farm desk green, shared by light and dark.
class FarmColors {
  static const accent = Color(0xFF3EE0A0);
  static const accentInk = Color(0xFF042117);
  static const danger = Color(0xFFFF8D84);
  static const warn = Color(0xFFF0C36A);
}

class Desk {
  static Color card(BuildContext context) => Theme.of(context).colorScheme.surface;
  static Color muted(BuildContext context) => Theme.of(context).colorScheme.onSurfaceVariant;
  static Color ink(BuildContext context) => Theme.of(context).colorScheme.onSurface;
  static Color line(BuildContext context) => Theme.of(context).dividerColor;
}

ThemeData farmTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final bg = dark ? const Color(0xFF0C0F14) : const Color(0xFFF4F7F5);
  final card = dark ? const Color(0xFF171D27) : const Color(0xFFFFFFFF);
  final ink = dark ? const Color(0xFFF3F6F8) : const Color(0xFF14201B);
  final muted = dark ? const Color(0xFF93A0B0) : const Color(0xFF5C6B73);
  final field = dark ? const Color(0xFF0D1117) : const Color(0xFFF7F8F6);
  final line = dark ? const Color(0x14FFFFFF) : const Color(0x1F14201B);
  final scheme = ColorScheme.fromSeed(
    seedColor: FarmColors.accent,
    brightness: brightness,
  ).copyWith(
    surface: card,
    onSurface: ink,
    onSurfaceVariant: muted,
    primary: FarmColors.accent,
    onPrimary: FarmColors.accentInk,
    error: FarmColors.danger,
    outline: line,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: bg,
    colorScheme: scheme,
    dividerColor: line,
    fontFamily: 'Segoe UI',
  );
  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      foregroundColor: ink,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: field,
      labelStyle: TextStyle(color: muted),
      hintStyle: TextStyle(color: muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: FarmColors.accent, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: card,
      indicatorColor: const Color(0x333EE0A0),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? FarmColors.accent : muted);
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(color: selected ? FarmColors.accent : muted);
      }),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ink,
        side: BorderSide(color: line),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: FarmColors.accent,
        foregroundColor: FarmColors.accentInk,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    textTheme: base.textTheme.apply(bodyColor: ink, displayColor: ink),
  );
}
