import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/firebase/firebase_services.dart';

void main() {
  test('chat push payloads resolve to the family chat destination', () {
    expect(
      FirebaseServices.destinationForData(
          const {'table': 'family_chat_message'}),
      'family_chat',
    );
    expect(
      FirebaseServices.destinationForData(const {'event': 'family_chat'}),
      'family_chat',
    );
    expect(
      FirebaseServices.destinationForData(const {'route': 'chat'}),
      'family_chat',
    );
  });

  test('unrelated family pushes do not open chat', () {
    expect(
      FirebaseServices.destinationForData(
          const {'table': 'activity_log', 'event': 'request.create'}),
      isNull,
    );
  });
}
