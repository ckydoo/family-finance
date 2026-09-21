import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── Design tokens (see PRODUCT_SPEC.md §6.3) ────────────────────────────────
const Color kPrimary = Color(0xFF0E7C66); // deep teal — trust/growth
const Color kPrimaryDark = Color(0xFF0A5A4B);
const Color kPrimarySoft = Color(0xFFE3F0EC); // teal wash (containers, chips)
const Color kAccent = Color(0xFFF4A81D); // warm amber — action
const Color kAccentSoft = Color(0xFFFCF1DC); // amber wash
const Color kBg = Color(0xFFF6F5F1); // off-white background
const Color kCard = Color(0xFFFFFFFF); // card surface
const Color kInk = Color(0xFF17251F); // primary text (teal-tinted ink)
const Color kInkSoft = Color(0xFF5D6A64); // secondary text (WCAG 5.5 on kBg)
const Color kInkFaint = Color(0xFF67736E); // captions (WCAG 4.5 on kBg)
const Color kDanger = Color(0xFFD9534F); // kind danger
const Color kDangerSoft = Color(0xFFFBE9E8);
const Color kIncomeGreen = Color(0xFF1B8A5A);
const Color kExpenseRed = Color(0xFFB3423E);
const Color kTrack = Color(0xFFECEAE4); // progress track
const Color kHairline = Color(0xFFE8E6DF); // soft borders/dividers
const Color kShadow = Color(0x1417251F); // 8% ink — soft elevation

// Kids Mode palette
const Color kKidBg = Color(0xFFFFC93C); // sunny yellow
const Color kKidCoral = Color(0xFFFF6B6B);
const Color kKidSky = Color(0xFF7EC8F2);
const Color kKidCard = Color(0xFFFFFDF4);
const Color kKidInk = Color(0xFF5B3A00);

/// App-wide font family (bundled — see pubspec + assets/fonts/poppins/OFL.txt).
const String kFontFamily = 'Poppins';

/// ── Named type ramp (G8) ───────────────────────────────────────────────────
/// Use for new surfaces: display → hero amounts, titleL/M → headings,
/// body → primary copy, caption → meta text. Legacy ad-hoc styles migrate
/// opportunistically (hero already uses display).
class MhuriType {
  static const display = TextStyle(
    fontFamily: kFontFamily,
    fontSize: 26,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    height: 1.1,
  );
  static const titleL = TextStyle(
    fontFamily: kFontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
  );
  static const titleM = TextStyle(
    fontFamily: kFontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w700,
  );
  static const body = TextStyle(
    fontFamily: kFontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.45,
  );
  static const caption = TextStyle(
    fontFamily: kFontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );
}

/// The one radius ruler: everything circles back to these.
const double kRadiusS = 12;
const double kRadiusM = 18;
const double kRadiusL = 24;
const double kRadiusSheet = 28;

/// Design-system radius helpers.
final BorderRadius kBRadiusS = BorderRadius.circular(kRadiusS);
final BorderRadius kBRadiusM = BorderRadius.circular(kRadiusM);
final BorderRadius kBRadiusL = BorderRadius.circular(kRadiusL);

/// Soft card shadow used across screens (subtle, never heavy).
const List<BoxShadow> kCardShadow = [
  BoxShadow(color: kShadow, blurRadius: 18, offset: Offset(0, 6)),
];

/// ── Dark-mode palette ──────────────────────────────────────────────────────
/// One object, two instances: every screen reads colors through [MhuriCtx]
/// so light/dark swap is automatic (G1).
class MhuriColors {
  final Color bg, card, ink, inkSoft, inkFaint, hairline;
  final Color primary, primaryDark, primarySoft;
  final Color accent, accentSoft, danger, dangerSoft;
  final Color incomeGreen, expenseRed, track, shadowColor, onSolid;
  final List<BoxShadow> cardShadow;

  const MhuriColors({
    required this.bg,
    required this.card,
    required this.ink,
    required this.inkSoft,
    required this.inkFaint,
    required this.hairline,
    required this.primary,
    required this.primaryDark,
    required this.primarySoft,
    required this.accent,
    required this.accentSoft,
    required this.danger,
    required this.dangerSoft,
    required this.incomeGreen,
    required this.expenseRed,
    required this.track,
    required this.shadowColor,
    required this.onSolid,
    required this.cardShadow,
  });

  static const light = MhuriColors(
    bg: kBg,
    card: kCard,
    ink: kInk,
    inkSoft: kInkSoft,
    inkFaint: kInkFaint,
    hairline: kHairline,
    primary: kPrimary,
    primaryDark: kPrimaryDark,
    primarySoft: kPrimarySoft,
    accent: kAccent,
    accentSoft: kAccentSoft,
    danger: kDanger,
    dangerSoft: kDangerSoft,
    incomeGreen: kIncomeGreen,
    expenseRed: kExpenseRed,
    track: kTrack,
    shadowColor: kShadow,
    onSolid: Colors.white,
    cardShadow: kCardShadow,
  );

  static const dark = MhuriColors(
    bg: Color(0xFF0D1512),
    card: Color(0xFF17211C),
    ink: Color(0xFFE9F0EB),
    inkSoft: Color(0xFFA3B2AB),
    inkFaint: Color(0xFF7C8B84),
    hairline: Color(0xFF26332D),
    primary: Color(0xFF2FB89A),
    primaryDark: Color(0xFF6FDCC4),
    primarySoft: Color(0xFF12312A),
    accent: Color(0xFFF4B84A),
    accentSoft: Color(0xFF332A12),
    danger: Color(0xFFE8796F),
    dangerSoft: Color(0xFF3A211E),
    incomeGreen: Color(0xFF46C983),
    expenseRed: Color(0xFFE4796F),
    track: Color(0xFF223029),
    shadowColor: Color(0x66000000),
    onSolid: Color(0xFF0C1411),
    cardShadow: [
      BoxShadow(color: Color(0x66000000), blurRadius: 18, offset: Offset(0, 6))
    ],
  );

  static MhuriColors of(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? dark : light;
}

/// Read design tokens with automatic dark mode: `context.card`, `context.ink`…
extension MhuriCtx on BuildContext {
  MhuriColors get mc => MhuriColors.of(this);
  Color get bg => mc.bg;
  Color get card => mc.card;
  Color get ink => mc.ink;
  Color get inkSoft => mc.inkSoft;
  Color get inkFaint => mc.inkFaint;
  Color get hairline => mc.hairline;
  Color get primary => mc.primary;
  Color get primaryDark => mc.primaryDark;
  Color get primarySoft => mc.primarySoft;
  Color get accent => mc.accent;
  Color get accentSoft => mc.accentSoft;
  Color get danger => mc.danger;
  Color get dangerSoft => mc.dangerSoft;
  Color get incomeGreen => mc.incomeGreen;
  Color get expenseRed => mc.expenseRed;
  Color get track => mc.track;
  Color get shadowColor => mc.shadowColor;
  List<BoxShadow> get cardShadow => mc.cardShadow;
  Color get onSolid => mc.onSolid;
}

ThemeData _buildTheme(MhuriColors p, Brightness brightness) {
  final scheme =
      ColorScheme.fromSeed(seedColor: p.primary, brightness: brightness)
          .copyWith(
    primary: p.primary,
    onPrimary: p.onSolid,
    primaryContainer: p.primarySoft,
    onPrimaryContainer: p.primaryDark,
    secondary: p.accent,
    onSecondary: p.ink,
    secondaryContainer: p.accentSoft,
    onSecondaryContainer: p.ink,
    error: p.danger,
    onError: p.onSolid,
    errorContainer: p.dangerSoft,
    onErrorContainer: p.expenseRed,
    surface: p.card,
    onSurface: p.ink,
    surfaceContainerHighest: p.track,
    onSurfaceVariant: p.inkSoft,
    outline: p.hairline,
    outlineVariant: p.hairline,
  );

  final base = ThemeData(
    useMaterial3: true,
    fontFamily: kFontFamily,
    scaffoldBackgroundColor: p.bg,
    colorScheme: scheme,
    visualDensity: VisualDensity.standard,
    splashFactory: InkSparkle.splashFactory,
  );

  // ── Type scale ──────────────────────────────────────────────────────────
  // Poppins carries the brand: geometric, warm, confident. Big numbers get
  // tight letter-spacing; body stays airy.
  final textTheme = base.textTheme.copyWith(
    displaySmall: base.textTheme.displaySmall?.copyWith(
      fontSize: 34,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.8,
      height: 1.12,
      color: p.ink,
    ),
    headlineMedium: base.textTheme.headlineMedium?.copyWith(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
      color: p.ink,
    ),
    titleLarge: base.textTheme.titleLarge?.copyWith(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
      color: p.ink,
    ),
    titleMedium: base.textTheme.titleMedium?.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: p.ink,
    ),
    bodyLarge: base.textTheme.bodyLarge?.copyWith(
      fontSize: 15,
      height: 1.45,
      color: p.ink,
    ),
    bodyMedium: base.textTheme.bodyMedium?.copyWith(
      fontSize: 13.5,
      height: 1.45,
      color: p.ink,
    ),
    bodySmall: base.textTheme.bodySmall?.copyWith(
      fontSize: 12,
      height: 1.4,
      color: p.inkSoft,
    ),
    labelLarge: base.textTheme.labelLarge?.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.1,
    ),
    labelMedium: base.textTheme.labelMedium?.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w600,
    ),
    labelSmall: base.textTheme.labelSmall?.copyWith(
      fontSize: 10.5,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.3,
      color: p.inkSoft,
    ),
  );

  return base.copyWith(
    textTheme: textTheme,

    // ── App bar ───────────────────────────────────────────────────────────
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg,
      // Status-bar icons always contrast the surface (light→dark icons).
      systemOverlayStyle: brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
              .copyWith(statusBarColor: Colors.transparent)
          : SystemUiOverlayStyle.dark
              .copyWith(statusBarColor: Colors.transparent),
      foregroundColor: p.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: 20,
      titleTextStyle: TextStyle(
        fontFamily: kFontFamily,
        color: p.ink,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      iconTheme: IconThemeData(color: p.ink, size: 24),
    ),

    // ── Buttons ───────────────────────────────────────────────────────────
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: p.primary,
        foregroundColor: p.onSolid,
        disabledBackgroundColor: p.track,
        disabledForegroundColor: p.inkFaint,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: const StadiumBorder(),
        textStyle: TextStyle(
          fontFamily: kFontFamily,
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.primary,
        foregroundColor: p.onSolid,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: const StadiumBorder(),
        textStyle: TextStyle(
          fontFamily: kFontFamily,
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.primary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: const StadiumBorder(),
        textStyle: TextStyle(
          fontFamily: kFontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.ink,
        side: BorderSide(color: p.hairline, width: 1.2),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: const StadiumBorder(),
        textStyle: TextStyle(
          fontFamily: kFontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: p.ink,
        highlightColor: p.primarySoft,
        splashFactory: InkSparkle.splashFactory,
      ),
    ),

    // ── Inputs ────────────────────────────────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: TextStyle(color: p.inkFaint, fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: kBRadiusM,
        borderSide: BorderSide(color: p.hairline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: kBRadiusM,
        borderSide: BorderSide(color: p.hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: kBRadiusM,
        borderSide: BorderSide(color: p.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: kBRadiusM,
        borderSide: BorderSide(color: p.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: kBRadiusM,
        borderSide: BorderSide(color: p.danger, width: 1.6),
      ),
    ),

    // ── Surfaces ──────────────────────────────────────────────────────────
    cardTheme: CardThemeData(
      color: p.card,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: kBRadiusL,
        side: BorderSide(color: p.hairline),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: kBRadiusL),
      titleTextStyle: TextStyle(
        fontFamily: kFontFamily,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: p.ink,
      ),
      contentTextStyle: TextStyle(
        fontFamily: kFontFamily,
        fontSize: 14,
        height: 1.45,
        color: p.inkSoft,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      modalElevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(kRadiusSheet)),
      ),
      showDragHandle: true,
      dragHandleColor: p.hairline,
    ),

    // ── Feedback ──────────────────────────────────────────────────────────
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.ink,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: kBRadiusM),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      contentTextStyle: TextStyle(
        fontFamily: kFontFamily,
        color: p.onSolid,
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
      ),
      actionTextColor: p.accent,
    ),

    // ── Small parts ───────────────────────────────────────────────────────
    dividerTheme: DividerThemeData(color: p.hairline, thickness: 1, space: 1),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: p.card,
      side: BorderSide(color: p.hairline),
      shape: const StadiumBorder(),
      labelStyle: TextStyle(
        fontFamily: kFontFamily,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: p.ink,
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: p.inkSoft,
      shape: RoundedRectangleBorder(borderRadius: kBRadiusM),
      titleTextStyle: TextStyle(
        fontFamily: kFontFamily,
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
        color: p.ink,
      ),
      subtitleTextStyle: TextStyle(
        fontFamily: kFontFamily,
        fontSize: 12.5,
        height: 1.35,
        color: p.inkSoft,
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? p.onSolid : p.inkFaint,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? p.primary : p.track,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: p.primary,
      linearTrackColor: p.track,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: p.accent,
      foregroundColor: p.ink,
      elevation: 3,
      focusElevation: 5,
      highlightElevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    bottomAppBarTheme: BottomAppBarThemeData(
      color: p.card,
      elevation: 0,
      height: 64,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.card,
      indicatorColor: p.primarySoft,
      elevation: 0,
      height: 66,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(
          fontFamily: kFontFamily,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: p.ink,
        ),
      ),
    ),

    // ── Motion ────────────────────────────────────────────────────────────
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.fuchsia: ZoomPageTransitionsBuilder(),
        TargetPlatform.linux: ZoomPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: ZoomPageTransitionsBuilder(),
      },
    ),
  );
}

/// Light theme (the original look).
ThemeData buildAppTheme() => _buildTheme(MhuriColors.light, Brightness.light);

/// Dark theme (G1): same structure, OLED-leaning dark surfaces.
ThemeData buildAppDarkTheme() => _buildTheme(MhuriColors.dark, Brightness.dark);
