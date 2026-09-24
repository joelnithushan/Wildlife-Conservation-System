import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

/// Web connection backed by SQLite compiled to WebAssembly.
///
/// Requires `sqlite3.wasm` and `drift_worker.js` to be served from the web
/// root (see README "Running on Web"). Used for manager/analyst dashboards.
QueryExecutor openConnection() {
  return LazyDatabase(() async {
    final result = await WasmDatabase.open(
      databaseName: 'wildlife_conservation',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.js'),
    );
    return result.resolvedExecutor;
  });
}
