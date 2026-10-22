import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── Midnight Slate & Champagne design tokens ───────────────────────────────
// Keep brand values here so feature widgets consume semantic colors through
// [MhuriCtx] rather than carrying raw hex values of their own.
const Color kPrimary = Color(0xFF24344A); // midnight slate
const Color kPrimaryDark = Color(0xFF17283D);
const Color kPrimaryLight = Color(0xFF40556D);
const Color kPrimarySoft = Color(0xFFE7EBEF); // slate wash (containers, chips)
const Color kAccent = Color(0xFFC6A477); // champagne accent
const Color kAccentDark =
    Color(0xFFA77E42); // accessible accent on light surfaces
const Color kAccentSoft = Color(0xFFF4EDE3); // champagne wash
const Color kBg = Color(0xFFF5F3EE); // warm off-white background
const Color kCard = Color(0xFFFFFFFF); // card surface
const Color kSurfaceSecondary = Color(0xFFEEEAE3);
const Color kInk = Color(0xFF20272D); // primary text
// One step darker than the reference #68717B so normal text clears WCAG 4.5:1
// against the warm background rather than rounding just below the threshold.
const Color kInkSoft = Color(0xFF66707A); // secondary text
const Color kInkFaint = Color(0xFF66707A); // captions
const Color kDanger = Color(0xFFB65C58);
const Color kDangerSoft = Color(0xFFF7E8E6);
const Color kIncomeGreen = Color(0xFF397866);
// Text/icon red is deliberately deeper than the danger fill token so it is
// readable on the soft danger surface at normal text sizes.
const Color kExpenseRed = Color(0xFFA34A47);
const Color kWarning = Color(0xFFB47C36);
const Color kInformation = Color(0xFF557C9C);
const Color kTrack = kSurfaceSecondary;
const Color kHairline = Color(0xFFE4E2DD);
const Color kShadow = Color(0x1420272D); // 8% ink - soft elevation

// Kids Mode keeps its playful geometry, but shares the core brand palette.
const Color kKidBg = kBg;
const Color kKidCoral = kDanger;
const Color kKidSky = kInformation;
const Color kKidCard = kCard;
const Color kKidInk = kInk;
const Color kKidAccentSoft = kAccentSoft;
const Color kKidBorder = kHairline;
const Color kDarkInkSoft = Color(0xFFC7D2DF);

/// App-wide font family (bundled - see pubspec + assets/fonts/poppins/OFL.txt).
const String kFontFamily = 'Poppins';

/// ── Named type ramp (G8) ───────────────────────────────────────────────────
/// Use for new surfaces: display → hero amounts, titleL/M → headings,
/// body → primary copy, caption → meta text. Legacy ad-hoc styles migrate
/// opportunistically (hero already uses display).
class MhuriType {
  static const display = TextStyle(
    fontFamily: kFontFamily,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.1,
  );
  static const titleL = TextStyle(
    fontFamily: kFontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
  );
  static const titleM = TextStyle(
    fontFamily: kFontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w600,
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
const double kRadiusXS = 6;
const double kRadiusS = 8;
const double kRadiusM = 10;
const double kRadiusL = 12;
const double kRadiusSheet = 20;

/// Standard spacing scale (4, 8, 12, 16, 24, 32, 48)
const double kSpace4 = 4;
const double kSpace8 = 8;
const double kSpace12 = 12;
const double kSpace16 = 16;
const double kSpace24 = 24;
const double kSpace32 = 32;
const double kSpace48 = 48;

/// Motion durations
const Duration kMotionFast = Duration(milliseconds: 150);
const Duration kMotion = Duration(milliseconds: 220);

/// Responsive page gutters used by every full-screen, scrollable surface.
/// SafeArea supplies the device inset; these values supply the visual breathing
/// room after it, so headers never sit against a notch or status bar.
const EdgeInsets kPageInsets = EdgeInsets.fromLTRB(20, 24, 20, 32);
const EdgeInsets kWidePageInsets = EdgeInsets.fromLTRB(24, 24, 24, 32);

/// Extra clearance for tab pages beneath the center-docked action button.
const EdgeInsets kTabPageInsets = EdgeInsets.fromLTRB(20, 24, 20, 88);

/// Design-system radius helpers.
final BorderRadius kBRadiusXS = BorderRadius.circular(kRadiusXS);
final BorderRadius kBRadiusS = BorderRadius.circular(kRadiusS);
final BorderRadius kBRadiusM = BorderRadius.circular(kRadiusM);
final BorderRadius kBRadiusL = BorderRadius.circular(kRadiusL);

/// Ordinary content surfaces are separated by tone and borders, not shadow.
const List<BoxShadow> kCardShadow = [];

/// ── Dark-mode palette ──────────────────────────────────────────────────────
/// One object, two instances: every screen reads colors through [MhuriCtx]
/// so light/dark swap is automatic (G1).
class MhuriColors {
  final Color bg, card, surfaceSecondary, ink, inkSoft, inkFaint, hairline;
  final Color primary, primaryDark, primaryLight, primarySoft;
  final Color accent, accentDark, accentSoft, danger, dangerSoft;
  final Color warning, information;
  final Color successSoft, warningSoft, infoSoft, violetSoft;
  final Color incomeGreen, expenseRed, track, shadowColor, onSolid;
  final List<BoxShadow> cardShadow;

  const MhuriColors({
    required this.bg,
    required this.card,
    required this.surfaceSecondary,
    required this.ink,
    required this.inkSoft,
    required this.inkFaint,
    required this.hairline,
    required this.primary,
    required this.primaryDark,
    required this.primaryLight,
    required this.primarySoft,
    required this.accent,
    required this.accentDark,
    required this.accentSoft,
    required this.danger,
    required this.dangerSoft,
    required this.warning,
    required this.information,
    required this.successSoft,
    required this.warningSoft,
    required this.infoSoft,
    required this.violetSoft,
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
    surfaceSecondary: kSurfaceSecondary,
    ink: kInk,
    inkSoft: kInkSoft,
    inkFaint: kInkFaint,
    hairline: kHairline,
    primary: kPrimary,
    primaryDark: kPrimaryDark,
    primaryLight: kPrimaryLight,
    primarySoft: kPrimarySoft,
    accent: kAccent,
    accentDark: kAccentDark,
    accentSoft: kAccentSoft,
    danger: kDanger,
    dangerSoft: kDangerSoft,
    warning: kWarning,
    information: kInformation,
    successSoft: Color(0xFFD9EDE8),
    warningSoft: Color(0xFFF7EBD9),
    infoSoft: Color(0xFFE6EEF4),
    violetSoft: Color(0xFFEFE3F7),
    incomeGreen: kIncomeGreen,
    expenseRed: kExpenseRed,
    track: kTrack,
    shadowColor: kShadow,
    onSolid: Colors.white,
    cardShadow: kCardShadow,
  );

  static const dark = MhuriColors(
    bg: Color(0xFF101722),
    card: Color(0xFF192333),
    surfaceSecondary: Color(0xFF222E3E),
    ink: Color(0xFFF3F1EC),
    inkSoft: Color(0xFFB5BDC7),
    inkFaint: Color(0xFF9AA5B2),
    hairline: Color(0xFF2D3A4C),
    primary: Color(0xFFC7D2DF),
    primaryDark: Color(0xFFE4EBF2),
    primaryLight: Color(0xFF9BAEC2),
    primarySoft: Color(0xFF26364A),
    accent: Color(0xFFD5B98F),
    accentDark: Color(0xFFE7C99B),
    accentSoft: Color(0xFF3A3024),
    danger: Color(0xFFE28B86),
    dangerSoft: Color(0xFF402827),
    warning: Color(0xFFD7A55F),
    information: Color(0xFF83A9C7),
    successSoft: Color(0xFF203B35),
    warningSoft: Color(0xFF3D3223),
    infoSoft: Color(0xFF243747),
    violetSoft: Color(0xFF342E40),
    incomeGreen: Color(0xFF72B29E),
    expenseRed: Color(0xFFE28B86),
    track: Color(0xFF263243),
    shadowColor: Color(0x66000000),
    onSolid: Color(0xFF101722),
    cardShadow: [],
  );

  static MhuriColors of(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? dark : light;
}

/// Read design tokens with automatic dark mode: `context.card`, `context.ink`…
extension MhuriCtx on BuildContext {
  MhuriColors get mc => MhuriColors.of(this);
  Color get bg => mc.bg;
  Color get card => mc.card;
  Color get surfaceSecondary => mc.surfaceSecondary;
  Color get ink => mc.ink;
  Color get inkSoft => mc.inkSoft;
  Color get inkFaint => mc.inkFaint;
  Color get hairline => mc.hairline;
  Color get primary => mc.primary;
  Color get primaryDark => mc.primaryDark;
  Color get primaryLight => mc.primaryLight;
  Color get primarySoft => mc.primarySoft;
  Color get accent => mc.accent;
  Color get accentDark => mc.accentDark;
  Color get accentSoft => mc.accentSoft;
  Color get danger => mc.danger;
  Color get dangerSoft => mc.dangerSoft;
  Color get warning => mc.warning;
  Color get information => mc.information;
  Color get successSoft => mc.successSoft;
  Color get warningSoft => mc.warningSoft;
  Color get infoSoft => mc.infoSoft;
  Color get violetSoft => mc.violetSoft;
  Color get incomeGreen => mc.incomeGreen;
  Color get expenseRed => mc.expenseRed;
  Color get track => mc.track;
  Color get shadowColor => mc.shadowColor;
  List<BoxShadow> get cardShadow => mc.cardShadow;
  Color get onSolid => mc.onSolid;
}

ThemeData _buildTheme(MhuriColors p, Brightness brightness) {
  final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
  final seededScheme =
      ColorScheme.fromSeed(seedColor: p.primary, brightness: brightness);
  final isDark = brightness == Brightness.dark;
  final scheme = seededScheme.copyWith(
    primary: p.primary,
    onPrimary: p.onSolid,
    primaryContainer: p.primarySoft,
    onPrimaryContainer: p.primaryDark,
    secondary: p.accent,
    // The dark palette's ink is near-white, so it disappears on the light
    // champagne accent. Keep the established light-mode pairing unchanged.
    onSecondary: brightness == Brightness.dark ? p.onSolid : p.ink,
    secondaryContainer: p.accentSoft,
    onSecondaryContainer: p.ink,
    error: p.danger,
    onError: p.onSolid,
    errorContainer: p.dangerSoft,
    onErrorContainer: p.expenseRed,
    surface: p.card,
    // Material 3 components also consume the container tiers directly. In
    // dark mode, pin them to our palette instead of accepting seed-generated
    // greys; retain every generated light-mode value exactly as before.
    surfaceDim: isDark ? p.bg : seededScheme.surfaceDim,
    surfaceBright: isDark ? p.surfaceSecondary : seededScheme.surfaceBright,
    surfaceContainerLowest: isDark ? p.bg : seededScheme.surfaceContainerLowest,
    surfaceContainerLow: isDark ? p.card : seededScheme.surfaceContainerLow,
    surfaceContainer: isDark ? p.card : seededScheme.surfaceContainer,
    surfaceContainerHigh:
        isDark ? p.surfaceSecondary : seededScheme.surfaceContainerHigh,
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
    splashFactory: isIOS ? NoSplash.splashFactory : InkSparkle.splashFactory,
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
      centerTitle: isIOS || defaultTargetPlatform == TargetPlatform.macOS,
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
        shape: RoundedRectangleBorder(borderRadius: kBRadiusM),
        textStyle: const TextStyle(
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
        shape: RoundedRectangleBorder(borderRadius: kBRadiusM),
        textStyle: const TextStyle(
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
        shape: RoundedRectangleBorder(borderRadius: kBRadiusS),
        textStyle: const TextStyle(
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
        shape: RoundedRectangleBorder(borderRadius: kBRadiusM),
        textStyle: const TextStyle(
          fontFamily: kFontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: p.ink,
        highlightColor: isIOS ? Colors.transparent : p.primarySoft,
        splashFactory:
            isIOS ? NoSplash.splashFactory : InkSparkle.splashFactory,
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
      shape: const RoundedRectangleBorder(
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
    badgeTheme: BadgeThemeData(
      backgroundColor: p.accentDark,
      // White is retained in light mode; dark mode needs dark ink against its
      // deliberately brighter champagne badge surface.
      textColor: brightness == Brightness.dark ? p.onSolid : Colors.white,
      smallSize: 8,
      largeSize: 22,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: const AlignmentDirectional(12, -11),
      textStyle: const TextStyle(
        fontFamily: kFontFamily,
        fontSize: 10,
        height: 1,
        fontWeight: FontWeight.w700,
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
      foregroundColor: p.onSolid,
      elevation: 2,
      focusElevation: 3,
      highlightElevation: 3,
      shape: const CircleBorder(),
    ),
    bottomAppBarTheme: BottomAppBarThemeData(
      color: p.card,
      elevation: 0,
      height: 64,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.card,
      indicatorColor: Colors.transparent,
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

    cupertinoOverrideTheme: CupertinoThemeData(
      primaryColor: p.primary,
      barBackgroundColor: p.bg,
      scaffoldBackgroundColor: p.bg,
      brightness: brightness,
      textTheme: CupertinoTextThemeData(
        primaryColor: p.ink,
        textStyle: TextStyle(fontFamily: kFontFamily, color: p.ink),
      ),
    ),

    // ── Motion ────────────────────────────────────────────────────────────
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
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
