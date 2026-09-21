import 'package:flutter/material.dart';

import 'app.dart';
import 'core/auth/auth_controller.dart';
import 'core/config/app_env.dart';
import 'core/db/app_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Environment (.env asset — see .env.example). Missing or invalid file
  // always means: offline demo mode, exactly as the app has always behaved.
  final env = await AppEnv.load();

  // Local database (M1 persistence). Null → in-memory demo mode.
  final db = await AppDatabase.open();

  // Auth (M2). Live mode restores a stored session before the first frame;
  // demo mode never shows login at all.
  final auth = AuthController(env: env, kvGet: db?.kvGet, kvSet: db?.kvSet);
  // Demo AND live: restore a stored session (demo = kv marker; first run
  // therefore starts at the login gate, as it should).
  await auth.restore();

  runApp(MhuriMoneyApp(db: db, env: env, auth: auth));
}
