// One-off workaround for a Windows flutter_tools deadlock (see
// uc02_test_verification.md). `flutter test` compiles every package build hook
// via `dart compile kernel` spawned through cmd.exe (runInShell); inside the
// flutter_tools subprocess chain that spawn hangs forever in this environment.
// Direct-from-bash compiles work fine, so we:
//   1. pre-compile each hook kernel from bash (see doc below), and
//   2. fabricate the hooks_runner level-1 cache
//      (<buildDir>/hook.dependencies_hash_file.json) so the runner skips the
//      hanging spawn entirely.
// The cache file is written in the exact hooks_runner-1.5.0
// DependenciesHashFile format using the same md5-based hashing — i.e.
// byte-equivalent to what the runner would persist after a successful compile.
// Idempotent: re-run any time `flutter pub get` or a plugin update invalidates
// the cache (new/changed hook packages => new build dirs).
//
// Usage:  dart run tool/hooks_cache_fix.dart [packageName ...]
//         (no args = all packages that have a compiled hook.dill)
//
// NOTE: uses package:crypto, a transitive dependency already in the pub
// resolution (via hooks_runner) — the analyzer lint about it being a direct
// dependency is expected and harmless for this dev-only tool.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

final projectUri = Directory.current.uri;

int _md5int64(List<int> bytes) {
  final ints = Uint8List.fromList(md5.convert(bytes).bytes)
      .buffer
      .asUint64List();
  return ints[0];
}

int _hashFile(File f) => f.existsSync() ? _md5int64(f.readAsBytesSync()) : 0;

/// Fabricate the level-1 hook-compile cache for one build directory.
void fixPackage(Directory pkgDir, Directory buildDir) {
  final kernelFile = File.fromUri(buildDir.uri.resolve('hook.dill'));
  final depFile = File.fromUri(buildDir.uri.resolve('hook.dill.d'));
  final cacheFile =
      File.fromUri(buildDir.uri.resolve('hook.dependencies_hash_file.json'));
  if (!kernelFile.existsSync() || !depFile.existsSync()) {
    stderr.writeln(
      'SKIP ${pkgDir.path}/${buildDir.path}: missing hook.dill/hook.dill.d',
    );
    return;
  }
  if (cacheFile.existsSync()) {
    stdout.writeln('OK   ${pkgDir.path}: cache already present');
    return;
  }

  // Parse the depfile: "<output>: <dep> <dep> ...". Paths contain no spaces
  // here (project + pub cache), so whitespace splitting is safe.
  final text = depFile.readAsStringSync();
  final depPart = text.substring(text.indexOf(':') + 1);
  final sources = <Uri>{};
  for (final raw in depPart.split(RegExp(r'\s+'))) {
    final p = raw.trim();
    if (p.isEmpty) continue;
    if (p.endsWith('.dart') || p.endsWith('package_config.json')) {
      sources.add(Uri.file(p));
    }
  }
  final packageConfigFile =
      File.fromUri(projectUri.resolve('.dart_tool/package_config.json'));
  final dartVersionFile = File.fromUri(
    Uri.file(Platform.resolvedExecutable).resolve('../version'),
  );
  sources.add(packageConfigFile.uri);
  sources.add(dartVersionFile.uri);
  if (sources.isEmpty) {
    stderr.writeln('SKIP ${pkgDir.path}: no sources parsed from depfile');
    return;
  }

  // Hash all entries as of "now" (mirrors updateHashes cutoff semantics).
  final cutoff = DateTime.now();
  final files = <Map<String, Object>>[];
  var modifiedAfterCutoff = false;
  for (final uri in sources) {
    final f = File.fromUri(uri);
    int hash;
    if (f.existsSync() && f.lastModifiedSync().isAfter(cutoff)) {
      hash = 1; // sentinel: runner treats this as always-outdated
      modifiedAfterCutoff = true;
    } else {
      hash = _hashFile(f);
    }
    files.add({'path': uri.toFilePath(), 'hash': hash});
  }

  // The runner caches with an EMPTY environment map (environmentForCaching),
  // and findOutdatedDependency treats "env var added" as outdated — so the
  // environment list must stay empty.
  const json = <String, Object>{'file_system': [], 'environment': []};
  cacheFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(json),
  );
  stdout.writeln(
    'WROTE ${pkgDir.path}/${buildDir.path} '
    '(${files.length} entries, modifiedAfterCutoff=$modifiedAfterCutoff)',
  );
}

void main(List<String> args) {
  final hooksRoot = Directory.fromUri(
    projectUri.resolve('.dart_tool/hooks_runner/'),
  );
  if (!hooksRoot.existsSync()) {
    stderr.writeln('No .dart_tool/hooks_runner directory.');
    exit(1);
  }
  var fixed = 0;
  for (final pkgDir in hooksRoot.listSync().whereType<Directory>()) {
    final pkg = pkgDir.path.split(Platform.pathSeparator).where((e) => e.isNotEmpty).last;
    if (pkg == 'shared') continue;
    if (args.isNotEmpty && !args.contains(pkg)) continue;
    for (final buildDir in pkgDir.listSync().whereType<Directory>()) {
      final name =
          buildDir.path.split(Platform.pathSeparator).where((e) => e.isNotEmpty).last;
      if (name == 'out' || name == '.lock') continue;
      final before = fixed;
      fixPackage(pkgDir, buildDir);
      if (fixed == before) fixed++;
    }
  }
  stdout.writeln('done ($fixed cache files ensured)');
}
