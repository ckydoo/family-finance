import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/billing/entitlement.dart';
import 'package:mhuri_money/core/db/app_database.dart';
import 'package:mhuri_money/core/money/money.dart';
import 'package:mhuri_money/core/planning/commitments.dart';
import 'package:mhuri_money/core/state/app_state.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('Plus features require an active family entitlement and matching key',
      () {
    final state = AppState();
    expect(state.hasPlus, isFalse);
    expect(state.hasPlusFeature('advanced_insights'), isFalse);

    state.familyEntitlement = const FamilyEntitlement(
      familyId: 'family-1',
      status: EntitlementStatus.active,
      features: {'advanced_insights'},
    );
    expect(state.hasPlusFeature('advanced_insights'), isTrue);
    expect(state.canWritePlusFeature('advanced_insights'), isTrue);
    expect(state.hasPlusFeature('savings_projections'), isTrue,
        reason: 'active Plus includes every currently advertised capability');
    expect(state.hasPlusFeature('not_a_real_plus_feature'), isFalse);

    state.familyEntitlement = const FamilyEntitlement(
      familyId: 'family-1',
      status: EntitlementStatus.expired,
      features: {'advanced_insights'},
    );
    expect(state.hasPlus, isFalse);
    expect(state.hasPlusFeature('advanced_insights'), isFalse);
    state.dispose();
  });

  test('legacy active entitlement unlocks newer chat and commitment features',
      () {
    final state = AppState();
    state.familyEntitlement = const FamilyEntitlement(
      familyId: 'family-legacy',
      status: EntitlementStatus.active,
      features: {},
    );

    expect(state.hasPlusFeature('smart_commitments'), isTrue);
    expect(state.canWritePlusFeature('smart_commitments'), isTrue);
    expect(state.canWritePlusFeature('enhanced_family_chat'), isTrue);
    expect(state.canWritePlusFeature('family_polls_pins'), isTrue);
    expect(state.canWritePlusFeature('advanced_chat_search'), isTrue);
  });

  test(
      'offline entitlement snapshot is bounded to 72h and scoped to family+user',
      () async {
    final now = DateTime.utc(2026, 10, 22, 12);
    final raw = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, version) => AppDatabase.createSchema(database),
      ),
    );
    final db = AppDatabase.wrap(raw);
    await db.kvSet('space_id', 'family-1');
    await db.kvSet('auth_user_id', 'user-1');
    final validSnapshot = FamilyEntitlement(
      familyId: 'family-1',
      status: EntitlementStatus.active,
      features: kPlusV2Features,
      expiresAt: now.add(const Duration(days: 20)),
      verifiedAt: now.subtract(const Duration(hours: 24)),
      userId: 'user-1',
    );
    await db.kvSet(
      'family_entitlement_v1',
      jsonEncode(validSnapshot.toJson(userId: 'user-1')),
    );

    var clockNow = now;
    final state = AppState(db: db, clock: () => clockNow);
    await state.ready();

    expect(state.hasPlus, isTrue);
    expect(state.familyEntitlement?.isOfflineSnapshot, isTrue);
    expect(state.hasPlusFeature('smart_commitments'), isTrue);
    expect(state.canWritePlusFeature('smart_commitments'), isFalse);
    expect(
      state.addFinancialCommitment(FinancialCommitment(
        id: 'offline-rent',
        name: 'Rent',
        amount: const Money(10000, Currency.usd),
        firstDueDate: now.add(const Duration(days: 5)),
        recurrence: CommitmentRecurrence.monthly,
        createdById: state.realUser.id,
      )),
      isFalse,
    );
    expect(state.financialCommitments, isEmpty);

    // Advance clock past 72 hours from verifiedAt -> offline cache must expire
    clockNow = now.add(const Duration(hours: 49));
    expect(state.hasPlus, isFalse);
    expect(state.hasPlusFeature('smart_commitments'), isFalse);

    // Switching account clears entitlement immediately
    state.resetForAccount('user-2', email: 'other@example.com');
    expect(state.familyEntitlement, isNull);
    await state.flushWrites();
    expect(await db.kvGet('family_entitlement_v1'), isEmpty);

    state.dispose();
    await db.flushWrites();
    await db.raw.close();
  });
}
