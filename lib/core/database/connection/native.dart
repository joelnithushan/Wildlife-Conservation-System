import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Mobile/desktop connection backed by SQLite via a file in the app documents
/// directory.
QueryExecutor openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'wildlife_conservation.db'));
    return NativeDatabase.createInBackground(file);
  });
}
