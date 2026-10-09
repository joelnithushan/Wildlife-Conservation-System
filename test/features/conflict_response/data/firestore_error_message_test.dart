import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/features/conflict_response/data/repositories/firestore_conflict_repository.dart';

/// §34: the UC03 Firestore repository must never surface a raw FirebaseException
/// string in the UI. FirestoreConflictRepository translates infrastructure
/// errors to these messages via [friendlyFirestoreMessage]; this covers the
/// mapping (the repository itself needs a live/emulated Firestore to exercise).
void main() {
  test('known infrastructure codes map to clear, user-safe messages', () {
    expect(friendlyFirestoreMessage('unavailable'),
        contains('temporarily unavailable'));
    expect(friendlyFirestoreMessage('deadline-exceeded'),
        contains('temporarily unavailable'));
    expect(friendlyFirestoreMessage('permission-denied'),
        contains('permission'));
    expect(friendlyFirestoreMessage('not-found'), contains('could not be found'));
    expect(friendlyFirestoreMessage('unauthenticated'),
        contains('session has expired'));
    expect(friendlyFirestoreMessage('aborted'), contains('conflicted'));
  });

  test('an unknown code falls back to a generic retry message', () {
    expect(friendlyFirestoreMessage('some-new-firebase-code'),
        'Something went wrong reaching the server. Please try again.');
  });

  test('messages read like human copy, never a raw Firebase error', () {
    for (final code in const [
      'unavailable',
      'permission-denied',
      'not-found',
      'unauthenticated',
      'aborted',
      'weird-code',
    ]) {
      final msg = friendlyFirestoreMessage(code);
      // No bracketed Firebase prefix (e.g. "[cloud_firestore/unavailable]"),
      // no package name, and a readable sentence that ends with punctuation.
      expect(msg, isNot(contains('[')));
      expect(msg, isNot(contains('cloud_firestore')));
      expect(msg, isNot(contains('/')));
      expect(msg.endsWith('.'), isTrue);
      expect(msg.length, greaterThan(20));
    }
  });
}
