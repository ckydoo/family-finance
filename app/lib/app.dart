import 'dart:async';
import 'package:flutter/material.dart';

import 'core/auth/auth_controller.dart';
import 'core/config/app_env.dart';
import 'core/db/app_database.dart';
import 'core/l10n/localization_delegates.dart';
import 'core/notifications/notifier.dart';
import 'l10n/generated/app_localizations.dart';
import 'core/db/persistence.dart';
import 'core/models/models.dart' show Role;
import 'core/state/app_state.dart';
import 'core/sync/supabase_sync_client.dart';
import 'core/sync/sync_engine.dart';
import 'core/observability/reporter.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/motion.dart';
import 'core/money/money.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/reset_password_screen.dart';
import 'features/kids/kids_mode.dart';
import 'features/onboarding/family_setup_screen.dart';
import 'features/shell/adult_shell.dart';
import 'features/teen/teen_zone.dart';

/// Root widget. Owns the [AppState] and [AuthController] and exposes state to
/// the whole tree via [AppScope]. Production (main) always passes a working
/// local database + configured env; widget tests may pass nothing (an empty
/// unconfigured app — no sync, no fixtures).
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
  late final bool _configured;
  SyncEngine? _engine;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final env = widget.env ?? const AppEnv();
    _configured = env.isConfigured;
    _auth = widget.auth ?? AuthController(env: env);
    _state = AppState(db: widget.db, env: env, auth: _auth);

    // #1 recovery + invite deep links, and the resume-your-reset banner.
    // Fire-and-forget: they only subscribe listeners / read local kv.
    unawaited(_initRecoveryLinks());
    unawaited(_checkPendingReset());

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

    // M3: configured connection + local database → real two-phone sync.
    final db = widget.db;
    final url = env.supabaseUrl;
    final key = env.supabaseAnonKey;
    if (_configured && db != null && (url?.isNotEmpty ?? false)) {
      final engine = SyncEngine(
        client: SupabaseSyncClient(
          baseUrl: url!,
          anonKey: key ?? '',
          tokenGet: () async {
            final t = await db.kvGet('auth_access_token');
            if (t != null && t.isNotEmpty) return t;
            // Self-heal a wiped/expired access token from the refresh token.
            return _auth.refreshAccessToken();
          },
        ),
        database: db.raw,
        persistence: Persistence(db),
        state: _state,
        kvGet: db.kvGet,
        kvSet: db.kvSet,
        // 401 mid-session → force one token refresh, retry once (#8).
        retryAuth: () async => await _auth.refreshAccessToken() != null,
      );
      // Phase 4 #19: one observability seam — errors AND sync-health
      // events flow through the active reporter. Swapping in Sentry or
      // Crashlytics later = implement MhuriReporter, assign activeReporter
      // here. Never log secrets/amounts (enforced in reporter.dart).
      activeReporter = const DebugReporter();
      SyncEngine.reportError =
          (where, err, st) => activeReporter?.error(where, err, st);
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
    if (state == AppLifecycleState.resumed && _configured && _auth.isLoggedIn) {
      _engine?.syncNow();
      _state.refreshPending();
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    _engine?.dispose();
    _state.dispose();
    _auth.dispose();
    super.dispose();
  }

  // ── password recovery deep links ──────────────────────────────────────────

  Future<void> _initRecoveryLinks() async {
    try {
      final links = AppLinks();
      _linkSub = links.uriLinkStream.listen(_onRecoveryLink);
      final initial = await links.getInitialLink();
      if (initial != null) _onRecoveryLink(initial);
    } catch (_) {
      // Deep links unavailable (unsupported platform/plugin) — password
      // recovery still works through the ordinary sign-in path.
    }
  }

  Future<void> _onRecoveryLink(Uri uri) async {
    // Join links (QR / WhatsApp share): mhuri://join?c=MHRI-XXXXXX
    final inviteCode = parseInviteCode(uri.toString());
    if (inviteCode != null) {
      final db = widget.db;
      if (db != null) await db.kvSet('pending_invite_code', inviteCode);
      final ctx = _navKey.currentContext;
      if (ctx != null && mounted) {
        if (!_auth.isLoggedIn || !_state.onboardingComplete) {
          // Login / family setup will pick the code up from kv.
          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
            content:
                Text(AppLocalizations.of(ctx)!.inviteLinkReady(inviteCode)),
            behavior: SnackBarBehavior.floating,
          ));
        } else {
          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
            content: Text(AppLocalizations.of(ctx)!.inviteAlreadyInFamily),
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
      return;
    }

    final link = parseRecoveryLink(uri.toString());
    if (!link.isRecovery) return; // some other deep link — not ours
    final ctx = _navKey.currentContext;
    if (ctx == null || !mounted) return;
    final navigator = Navigator.of(ctx);
    if (link.kind == RecoveryKind.tokens) {
      final ok = await _auth.adoptRecoverySession(
          link.accessToken!, link.refreshToken!);
      if (!mounted) return;
      // A broken token still gets a screen — the expired state with a
      // "send a new link" action, never a dead end.
      navigator.push(MaterialPageRoute<void>(
        builder: (_) => ok
            ? ResetPasswordScreen(auth: _auth, email: _auth.session?.email)
            : _ResetExpired(_auth),
      ));
    } else {
      // PKCE-style (?code=) link — cannot be exchanged by this client.
      navigator.push(
          MaterialPageRoute<void>(builder: (_) => _ResetExpired(_auth)));
    }
  }

  /// Closed the app between the reset link and picking a new password?
  /// Resume straight into the reset screen instead of dropping the user in.
  Future<void> _checkPendingReset() async {
    final db = widget.db;
    if (db == null) return;
    try {
      final flag = await db.kvGet('pw_reset_pending');
      final email = await db.kvGet('auth_email');
      if ((flag ?? '').isNotEmpty && _auth.isLoggedIn) {
        if (!mounted) return;
        setState(() {
          _resumeReset = true;
          _pendingResetEmail = (email ?? '').isEmpty ? null : email;
        });
      }
    } catch (_) {}
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
            title: 'Mhuri Hub',
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
            locale:
                _state.localeCode.isEmpty ? null : Locale(_state.localeCode),
            localizationsDelegates: mhuriLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            // Elder mode (J6): scale every screen's text.
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(_state.largeText ? 1.2 : 1.0)),
              child: child ?? const SizedBox.shrink(),
            ),
            home: AnimatedBuilder(
              animation: _auth,
              builder: (context, _) {
                // Hydration splash: local database is loading.
                if (_state.hydrating) {
                  return const _Splash();
                }
                // Interface pass 3: a designed failure path, not a white screen.
                if (_state.lastError != null) {
                  return _ErrorPane(onRetry: () => _state.refresh());
                }
                // First run starts at Authentication. After verifying once,
                // launches go straight in via the restored session.
                if (!_auth.isLoggedIn) {
                  return LoginScreen(auth: _auth);
                }
                // Closed the app mid-recovery? Finish choosing the new
                // password before anything else.
                if (_resumeReset) {
                  return ResetPasswordScreen(
                      auth: _auth, email: _pendingResetEmail);
                }
                // First-run family setup (skip writes kv): create a family
                // or join one — that IS the onboarding.
                if (_auth.isLoggedIn && !_state.onboardingComplete) {
                  return FamilySetupScreen(state: _state);
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

class _SplashState extends State<_Splash> with SingleTickerProviderStateMixin {
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
              'Mhuri Hub',
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

/// The reset link is dead (single-use already used, expired, or PKCE-style):
/// show the honest expired state with a "send a new link" action.
class _ResetExpired extends StatelessWidget {
  const _ResetExpired();

  @override
  Widget build(BuildContext context) {
    final auth = AppScope.of(context).auth;
    return ResetPasswordScreen(auth: auth, startExpired: true);
  }
}
