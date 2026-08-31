import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../modules/home/bindings/home_binding.dart';
import '../modules/home/views/home_view.dart';
import '../modules/home/views/mobile_ai_view.dart';
import '../modules/home/views/mobile_home_view.dart';
import '../modules/home/views/mobile_outline_view.dart';
import '../modules/home/views/mobile_wifi_transfer_view.dart';
import '../modules/home/views/widgets/debug_gallery_view.dart';

part 'app_routes.dart';

class AppPages {
  AppPages._();

  static const initial = Routes.home;

  static final routes = [
    GetPage(
      name: _Paths.home,
      page: () => _isMobilePlatform ? const MobileHomeView() : const HomeView(),
      binding: HomeBinding(),
    ),
    GetPage(name: _Paths.readerOutline, page: () => const MobileOutlineView()),
    GetPage(name: _Paths.readerAi, page: () => const MobileAiView()),
    GetPage(
      name: _Paths.wifiTransfer,
      page: () => const MobileWifiTransferView(),
    ),
    if (kDebugMode)
      GetPage(name: _Paths.debugGallery, page: () => const DebugGalleryView()),
  ];
}

bool get _isMobilePlatform {
  if (kIsWeb) {
    return false;
  }
  return switch (defaultTargetPlatform) {
    TargetPlatform.android || TargetPlatform.iOS => true,
    _ => false,
  };
}
