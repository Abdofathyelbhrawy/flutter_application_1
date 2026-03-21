// screens/onboarding_web.dart
// Web implementation using browser localStorage
import 'dart:js_interop';
import 'package:web/web.dart' as web;

bool isOnboardingDone() {
  try {
    return web.window.localStorage.getItem('web_onboarding_done') == 'true';
  } catch (_) {
    return false;
  }
}

void markOnboardingDone() {
  try {
    web.window.localStorage.setItem('web_onboarding_done', 'true');
  } catch (_) {}
}
