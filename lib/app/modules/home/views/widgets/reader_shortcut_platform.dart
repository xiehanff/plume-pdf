import 'package:flutter/foundation.dart';

bool usesMetaModifier([TargetPlatform? platform]) {
  return (platform ?? defaultTargetPlatform) == TargetPlatform.macOS;
}

String primaryShortcutModifierLabel([TargetPlatform? platform]) {
  return usesMetaModifier(platform) ? 'Command' : 'Ctrl';
}
