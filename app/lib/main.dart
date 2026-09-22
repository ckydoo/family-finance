import 'package:flutter/material.dart';

import 'app.dart';
import 'core/auth/auth_controller.dart';
import 'core/config/app_env.dart';
import 'core/db/app_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Server connection (see AppEnv): ignored .env asset, then dart-defines.
  // A build with no connection shows the setup screen below — it never
  // runs as anything other than the real app.
  final env = await AppEnv.load();

  // Local database (M1 persistence). Null → the device refuses local
  // storage, which the app cannot run without.
  final db = await AppDatabase.open();

  if (!env.isConfigured || db == null) {
    runApp(MhuriSetupErrorApp(reason: env.configError ?? 'Local storage is unavailable on this device.'));
    return;
  }

  // Auth (M2). Live session restore before the first frame; first run
  // starts at the login gate.
  final auth = AuthController(env: env, kvGet: db.kvGet, kvSet: db.kvSet);
  await auth.restore();

  runApp(MhuriMoneyApp(db: db, env: env, auth: auth));
}

/// Shown when a build has no Supabase connection (or the device refuses
/// local storage). Developer-facing by nature — the build is misconfigured,
/// not the user's data — so the text stays in plain English.
class MhuriSetupErrorApp extends StatelessWidget {
  const MhuriSetupErrorApp({super.key, required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0B1F1A),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.cloud_off_outlined,
                    size: 44, color: Color(0xFF7FD1B9)),
                const SizedBox(height: 18),
                const Text(
                  'Mhuri Hub — setup needed',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFEAF4F0),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  reason,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Color(0xFFA9C3BA),
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
