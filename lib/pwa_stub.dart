/// Non-web fallback for [pwa.dart]. Native builds have no browser install
/// flow, so every check is false.
bool get isIosDevice => false;

bool get isStandalone => false;

bool get shouldSuggestInstall => false;
