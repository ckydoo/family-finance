import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/config/app_version.dart';

void main() {
  test('user-visible app version matches the current release', () {
    expect(kAppVersion, '0.2.0');
  });
}
