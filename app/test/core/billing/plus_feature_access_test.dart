import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/billing/entitlement.dart';
import 'package:mhuri_money/core/state/app_state.dart';

void main() {
  test('Plus features require an active family entitlement and matching key', () {
    final state = AppState();
    expect(state.hasPlus, isFalse);
    expect(state.hasPlusFeature('advanced_insights'), isFalse);

    state.familyEntitlement = const FamilyEntitlement(
      familyId: 'family-1',
      status: EntitlementStatus.active,
      features: {'advanced_insights'},
    );
    expect(state.hasPlusFeature('advanced_insights'), isTrue);
    expect(state.hasPlusFeature('savings_projections'), isFalse);

    state.familyEntitlement = const FamilyEntitlement(
      familyId: 'family-1',
      status: EntitlementStatus.expired,
      features: {'advanced_insights'},
    );
    expect(state.hasPlus, isFalse);
    expect(state.hasPlusFeature('advanced_insights'), isFalse);
    state.dispose();
  });
}
