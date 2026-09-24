import 'package:drift/drift.dart';

/// Fallback used when neither dart:io nor web is available.
QueryExecutor openConnection() =>
    throw UnsupportedError('No database connection is available on this platform.');
