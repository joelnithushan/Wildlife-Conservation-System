# UC02 test-runner environment notes (Windows)

## The problem

`flutter test` deadlocked forever in this environment. With `-v` the last trace
line before the hang was always:

```
Running `...dart compile kernel --packages=... --output=.../hooks_runner/<pkg>/<hash>/hook.dill
--depfile=... C:\...\Pub\Cache\hosted\pub.dev\<pkg>\hook\build.dart`
```

`hooks_runner` (package `hooks_runner-1.5.0`, used by flutter_tools to run
native-assets build hooks — here `objective_c-9.5.0` and `sqlite3-3.5.2`)
compiles each package's `hook/build.dart` by spawning `dart compile kernel`
**through cmd.exe** (`runInShell: true` because a working directory is set —
see `run_process.dart`). Inside the flutter_tools subprocess chain that spawn
never completes on this machine (pipe/console interplay bug). The exact same
command run directly from the Git Bash terminal finishes in ~25s. The hang
re-arms for every hook package and every cache-invalidating change.

Workarounds that did NOT work: PowerShell parent, `cmd //c` parent, bypassing
the `flutter.bat` wrapper, `winpty` (console assertion), pre-building only the
kernel file (the runner re-spawns because its cache marker was missing).

## The fix that works

The hooks_runner has a two-level cache:

1. **Hook-compile cache** — `<buildDir>/hook.dependencies_hash_file.json`
   (format in `hooks_runner-1.5.0/lib/src/dependencies_hash_file/dependencies_hash_file.dart`).
   When present and hashes match, the `dart compile kernel` spawn is SKIPPED.
   Note: an *empty* `environment` list is required (the runner caches with an
   empty env map and treats "env var added" as outdated).
2. **Hook-output cache** — `<buildDir>/input.json` + `output.json` +
   `dependencies.dependencies_hash_file.json`. Once a hook has produced a
   successful `output.json`, later runs skip executing the hook.

`tool/hooks_cache_fix.dart` fabricates cache #1 (level-2 then fills in naturally
after the hook runs once). Recipe on a fresh checkout / after `pub get`:

1. Compile each hook kernel directly from bash (works fine):
   ```bash
   DART="$USERPROFILE/flutter-sdk/flutter/bin/cache/dart-sdk/bin/dart.exe"
   "$DART" compile kernel \
     --packages="$PWD/.dart_tool/package_config.json" \
     --output="$PWD/.dart_tool/hooks_runner/<pkg>/<hash>/hook.dill" \
     --depfile="$PWD/.dart_tool/hooks_runner/<pkg>/<hash>/hook.dill.d" \
     "$LOCALAPPDATA/Pub/Cache/hosted/pub.dev/<pkg>-<ver>/hook/build.dart"
   ```
   (`<hash>` currently `4a1c97ad39` for both packages; it appears in the
   `-v` log or is created by the runner when a run first stalls.)
2. Run `dart run tool/hooks_cache_fix.dart` to write the cache markers.
3. `flutter test` now runs normally (~15s for the UC02 suite).

## Failure artifacts (cleaned up)

- `test/patrol/presentation/failures/` — golden-image diff PNGs; removed after
  each run. The two remaining full-suite failures are UC01 golden pixel tests
  (`my_patrols.png`, `assign_patrol_route.png`, 1.8%/3.4% pixel diff) that are
  environment/font-rasterization-sensitive and pre-date UC02.
