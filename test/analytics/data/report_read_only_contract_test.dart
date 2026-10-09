import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// UC04 may write a local export file. It must not write patrols, incidents,
/// alerts, or assignments.
void main() {
  test('analytics sources do not write UC01–UC03 records', () {
    final root = Directory('lib/features/analytics');
    expect(root.existsSync(), isTrue, reason: 'run from the repository root');

    final violations = <String>[];
    final forbidden = RegExp(
      r'''\.(insert|update|delete|set|write)\(|\binto\(|\.batch\(''',
    );

    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final name = entity.uri.pathSegments.last;
      // Export bytes are a local file or a browser download, not source data.
      if (name.startsWith('report_file_saver')) continue;

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.startsWith('//') ||
            line.startsWith('*') ||
            line.startsWith('///')) {
          continue;
        }
        if (forbidden.hasMatch(line)) {
          violations.add('${entity.path}:${i + 1}: $line');
        }
      }
    }

    expect(violations, isEmpty);
  });
}
