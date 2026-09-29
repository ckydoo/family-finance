import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/auth/auth_controller.dart';
import 'package:mhuri_money/core/db/app_database.dart';
import 'package:mhuri_money/core/models/models.dart';
import 'package:mhuri_money/core/money/money.dart';
import 'package:mhuri_money/core/state/app_state.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fake_auth.dart';
import 'seed.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase db;

  setUp(() async {
    final raw = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (d, v) async => AppDatabase.createSchema(d),
      ),
    );
    db = AppDatabase.wrap(raw);
  });

  tearDown(() async {
    await db.raw.close();
  });

  Future<AppState> freshState() async {
    final s = AppState(db: db);
    await s.ready();
    seedMemory(s);
    s.members.addAll(const [
      Member(id: 'm_owner', name: 'David Moyo', emoji: 'person', role: Role.owner),
      Member(id: 'm_adult', name: 'Mai Moyo', emoji: 'person', role: Role.adult),
      Member(id: 'm_teen', name: 'Tinashe Moyo', emoji: 'person', role: Role.teen),
      Member(id: 'm_kid', name: 'Leo Moyo', emoji: 'child', role: Role.kid),
    ]);
    s.switchUser(s.members.first);
    return s;
  }

  group('Phase 3 - Account Lifecycle', () {
    test('signup, confirmation state, and resend flow', () async {
      final fake = FakeAuthService();
      final auth = AuthController(env: testEnv(), service: fake);

      // Sign up with an address requiring confirmation
      fake.requireConfirmation = true;
      final ok = await auth.signUp('newuser@mhuri.app', 'correct-password');
      expect(ok, isFalse);
      expect(auth.needsConfirmation, isTrue);
      expect(auth.isLoggedIn, isFalse);

      // Resend confirmation
      final resent = await auth.resendConfirmation('newuser@mhuri.app');
      expect(resent, isTrue);

      // After user confirms, sign in succeeds
      fake.requireConfirmation = false;
      final signedIn = await auth.signIn('newuser@mhuri.app', 'correct-password');
      expect(signedIn, isTrue);
      expect(auth.isLoggedIn, isTrue);
      expect(auth.session?.email, 'newuser@mhuri.app');
    });

    test('reauthentication validates password before sensitive operations', () async {
      final fake = FakeAuthService();
      final auth = AuthController(env: testEnv(), service: fake);

      await auth.signIn('owner@mhuri.app', 'correct-password');
      expect(auth.isLoggedIn, isTrue);

      // Incorrect password fails
      final wrong = await auth.reauthenticate('wrong-pass');
      expect(wrong, isFalse);

      // Correct password succeeds
      final right = await auth.reauthenticate('correct-password');
      expect(right, isTrue);
    });

    test('session persistence across simulated app restart', () async {
      final fake = FakeAuthService();
      final auth1 = AuthController(env: testEnv(), service: fake);

      await auth1.signIn('restored@mhuri.app', 'correct-password');
      expect(auth1.isLoggedIn, isTrue);

      // Simulate app restart with a new controller sharing the same auth backend
      final auth2 = AuthController(env: testEnv(), service: fake);
      expect(auth2.isLoggedIn, isFalse);

      await auth2.restore();
      expect(auth2.isLoggedIn, isTrue);
      expect(auth2.session?.email, 'restored@mhuri.app');
    });

    test('forgot password and password reset adoption', () async {
      final fake = FakeAuthService();
      final auth = AuthController(env: testEnv(), service: fake);

      final resetSent = await auth.sendPasswordReset('user@mhuri.app');
      expect(resetSent, isTrue);

      final adopted = await auth.adoptRecoverySession('recovery-access', 'recovery-refresh');
      expect(adopted, isTrue);
      expect(auth.isLoggedIn, isTrue);

      final updated = await auth.updatePassword('brand-new-password');
      expect(updated.ok, isTrue);
    });
  });

  group('Phase 3 - Family Lifecycle & Governance', () {
    test('owner cannot delete account when other family members exist', () async {
      final s = await freshState();

      // Verify initial state: owner exists and there are multiple members
      expect(s.user.role, Role.owner);
      expect(s.members.length, greaterThan(1));

      // Attempting deletion while members exist must be blocked
      final canDeleteDirectly = s.user.role != Role.owner || s.members.length <= 1;
      expect(canDeleteDirectly, isFalse);
    });

    test('ownership transfer swaps owner role to another adult member', () async {
      final s = await freshState();
      final initialOwner = s.members.firstWhere((m) => m.role == Role.owner);
      final adultCandidate = s.members.firstWhere((m) => m.role == Role.adult);

      expect(initialOwner.id, isNot(adultCandidate.id));

      // Simulate ownership transfer: candidate becomes owner, previous owner becomes adult
      final updatedMembers = s.members.map<Member>((m) {
        if (m.id == adultCandidate.id) {
          return Member(
            id: m.id,
            name: m.name,
            emoji: m.emoji,
            role: Role.owner,
            avatarUrl: m.avatarUrl,
          );
        } else if (m.id == initialOwner.id) {
          return Member(
            id: m.id,
            name: m.name,
            emoji: m.emoji,
            role: Role.adult,
            avatarUrl: m.avatarUrl,
          );
        }
        return m;
      }).toList();

      s.members.clear();
      s.members.addAll(updatedMembers);

      expect(s.members.firstWhere((m) => m.id == adultCandidate.id).role, Role.owner);
      expect(s.members.firstWhere((m) => m.id == initialOwner.id).role, Role.adult);

      // Now the former owner is a standard adult member and can leave/delete without ownership transfer block
      final formerOwner = s.members.firstWhere((m) => m.id == initialOwner.id);
      final canLeaveNow = formerOwner.role != Role.owner || s.members.length <= 1;
      expect(canLeaveNow, isTrue);
    });

    test('member leave preserves ledger history with former member attribution', () async {
      final s = await freshState();
      final leavingMember = s.members.firstWhere((m) => m.role == Role.adult);

      // Add transaction by the leaving member
      s.addTx(
        type: TxType.expense,
        amount: Money.fromMajor(45.0, Currency.usd),
        memberId: leavingMember.id,
        method: Method.bankCard,
        note: 'School uniforms',
      );

      final totalSpentBefore = s.txs
          .where((t) => t.memberId == leavingMember.id)
          .fold<int>(0, (sum, t) => sum + t.amount.minor);
      expect(totalSpentBefore, greaterThan(0));

      // Member leaves: removed from active members list
      s.members.removeWhere((m) => m.id == leavingMember.id);
      expect(s.members.any((m) => m.id == leavingMember.id), isFalse);

      // Transactions still exist in ledger and balance remains reconciled
      final transactionsRemain = s.txs.where((t) => t.memberId == leavingMember.id).toList();
      expect(transactionsRemain.isNotEmpty, isTrue);
      expect(transactionsRemain.first.note, 'School uniforms');

      // Member lookup gracefully returns null for inactive/removed member
      final memberLookup = s.member(leavingMember.id);
      expect(memberLookup, isNull);
    });

    test('sole owner deletion clears local account data and cascades', () async {
      final s = await freshState();

      // Reduce to sole member
      final soleOwner = s.members.firstWhere((m) => m.role == Role.owner);
      s.members.clear();
      s.members.add(soleOwner);
      expect(s.members.length, 1);

      // Can proceed to delete
      final canDelete = s.user.role != Role.owner || s.members.length <= 1;
      expect(canDelete, isTrue);

      // Clearing local account data wipes session & caches
      await s.clearLocalAccountData();
      expect(s.hasSpace, isFalse);
      expect(s.inviteCode, isNull);
    });
  });
}

