import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/core/utils/validators.dart';

void main() {
  group('validCoordinates', () {
    test('accepts in-range values', () {
      expect(Validators.validCoordinates(7.87, 80.77), isTrue);
      expect(Validators.validCoordinates(-90, 180), isTrue);
    });

    test('rejects out-of-range and non-finite', () {
      expect(Validators.validCoordinates(91, 0), isFalse);
      expect(Validators.validCoordinates(0, 181), isFalse);
      expect(Validators.validCoordinates(double.nan, 0), isFalse);
      expect(Validators.validCoordinates(0, double.infinity), isFalse);
    });
  });

  group('validDateRange', () {
    test('start before or equal end is valid', () {
      final start = DateTime(2026, 1, 1);
      final end = DateTime(2026, 2, 1);
      expect(Validators.validDateRange(start, end), isTrue);
      expect(Validators.validDateRange(start, start), isTrue);
    });

    test('start after end is invalid', () {
      expect(
        Validators.validDateRange(DateTime(2026, 3, 1), DateTime(2026, 1, 1)),
        isFalse,
      );
    });
  });

  group('nonEmptyDescription', () {
    test('rejects null and whitespace', () {
      expect(Validators.nonEmptyDescription(null), isFalse);
      expect(Validators.nonEmptyDescription('   '), isFalse);
    });
    test('accepts real text', () {
      expect(Validators.nonEmptyDescription('snare found'), isTrue);
    });
  });

  group('incidentEvidenceValid (photo OR omission reason)', () {
    test('valid with a local photo', () {
      expect(
        Validators.incidentEvidenceValid(localPhotoPath: '/tmp/x.jpg'),
        isTrue,
      );
    });
    test('valid with an uploaded url', () {
      expect(
        Validators.incidentEvidenceValid(photoUrl: 'https://x/y.jpg'),
        isTrue,
      );
    });
    test('valid with an omission reason', () {
      expect(
        Validators.incidentEvidenceValid(evidenceOmissionReason: 'camera failed'),
        isTrue,
      );
    });
    test('invalid with neither', () {
      expect(Validators.incidentEvidenceValid(), isFalse);
      expect(
        Validators.incidentEvidenceValid(localPhotoPath: '  ', evidenceOmissionReason: ''),
        isFalse,
      );
    });
  });
}
