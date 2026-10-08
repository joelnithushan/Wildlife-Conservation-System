import 'package:integration_test/integration_test_driver.dart';

/// Driver entrypoint for `flutter drive` so integration tests can run with
/// `--no-dds` (the Dart Development Service fails to start in this environment).
Future<void> main() => integrationDriver();
