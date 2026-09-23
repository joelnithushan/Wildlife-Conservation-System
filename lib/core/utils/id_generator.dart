import 'package:uuid/uuid.dart';

/// Generates stable, client-side unique IDs.
///
/// IDs are created once on the client (not by the server), so an offline record
/// keeps the same ID across sync retries. Combined with idempotent upserts keyed
/// on this ID, retries never create duplicate remote records.
abstract final class IdGenerator {
  static const _uuid = Uuid();

  /// A fresh UUID v4, optionally namespaced by a short [prefix] for readability
  /// in logs (e.g. `patrol_3f2a...`).
  static String newId([String? prefix]) {
    final id = _uuid.v4();
    return prefix == null ? id : '${prefix}_$id';
  }
}
