import 'package:flutter/material.dart';

import 'core/auth/auth_controller.dart';
import 'core/config/app_env.dart';
import 'core/db/app_database.dart';
import 'core/notifications/notifier.dart';
import 'l10n/generated/app_localizations.dart';
import 'core/db/persistence.dart';
import 'core/models/models.dart' show Role;
import 'core/state/app_state.dart';
import 'core/sync/supabase_sync_client.dart';
import 'core/sync/sync_engine.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/motion.dart';
import 'core/money/money.dart';
import 'features/auth/login_screen.dart';
import 'features/kids/kids_mode.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/shell/adult_shell.dart';
import 'features/teen/teen_zone.dart';

/// Root widget. Owns the [AppState] and [AuthController] and exposes state to
/// the whole tree via [AppScope]. All parameters optional: `flutter test` and
/// demo builds pass nothing and get the classic offline demo experience.
class MhuriMoneyApp extends StatefulWidget {
  const MhuriMoneyApp({super.key, this.db, this.env, this.auth});

  final AppDatabase? db;
  final AppEnv? env;
  final AuthController? auth;

  @override
  State<MhuriMoneyApp> createState() => _MhuriMoneyAppState();
}

class _MhuriMoneyAppState extends State<MhuriMoneyApp>
    with WidgetsBindingObserver {
  late final AppState _state;
  late final AuthController _auth;
  late final bool _live;
  SyncEngine? _engine;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final env = widget.env ?? const AppEnv.fallback();
    _live = env.isLive;
    _auth = widget.auth ?? AuthController(env: env);
    _state = AppState(db: widget.db, env: env, auth: _auth);

    // M5: bridge reminder plans to the OS notification scheduler.
    var permissionAsked = false;
    _state.reminderHook = (plan) {
      if (plan.isNotEmpty && !permissionAsked) {
        permissionAsked = true;
        Notifier.requestPermission().then((_) => Notifier.apply(plan));
        return;
      }
      Notifier.apply(plan);
    };

    // M3: live mode + local database → real two-phone sync.
    final db = widget.db;
    final url = env.supabaseUrl;
    final key = env.supabaseAnonKey;
    if (_live && db != null && (url?.isNotEmpty ?? false)) {
      final engine = SyncEngine(
        client: SupabaseSyncClient(
          baseUrl: url!,
          anonKey: key ?? '',
          tokenGet: () => db.kvGet('auth_access_token'),
        ),
        database: db.raw,
        persistence: Persistence(db),
        state: _state,
        kvGet: db.kvGet,
        kvSet: db.kvSet,
      );
      // M7: pluggable error reporting — point at Sentry/Crashlytics later
      // (optional SENTRY_DSN env stays post-8).
      SyncEngine.reportError = (where, err, st) {
        debugPrint('Mhuri sync[$where]: $err');
      };
      _state.attachSync(engine);
      _engine = engine;
      engine.start();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // G5: left the foreground → hide balances (Monzo-style privacy).
    // The user reveals them again with the eye on the pool card.
    if ((state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden) &&
        !_state.hideAmounts &&
        _state.autoHideAmounts) {
      _state.setHideAmounts(true);
    }
    // Premium pass: back in the foreground → pull the family's changes now
    // (narrows the 45s poll window to ~0 for the "just opened the app" case).
    if (state == AppLifecycleState.resumed && _live && _auth.isLoggedIn) {
      _engine?.syncNow();
      _state.refreshPending();
    }
  }

  @override
  void dispose() {
    _engine?.dispose();
    _state.dispose();
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      notifier: _state,
      child: AnimatedBuilder(
        animation: _state,
        builder: (context, _) {
        // G7: money grouping follows the app locale (es/fr/pt via intl).
        Money.localeTag = _state.localeCode;
        return MaterialApp(
        title: 'Mhuri Money',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        darkTheme: buildAppDarkTheme(),
        // G1: system-following dark mode with manual override.
        themeMode: _state.themeMode == 1
            ? ThemeMode.light
            : _state.themeMode == 2
                ? ThemeMode.dark
                : ThemeMode.system,
        // M6 international: 6 languages, system-aware, user-overridable.
        locale: _state.localeCode.isEmpty ? null : Locale(_state.localeCode),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // Elder mode (J6): scale every screen's text.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(_state.largeText ? 1.2 : 1.0)),
          child: child ?? const SizedBox.shrink(),
        ),
        home: AnimatedBuilder(
          animation: _auth,
          builder: (context, _) {
            // Hydration splash: local database is loading (demo boots fast).
            if (_state.hydrating) {
              return const _Splash();
            }
            // Interface pass 3: a designed failure path, not a white screen.
            if (_state.lastError != null) {
              return _ErrorPane(onRetry: () => _state.refresh());
            }
            // First run starts at Authentication in BOTH modes (demo login
            // = any phone + code 1234). After verifying once, launches go
            // straight in via the restored session.
            if (!_auth.isLoggedIn) {
              return LoginScreen(auth: _auth);
            }
            // First-run onboarding (live mode only; skip writes kv).
            if (_live && _auth.isLoggedIn && !_state.onboardingComplete) {
              return OnboardingScreen(state: _state);
            }
            return const RoleGate();
          },
        ),
        );
        },
      ),
    );
  }
}

/// Minimal branded splash while the local database hydrates.
class _Splash extends StatefulWidget {
  const _Splash();

  @override
  State<_Splash> createState() => _SplashState();
}

class _SplashState extends State<_Splash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logo = Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: context.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Image.asset(
          'assets/branding/splash.png',
          width: 92,
          height: 92,
          fit: BoxFit.cover,
        ),
      ),
    );
    return Scaffold(
      backgroundColor: context.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MediaQuery.disableAnimationsOf(context)
                ? logo
                : AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, _) => Transform.scale(
                      scale: 1 + _pulse.value * 0.045,
                      child: logo,
                    ),
                  ),
            const SizedBox(height: 22),
            Text(
              'Mhuri Money',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: context.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'One family · one plan',
              style: TextStyle(fontSize: 12.5, color: context.inkSoft),
            ),
            const SizedBox(height: 30),
            // Skeleton bars instead of a spinner: the shape of what loads.
            const Column(
              children: [
                Skeleton(width: 200),
                SizedBox(height: 10),
                Skeleton(width: 156),
                SizedBox(height: 10),
                Skeleton(width: 112),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Hydration failed (corrupt db, storage full…). Offers a real retry.
class _ErrorPane extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorPane({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined, size: 44, color: context.inkFaint),
              const SizedBox(height: 16),
              Text(
                'Something went wrong loading your family data.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: context.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your data stays safe on this device — try again.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: context.inkSoft),
              ),
              const SizedBox(height: 22),
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.primary,
                  foregroundColor: context.onSolid,
                  shape: const StadiumBorder(),
                ),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Routes to the right shell based on the signed-in member's role.
/// Kids get the sealed, playful Kids Mode; teens get the Teen Zone —
/// never the full adult app.
class RoleGate extends StatelessWidget {
  const RoleGate({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return switch (s.user.role) {
      Role.kid => const KidsMode(),
      Role.teen => const TeenZone(),
      _ => const AdultShell(),
    };
  }
}
