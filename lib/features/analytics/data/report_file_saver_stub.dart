/// Fallback when neither `dart:io` nor the browser is available.
Future<String> saveReportBytes(String fileName, List<int> bytes) async {
  throw UnsupportedError('Cannot save $fileName on this platform.');
}
