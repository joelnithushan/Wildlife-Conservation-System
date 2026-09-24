import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Browser download for the same bytes the mobile saver writes to a file.
Future<String> saveReportBytes(String fileName, List<int> bytes) async {
  final mime =
      fileName.endsWith('.csv') ? 'text/csv;charset=utf-8' : 'application/pdf';
  final href = 'data:$mime;base64,${base64Encode(bytes)}';
  final document = globalContext.getProperty<JSObject>('document'.toJS);
  final body = document.getProperty<JSObject>('body'.toJS);
  final anchor = document.callMethod<JSObject>('createElement'.toJS, 'a'.toJS);
  anchor.setProperty('href'.toJS, href.toJS);
  anchor.setProperty('download'.toJS, fileName.toJS);
  body.callMethod('append'.toJS, anchor);
  anchor.callMethod('click'.toJS);
  anchor.callMethod('remove'.toJS);
  return fileName;
}
