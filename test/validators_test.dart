import 'package:flutter_test/flutter_test.dart';

import 'package:team_track/core/utils/validators.dart';

void main() {
  group('Validators.requiredText', () {
    test('returns error for null or blank', () {
      expect(Validators.requiredText(null, label: 'Name'), 'Name is required');
      expect(Validators.requiredText('   ', label: 'Name'), 'Name is required');
    });

    test('returns null for valid text', () {
      expect(Validators.requiredText('Alex', label: 'Name'), isNull);
    });
  });

  group('Validators.nonNegativeInt', () {
    test('accepts 0 and positive ints', () {
      expect(Validators.nonNegativeInt('0', label: 'Minutes'), isNull);
      expect(Validators.nonNegativeInt('120', label: 'Minutes'), isNull);
    });

    test('rejects null, non-int and negatives', () {
      expect(Validators.nonNegativeInt(null, label: 'Minutes'), 'Minutes must be >= 0');
      expect(Validators.nonNegativeInt('x', label: 'Minutes'), 'Minutes must be >= 0');
      expect(Validators.nonNegativeInt('-1', label: 'Minutes'), 'Minutes must be >= 0');
    });
  });

  group('Validators.boundedInt', () {
    test('accepts values in range', () {
      expect(
        Validators.boundedInt('90', min: 0, max: 120, label: 'Minutes'),
        isNull,
      );
    });

    test('rejects values out of range or invalid', () {
      expect(
        Validators.boundedInt('-1', min: 0, max: 120, label: 'Minutes'),
        'Minutes must be between 0 and 120',
      );
      expect(
        Validators.boundedInt('121', min: 0, max: 120, label: 'Minutes'),
        'Minutes must be between 0 and 120',
      );
      expect(
        Validators.boundedInt('abc', min: 0, max: 120, label: 'Minutes'),
        'Minutes must be between 0 and 120',
      );
    });
  });
}