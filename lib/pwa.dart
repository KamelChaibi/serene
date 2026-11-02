// Platform-neutral entry point for the handful of PWA checks Serene needs.
//
// The web implementation is selected by a conditional import, so the app can
// still be built for Android/iOS without pulling in `package:web`.
export 'pwa_stub.dart' if (dart.library.js_interop) 'pwa_web.dart';
