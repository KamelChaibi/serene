import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// iOS exposes `navigator.standalone` on Home Screen web apps, but it is not
/// part of the standard `Navigator` interface in `package:web`.
@JS('navigator')
external _BrowserNavigator get _navigator;

extension type _BrowserNavigator(JSObject _) implements JSObject {
  external bool? get standalone;
}

/// True on iPhone/iPad/iPod, including iPadOS 13+ which reports a desktop
/// Mac user agent but still has a touch screen.
bool get isIosDevice {
  final userAgent = web.window.navigator.userAgent;
  final ios = userAgent.contains('iPhone') ||
      userAgent.contains('iPad') ||
      userAgent.contains('iPod');
  final ipadDesktopMode =
      userAgent.contains('Macintosh') && web.window.navigator.maxTouchPoints > 1;
  return ios || ipadDesktopMode;
}

/// True when Serene was opened from the Home Screen rather than a browser tab.
bool get isStandalone =>
    web.window.matchMedia('(display-mode: standalone)').matches ||
    (_navigator.standalone ?? false);

/// iOS has no automatic install prompt: adding to the Home Screen is a manual
/// Safari Share-menu action. Show a gentle hint until it has been done.
bool get shouldSuggestInstall => isIosDevice && !isStandalone;
