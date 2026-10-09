import 'package:integration_test/integration_test.dart';

import '../test/analytics/presentation/analytics_report_flow_test.dart'
    as report_flow;

/// Device entry point for the UC04 report flow.
///
/// `flutter test` runs the same cases from test/analytics. On a phone or
/// desktop target, run:
/// `flutter test integration_test/analytics_report_flow_test.dart -d <device>`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  report_flow.main();
}
