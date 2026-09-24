// Selects the right Drift connection for the current platform at compile time,
// so the app builds for both mobile and web.
export 'unsupported.dart'
    if (dart.library.io) 'native.dart'
    if (dart.library.js_interop) 'web.dart';
