import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'app.dart';
import 'core/auth/auth_controller.dart';
import 'core/auth/secure_token_store.dart';
import 'core/config/app_env.dart';
import 'core/db/app_database.dart';
import 'core/firebase/firebase_services.dart';
import 'core/theme/app_theme.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) =>
    FirebaseServices.handleBackgroundMessage(message);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await FirebaseServices.initialize(
    backgroundHandler: firebaseMessagingBackgroundHandler,
  );

  // Server connection (see AppEnv): dart-defines > .env asset > constants.
  // A build with no connection shows the setup screen below - it never
  // runs as anything other than the real app.
  final env = await AppEnv.load();

  // Local database (M1 persistence). Null → the device refuses local
  // storage, which the app cannot run without.
  final db = await AppDatabase.open();

  if (!env.isConfigured || db == null) {
    debugPrint('Mhuri startup unavailable: '
        '${env.configError ?? 'Local database could not be opened.'}');
    runApp(const MhuriSetupErrorApp());
    return;
  }

  // Auth (M2). Start session restore before the first frame, but never hold
  // Flutter's UI behind a network refresh. Cached users enter immediately;
  // the server check completes in the background.
  final tokenStore = SecureTokenStore(legacyDatabase: db);
  await tokenStore.migrateLegacyTokens();
  final auth = AuthController(
    env: env,
    kvGet: tokenStore.get,
    kvSet: tokenStore.set,
  );
  runApp(MhuriMoneyApp(db: db, env: env, auth: auth));
  unawaited(auth.restore());
}

/// Shown when the app cannot safely start. Technical detail is logged, never
/// displayed to the user.
class MhuriSetupErrorApp extends StatelessWidget {
  const MhuriSetupErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppDarkTheme(),
      home: const Scaffold(
        backgroundColor: kPrimaryDark,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.cloud_off_outlined, size: 44, color: kAccent),
                SizedBox(height: 18),
                Text(
                  'Mhuri could not start',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Please close and reopen the app. If this keeps happening, update or reinstall Mhuri and try again.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: kDarkInkSoft,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
