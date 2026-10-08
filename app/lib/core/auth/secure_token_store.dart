import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../db/app_database.dart';

/// Stores Supabase session credentials in Keychain/Android encrypted storage.
///
/// Existing SQLite credentials are migrated once and immediately erased so
/// upgrades do not silently sign users out or leave reusable tokens behind.
class SecureTokenStore {
  SecureTokenStore({
    FlutterSecureStorage? storage,
    this.legacyDatabase,
  }) : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                  accessibility:
                      KeychainAccessibility.first_unlock_this_device),
            );

  static const Set<String> tokenKeys = {
    'auth_access_token',
    'auth_refresh_token',
  };

  final FlutterSecureStorage _storage;
  final AppDatabase? legacyDatabase;

  Future<void> migrateLegacyTokens() async {
    final database = legacyDatabase;
    if (database == null) return;
    for (final key in tokenKeys) {
      final secureValue = await _storage.read(key: key);
      final legacyValue = await database.kvGet(key);
      if ((secureValue == null || secureValue.isEmpty) &&
          legacyValue != null &&
          legacyValue.isNotEmpty) {
        await _storage.write(key: key, value: legacyValue);
      }
      if (legacyValue != null) await database.kvDelete(key);
    }
  }

  Future<String?> get(String key) async {
    if (!tokenKeys.contains(key)) return legacyDatabase?.kvGet(key);
    return _storage.read(key: key);
  }

  Future<void> set(String key, String value) async {
    if (!tokenKeys.contains(key)) {
      await legacyDatabase?.kvSet(key, value);
      return;
    }
    if (value.isEmpty) {
      await _storage.delete(key: key);
    } else {
      await _storage.write(key: key, value: value);
    }
  }
}
