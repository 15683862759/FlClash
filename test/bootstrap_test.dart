import 'package:fl_clash/bootstrap.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('disclaimer consent', () {
    test('records consent that was given', () async {
      var exited = false;
      var recorded = false;

      await resolveDisclaimerConsent(
        accepted: true,
        exit: () async => exited = true,
        record: () => recorded = true,
      );

      expect(exited, isFalse);
      expect(recorded, isTrue);
    });

    test('never records a refusal', () async {
      var exited = false;
      var recorded = false;

      await resolveDisclaimerConsent(
        accepted: false,
        exit: () async => exited = true,
        record: () => recorded = true,
      );

      expect(exited, isTrue);
      expect(recorded, isFalse);
    });
  });
}
