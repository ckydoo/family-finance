import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/models/models.dart';
import 'package:mhuri_money/core/money/money.dart';
import 'package:mhuri_money/core/security/rate_limiter.dart';
import 'package:mhuri_money/core/state/app_state.dart';

void main() {
  group('Phase 4 - Permissions Matrix & Security Enforcement', () {
    AppState makeStateFor({
      required Role role,
      String id = 'm_actor',
      String name = 'Actor',
    }) {
      final actor = Member(id: id, name: name, emoji: 'person', role: role);
      final s = AppState();
      s.members
        ..clear()
        ..addAll([
          const Member(
              id: 'm_owner', name: 'Owner', emoji: '👑', role: Role.owner),
          const Member(
              id: 'm_adult', name: 'Adult', emoji: '🧑', role: Role.adult),
          const Member(
              id: 'm_teen', name: 'Teen', emoji: '🎧', role: Role.teen),
          const Member(id: 'm_kid', name: 'Kid', emoji: '🎈', role: Role.kid),
          const Member(
              id: 'm_viewer', name: 'Viewer', emoji: '👀', role: Role.viewer),
          actor,
        ]);
      s.switchUser(actor);
      s.setRealUser(actor);

      // Add mock envelopes, accounts, goals, chores, etc.
      s.envelopes
        ..clear()
        ..addAll([
          Envelope(
            id: 'env_groceries',
            name: 'Groceries',
            emoji: 'cart',
            limit: const Money(30000, Currency.usd),
          ),
          Envelope(
            id: 'env_fun',
            name: 'Fun',
            emoji: 'game',
            limit: const Money(10000, Currency.usd),
          ),
        ]);
      s.goals
        ..clear()
        ..add(const Goal(
          id: 'g_jar',
          name: "Kid's Jar",
          emoji: 'jar',
          target: Money(5000, Currency.usd),
          isKidJar: true,
        ));
      return s;
    }

    test('1. Owner permissions: full authority across all domains', () async {
      final s = makeStateFor(role: Role.owner);

      expect(s.authRole, Role.owner);
      expect(s.canAdmin, isTrue);
      expect(s.canInvite, isTrue);
      expect(s.canApprove, isTrue);
      expect(s.canEditBudgets, isTrue);
      expect(s.canTransferOwnership, isTrue);
      expect(s.canDeleteSpace, isTrue);
      expect(s.canAuthorTransact, isTrue);
      expect(s.canAuthorViewBudget, isTrue);
      expect(s.canAuthorViewWallet, isTrue);
      expect(s.canEditLists, isTrue);
      expect(s.canContributeSavings, isTrue);

      final chore = s.addChore(name: 'Wash dishes', starsReward: 4);
      expect(chore, isNotNull);
      expect(s.chores.single.name, 'Wash dishes');
      expect(s.chores.single.stars, 4);

      // Budgets: moveMoney & addEnvelope
      final moved = s.moveMoney(s.envelopes[0], s.envelopes[1],
          const Money(2000, Currency.usd), 'Reallocate');
      expect(moved, isTrue);
      final envCountBefore = s.envelopes.length;
      s.addEnvelope(name: 'Utilities', limit: const Money(5000, Currency.usd));
      expect(s.envelopes.length, envCountBefore + 1);

      // Transactions
      final txOk = s.addTx(
        type: TxType.expense,
        amount: const Money(1500, Currency.usd),
        memberId: s.user.id,
        method: Method.cash,
        note: 'Hardware store',
        envelopeId: 'env_groceries',
      );
      expect(txOk, isTrue);

      // Savings circle
      s.circle = SavingsCircle(
        name: 'Family Mukando',
        contribution: const Money(1000, Currency.usd),
        totalRounds: 5,
        currentRound: 1,
        order: const ['Owner', 'Adult'],
      );
      s.circleCollect();
      expect(s.circle.currentRound, 2);

      // Settings
      s.setOverspendPolicy(OverspendPolicy.block);
      expect(s.overspendPolicy, OverspendPolicy.block);
      s.setMonthStartDay(15);
      expect(s.monthStartDay, 15);
    });

    test(
        '2. Adult Member: everyday financial authority without family administration',
        () async {
      final s = makeStateFor(role: Role.adult);

      expect(s.authRole, Role.adult);
      expect(s.canAdmin, isFalse);
      expect(s.canInvite, isFalse);
      expect(s.canApprove, isTrue);
      expect(s.canEditBudgets, isTrue);
      expect(s.canAuthorTransact, isTrue);
      expect(s.canTransferOwnership, isFalse);
      expect(s.canDeleteSpace, isFalse);

      // Budgets
      final moved = s.moveMoney(s.envelopes[0], s.envelopes[1],
          const Money(1000, Currency.usd), 'Shift');
      expect(moved, isTrue);

      // Approvals: chores & kid requests
      final chore = Chore(
        id: 'c1',
        name: 'Dishes',
        stars: 5,
        state: ChoreState.waiting,
      );
      final starsBefore = s.stars;
      s.confirmChore(chore);
      expect(chore.state, ChoreState.confirmed);
      expect(s.stars, starsBefore + 5);

      final req = KidRequest(
        id: 'r1',
        kidId: 'm_kid',
        amount: const Money(500, Currency.usd),
        reason: 'Book',
      );
      s.requests.add(req);
      s.approveRequest(req);
      expect(req.state, RequestState.approved);
    });

    test(
        '3. Teen: transacting & budget access governed by permission switches, no admin/budget editing',
        () async {
      final s = makeStateFor(role: Role.teen);

      expect(s.authRole, Role.teen);
      expect(s.canAdmin, isFalse);
      expect(s.canInvite, isFalse);
      expect(s.canApprove, isFalse);
      expect(s.canEditBudgets, isFalse);
      expect(s.canTransferOwnership, isFalse);
      expect(s.canDeleteSpace, isFalse);
      expect(s.canEditLists, isFalse);

      expect(
        s.addChore(name: 'Unauthorized chore', starsReward: 3),
        isNull,
      );
      expect(s.chores, isEmpty);
      expect(s.canContributeSavings, isTrue);

      // Default switches: teen_transactions = true, teen_budget = true
      expect(s.canAuthorTransact, isTrue);
      expect(s.canAuthorViewBudget, isTrue);

      // Attempting to move budget money is denied
      final moved = s.moveMoney(s.envelopes[0], s.envelopes[1],
          const Money(500, Currency.usd), 'Teen shift');
      expect(moved, isFalse);

      // Attempting to add envelope is denied
      final envCount = s.envelopes.length;
      s.addEnvelope(name: 'Sneakers', limit: const Money(5000, Currency.usd));
      expect(s.envelopes.length, envCount);

      // Attempting to approve chore is denied
      final chore = Chore(
        id: 'c2',
        name: 'Mow lawn',
        stars: 10,
        state: ChoreState.waiting,
      );
      final starsBefore = s.stars;
      s.confirmChore(chore);
      expect(chore.state, ChoreState.waiting);
      expect(s.stars, starsBefore);

      // When parent turns off teen_transactions switch:
      s.applyRolePermissions({'teen_transactions': false});
      // Teen cannot apply permissions!
      // Real admin applies permission switch:
      s.setRealUser(s.members.firstWhere((m) => m.role == Role.owner));
      s.applyRolePermissions(
          {'teen_transactions': false, 'teen_budget': false});
      // Switch back to teen actor
      s.setRealUser(s.members.firstWhere((m) => m.id == 'm_actor'));

      expect(s.canAuthorTransact, isFalse);
      expect(s.canAuthorViewBudget, isFalse);

      final txBlocked = s.addTx(
        type: TxType.expense,
        amount: const Money(200, Currency.usd),
        memberId: s.user.id,
        method: Method.cash,
        note: 'Snack',
      );
      expect(txBlocked, isFalse);
    });

    test(
        '4. Kid (Child): child_transactions default false and shared shopping administration is blocked',
        () async {
      final s = makeStateFor(role: Role.kid);

      expect(s.authRole, Role.kid);
      expect(s.canAdmin, isFalse);
      expect(s.canInvite, isFalse);
      expect(s.canApprove, isFalse);
      expect(s.canEditBudgets, isFalse);
      expect(
          s.canAuthorTransact, isFalse); // child_transactions defaults to false
      expect(s.canAuthorViewBudget, isTrue); // child_budget defaults to true
      expect(s.canEditLists, isFalse);

      // Cannot add transactions directly
      final txBlocked = s.addTx(
        type: TxType.expense,
        amount: const Money(100, Currency.usd),
        memberId: s.user.id,
        method: Method.cash,
        note: 'Candy',
      );
      expect(txBlocked, isFalse);

      // Cannot mutate the adults' shared shopping list through Kids Mode.
      s.addItem('Cereal', 1, const Money(400, Currency.usd));
      expect(s.items.any((i) => i.name == 'Cereal'), isFalse);

      // Can claim a chore
      final chore = Chore(
        id: 'c3',
        name: 'Make bed',
        stars: 2,
        state: ChoreState.todo,
      );
      s.claimChore(chore);
      expect(chore.state, ChoreState.waiting);

      // Cannot self-confirm chore
      s.confirmChore(chore);
      expect(chore.state, ChoreState.waiting);

      // Request money works
      s.requestMoney(const Money(300, Currency.usd), 'Art supplies');
      expect(s.requests.any((r) => r.reason == 'Art supplies'), isTrue);
    });

    test(
        '5. Viewer (Elder / Observer): read-only access, all mutations and write actions blocked',
        () async {
      final s = makeStateFor(role: Role.viewer);

      expect(s.authRole, Role.viewer);
      expect(s.canAdmin, isFalse);
      expect(s.canInvite, isFalse);
      expect(s.canApprove, isFalse);
      expect(s.canEditBudgets, isFalse);
      expect(s.canAuthorTransact, isFalse);
      expect(s.canEditLists, isFalse);
      expect(s.canContributeSavings, isFalse);
      expect(s.canAuthorViewBudget, isTrue); // Read-only viewing allowed
      expect(s.canAuthorViewWallet, isTrue); // Read-only viewing allowed

      // Mutations are strictly blocked:
      expect(
        s.addTx(
          type: TxType.expense,
          amount: const Money(500, Currency.usd),
          memberId: s.user.id,
          method: Method.cash,
          note: 'Viewer expense',
        ),
        isFalse,
      );

      final envCount = s.envelopes.length;
      s.addEnvelope(name: 'Gardening', limit: const Money(2000, Currency.usd));
      expect(s.envelopes.length, envCount);

      final itemCount = s.items.length;
      s.addItem('Tea', 1, const Money(200, Currency.usd));
      expect(s.items.length, itemCount);

      s.contribute(s.goals.first, const Money(100, Currency.usd));
      expect(s.goalTxs, isEmpty);

      s.setOverspendPolicy(OverspendPolicy.block);
      expect(s.overspendPolicy, OverspendPolicy.warn); // not changed
    });

    test(
        '6. Profile Preview Privilege Escalation Prevention: previewing an owner never grants owner authority',
        () async {
      // Authenticated user is a KID
      final s = makeStateFor(role: Role.kid, id: 'm_leo', name: 'Leo');

      expect(s.user.role, Role.kid);
      expect(s.realUser.role, Role.kid);
      expect(s.authRole, Role.kid);
      expect(s.canEditBudgets, isFalse);
      expect(s.canApprove, isFalse);
      expect(s.canAdmin, isFalse);

      // Kid previews the Owner ("Preview as Farai (Owner)")
      final owner = s.members.firstWhere((m) => m.role == Role.owner);
      s.switchUser(owner);

      // UI presents the owner profile:
      expect(s.user.id, owner.id);
      expect(s.user.role, Role.owner);

      // BUT authoritative credentials remain locked to the real user:
      expect(s.realUser.id, 'm_leo');
      expect(s.realUser.role, Role.kid);
      expect(s.authRole, Role.kid);

      // All authority getters MUST evaluate against authRole:
      expect(s.canAdmin, isFalse);
      expect(s.canInvite, isFalse);
      expect(s.canApprove, isFalse);
      expect(s.canEditBudgets, isFalse);
      expect(s.canTransferOwnership, isFalse);
      expect(s.canDeleteSpace, isFalse);
      expect(s.canAuthorTransact, isFalse);

      // Attempting to move budget money while in preview is BLOCKED
      final moved = s.moveMoney(s.envelopes[0], s.envelopes[1],
          const Money(5000, Currency.usd), 'Escalation attempt');
      expect(moved, isFalse);

      // Attempting to approve a request while in preview is BLOCKED
      final req = KidRequest(
        id: 'r_hack',
        kidId: 'm_leo',
        amount: const Money(10000, Currency.usd),
        reason: 'Free money',
      );
      s.requests.add(req);
      s.approveRequest(req);
      expect(req.state, RequestState.pending); // Not approved!

      // Attempting to change family settings while in preview is BLOCKED
      s.setOverspendPolicy(OverspendPolicy.block);
      expect(s.overspendPolicy, OverspendPolicy.warn);
    });

    test(
        '7. Rate Limiter: throttles repeated attempts and triggers temporary lockout',
        () async {
      final limiter = RateLimiter(
        maxAttempts: 3,
        window: const Duration(seconds: 10),
        lockoutDuration: const Duration(seconds: 15),
      );

      final now = DateTime(2026, 9, 23, 12, 0, 0);
      expect(limiter.isAllowed('user1', now: now), isTrue);

      expect(limiter.recordAttempt('user1', now: now), isTrue);
      expect(
          limiter.recordAttempt('user1',
              now: now.add(const Duration(seconds: 1))),
          isTrue);
      // 3rd attempt triggers lockout:
      expect(
          limiter.recordAttempt('user1',
              now: now.add(const Duration(seconds: 2))),
          isFalse);

      // Subsequent attempt during lockout is denied:
      expect(
          limiter.isAllowed('user1', now: now.add(const Duration(seconds: 5))),
          isFalse);
      expect(
          limiter.recordAttempt('user1',
              now: now.add(const Duration(seconds: 5))),
          isFalse);

      // After lockout expires (15 seconds after 12:00:02 -> 12:00:17):
      final afterLockout = now.add(const Duration(seconds: 18));
      expect(limiter.isAllowed('user1', now: afterLockout), isTrue);
    });

    test(
        '8. PIN Brute-force Prevention: 5 wrong attempts lock out verification',
        () async {
      final s = AppState();
      await s.pinStore.setPin('m_leo', '1234');

      expect(await s.pinStore.verifyPin('m_leo', '1234'), isTrue);

      // 5 failed attempts:
      for (var i = 0; i < 5; i++) {
        final res = await s.pinStore.verifyPin('m_leo', '9999');
        expect(res, isFalse);
      }

      // Now locked out:
      expect(s.pinStore.isLockedOut('m_leo'), isTrue);

      // Even entering the correct PIN fails while locked out:
      expect(await s.pinStore.verifyPin('m_leo', '1234'), isFalse);
    });

    test('9. Child chore and request journey requires a parent to complete it',
        () {
      final s = makeStateFor(role: Role.kid, id: 'm_child_actor');
      final child = s.realUser;
      final owner = s.members.firstWhere((m) => m.role == Role.owner);
      final chore = Chore(
        id: 'journey-chore',
        name: 'Sweep the kitchen',
        stars: 3,
      );
      s.chores.add(chore);

      s.claimChore(chore);
      expect(chore.state, ChoreState.waiting);
      expect(chore.assigneeMemberId, child.id);
      s.confirmChore(chore);
      expect(chore.state, ChoreState.waiting);

      s.requestMoney(const Money(400, Currency.usd), 'School notebook');
      final request = s.requests.single;
      expect(request.kidId, child.id);

      s.switchUser(owner);
      s.setRealUser(owner);
      s.confirmChore(chore);
      expect(chore.state, ChoreState.confirmed);
      expect(s.stars, 3);
      s.confirmChore(chore);
      expect(s.stars, 3, reason: 'confirmation must be idempotent');
      s.approveRequest(request);
      expect(request.state, RequestState.approved);
    });

    test('10. Teen proposal posts exactly once only after parent approval', () {
      final s = makeStateFor(role: Role.teen, id: 'm_teen_actor');
      final teen = s.realUser;
      final owner = s.members.firstWhere((m) => m.role == Role.owner);

      s.addEarning(const Money(2500, Currency.usd), 'Garden work');
      expect(s.earnings.single.memberId, teen.id);
      s.proposeExpense(
        const Money(700, Currency.usd),
        'env_groceries',
        'Lunch',
      );
      final proposal = s.proposals.single;
      expect(s.txs, isEmpty);

      s.switchUser(owner);
      s.setRealUser(owner);
      s.approveProposal(proposal);
      expect(proposal.state, RequestState.approved);
      expect(s.txs.where((tx) => tx.note == 'Approved: Lunch'), hasLength(1));
      s.approveProposal(proposal);
      expect(s.txs.where((tx) => tx.note == 'Approved: Lunch'), hasLength(1));
    });

    test('11. Role-only actions are rejected when called outside their UI', () {
      final ownerState = makeStateFor(role: Role.owner);
      ownerState.requestMoney(const Money(100, Currency.usd), 'Invalid');
      ownerState.addEarning(const Money(100, Currency.usd), 'Invalid');
      ownerState.proposeExpense(
        const Money(100, Currency.usd),
        'env_groceries',
        'Invalid',
      );
      expect(ownerState.requests, isEmpty);
      expect(ownerState.earnings, isEmpty);
      expect(ownerState.proposals, isEmpty);

      final viewerState = makeStateFor(role: Role.viewer);
      final chore = Chore(id: 'blocked-chore', name: 'Blocked', stars: 2);
      viewerState.claimChore(chore);
      expect(chore.state, ChoreState.todo);
    });
  });
}
