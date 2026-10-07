import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/models/models.dart';
import 'package:mhuri_money/core/money/money.dart';
import 'package:mhuri_money/core/state/app_state.dart';

void main() {
  test('campaign separates pledged, collected and remaining amounts', () {
    final state = AppState();
    state.members.add(state.user);
    state.createContributionCampaign(
      name: 'Christmas Gathering',
      target: const Money(60000, Currency.usd),
      deadline: DateTime(2026, 12, 20),
    );
    final campaign = state.contributionCampaigns.single;

    expect(
        state.setContributionPledge(
            campaign, state.user.id, const Money(20000, Currency.usd)),
        isTrue);
    expect(
        state.recordContributionPayment(
            campaign, state.user.id, const Money(7500, Currency.usd),
            id: 'pay-1'),
        isTrue);
    expect(state.pledgedFor(campaign).minor, 20000);
    expect(state.collectedFor(campaign).minor, 7500);
    expect(state.collectedFor(campaign, state.user.id).minor, 7500);
  });

  test('payment ids prevent duplicate collection records', () {
    final state = AppState();
    state.members.add(state.user);
    final campaign = ContributionCampaign(
      id: 'campaign',
      name: 'School reunion',
      target: const Money(10000, Currency.usd),
      deadline: DateTime(2026, 11, 1),
      createdById: state.user.id,
    );
    state.contributionCampaigns.add(campaign);

    expect(
        state.recordContributionPayment(
            campaign, state.user.id, const Money(1000, Currency.usd),
            id: 'same'),
        isTrue);
    expect(
        state.recordContributionPayment(
            campaign, state.user.id, const Money(1000, Currency.usd),
            id: 'same'),
        isFalse);
    expect(state.contributionPayments, hasLength(1));
  });
}
