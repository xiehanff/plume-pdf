import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../modules/home/bindings/home_binding.dart';
import '../modules/home/views/home_view.dart';
import '../modules/home/views/widgets/debug_gallery_view.dart';

part 'app_routes.dart';

class AppPages {
  AppPages._();

  static const initial = Routes.home;

  static final routes = [
    GetPage(
      name: _Paths.home,
      page: () => const HomeView(),
      binding: HomeBinding(),
    ),
    if (kDebugMode)
      GetPage(
        name: _Paths.debugGallery,
        page: () => const DebugGalleryView(),
      ),
  ];
}
