import 'package:flutter/material.dart';

import '../data/catalog.dart';

// The Mossgrove palette (SPEC.md §10): cabinet-enamel green, cool card-stock neutrals, one brass accent kept for item
// numbers, Add to cart and the cart count, never for decoration. Dynamic colour is off: Flutter has none unless a
// package adds it, and Mossgrove adds none, so all five apps and every screenshot look the same.
const _light = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF2E5E55),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFCBE7DF),
  onPrimaryContainer: Color(0xFF0B2B25),
  secondary: Color(0xFF4F615C),
  onSecondary: Color(0xFFFFFFFF),
  secondaryContainer: Color(0xFFD2E5DF),
  onSecondaryContainer: Color(0xFF0C1F1B),
  tertiary: Color(0xFF7A5A1C),
  onTertiary: Color(0xFFFFFFFF),
  tertiaryContainer: Color(0xFFFCDFA6),
  onTertiaryContainer: Color(0xFF271900),
  error: Color(0xFFBA1A1A),
  onError: Color(0xFFFFFFFF),
  errorContainer: Color(0xFFFFDAD6),
  onErrorContainer: Color(0xFF410002),
  surface: Color(0xFFF7F9F7),
  onSurface: Color(0xFF181C1B),
  surfaceContainerHighest: Color(0xFFE0E3E1),
  onSurfaceVariant: Color(0xFF3F4946),
  outline: Color(0xFF6F7976),
  outlineVariant: Color(0xFFBFC9C5),
  surfaceContainerLowest: Color(0xFFFFFFFF),
  surfaceContainerLow: Color(0xFFF1F4F2),
  surfaceContainer: Color(0xFFEBEFEC),
  surfaceContainerHigh: Color(0xFFE5E9E6),
  inverseSurface: Color(0xFF2D3130),
  onInverseSurface: Color(0xFFEFF1EF),
  inversePrimary: Color(0xFF95D1C2),
  surfaceTint: Color(0xFF2E5E55),
);

const _dark = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFF95D1C2),
  onPrimary: Color(0xFF003730),
  primaryContainer: Color(0xFF15493F),
  onPrimaryContainer: Color(0xFFB0EEDD),
  secondary: Color(0xFFB6CBC4),
  onSecondary: Color(0xFF21352F),
  secondaryContainer: Color(0xFF374B45),
  onSecondaryContainer: Color(0xFFD2E7E0),
  tertiary: Color(0xFFEEC06E),
  onTertiary: Color(0xFF412D00),
  tertiaryContainer: Color(0xFF5D4200),
  onTertiaryContainer: Color(0xFFFFDEA5),
  error: Color(0xFFFFB4AB),
  onError: Color(0xFF690005),
  errorContainer: Color(0xFF93000A),
  onErrorContainer: Color(0xFFFFDAD6),
  surface: Color(0xFF101413),
  onSurface: Color(0xFFE0E3E1),
  surfaceContainerHighest: Color(0xFF313635),
  onSurfaceVariant: Color(0xFFBFC9C5),
  outline: Color(0xFF899390),
  outlineVariant: Color(0xFF3F4946),
  surfaceContainerLowest: Color(0xFF0B0F0E),
  surfaceContainerLow: Color(0xFF181C1B),
  surfaceContainer: Color(0xFF1C2120),
  surfaceContainerHigh: Color(0xFF272B2A),
  inverseSurface: Color(0xFFE0E3E1),
  onInverseSurface: Color(0xFF2D3130),
  inversePrimary: Color(0xFF2E5E55),
  surfaceTint: Color(0xFF95D1C2),
);

/// One tint pair per aisle: the tile behind an item's drawing, and the drawing's ink.
@immutable
class AisleTint {
  const AisleTint(this.tile, this.ink);

  final Color tile;
  final Color ink;
}

/// The aisle tints and the item-number style, as a theme extension so light and dark switch together.
@immutable
class Mossgrove extends ThemeExtension<Mossgrove> {
  const Mossgrove({required this.kitchen, required this.desk, required this.garden, required this.home});

  final AisleTint kitchen;
  final AisleTint desk;
  final AisleTint garden;
  final AisleTint home;

  static const light = Mossgrove(
    kitchen: AisleTint(Color(0xFFDDEBE5), Color(0xFF2E5E55)),
    desk: AisleTint(Color(0xFFE2E7EE), Color(0xFF3F5466)),
    garden: AisleTint(Color(0xFFDCEBD3), Color(0xFF3E6A2E)),
    home: AisleTint(Color(0xFFE8E4DE), Color(0xFF5B5148)),
  );

  static const dark = Mossgrove(
    kitchen: AisleTint(Color(0xFF23332E), Color(0xFF95D1C2)),
    desk: AisleTint(Color(0xFF222A33), Color(0xFFB4C5D8)),
    garden: AisleTint(Color(0xFF263322), Color(0xFFA8D493)),
    home: AisleTint(Color(0xFF302D29), Color(0xFFD3C7BA)),
  );

  static Mossgrove of(BuildContext context) => Theme.of(context).extension<Mossgrove>()!;

  AisleTint aisle(Category category) => switch (category) {
    Category.kitchen => kitchen,
    Category.desk => desk,
    Category.garden => garden,
    Category.home => home,
  };

  @override
  Mossgrove copyWith() => this;

  @override
  Mossgrove lerp(Mossgrove? other, double t) => t < 0.5 ? this : (other ?? this);
}

/// The system monospace face: `monospace` on Android, Menlo on iOS. Nothing is bundled.
const monospace = 'monospace';
const monospaceFallback = ['Menlo', 'Courier'];

/// Item numbers ("No. 007") and the test account are set in the system monospace face, so the digits line up.
const itemNumberStyle = TextStyle(
  fontFamily: monospace,
  fontFamilyFallback: monospaceFallback,
  fontWeight: FontWeight.w500,
  fontSize: 13,
  letterSpacing: 0.5,
);

// Corners (SPEC.md §10): 4 for label holders and text fields, 8 for chips and drawing tiles, 12 for drawer fronts
// and pads, 28 for dialogs and sheets.
const radiusLabel = BorderRadius.all(Radius.circular(4));
const radiusTile = BorderRadius.all(Radius.circular(8));
const radiusDrawer = BorderRadius.all(Radius.circular(12));
const radiusDialog = BorderRadius.all(Radius.circular(28));

ThemeData mossgroveTheme(Brightness brightness) {
  final scheme = brightness == Brightness.light ? _light : _dark;
  final base = ThemeData(colorScheme: scheme, useMaterial3: true, brightness: brightness);
  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    extensions: [brightness == Brightness.light ? Mossgrove.light : Mossgrove.dark],
    inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder(borderRadius: radiusLabel)),
    // the title keeps Material's own style (titleLarge); only the tint on scroll is turned off
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
    ),
    dialogTheme: const DialogThemeData(shape: RoundedRectangleBorder(borderRadius: radiusDialog)),
    // full width along the bottom, as the Android app's: a bar, not a floating card
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.fixed,
      elevation: 0,
      backgroundColor: scheme.inverseSurface,
      actionTextColor: scheme.inversePrimary,
    ),
    chipTheme: base.chipTheme.copyWith(shape: const RoundedRectangleBorder(borderRadius: radiusTile)),
  );
}
