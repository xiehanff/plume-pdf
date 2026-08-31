import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:window_manager/window_manager.dart';

import 'app/routes/app_pages.dart';
import 'app/services/app_launch_args.dart';
import 'app/theme/app_colors.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLaunchArgs.setArgs(args);

  if (_isDesktopPlatform) {
    await windowManager.ensureInitialized();
    final windowOptions = WindowOptions(
      size: const Size(1280, 840),
      minimumSize: const Size(800, 600),
      center: true,
      title: 'Plume PDF',
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: defaultTargetPlatform == TargetPlatform.macOS,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(const MyApp());
}

bool get _isDesktopPlatform {
  if (kIsWeb) {
    return false;
  }
  return switch (defaultTargetPlatform) {
    TargetPlatform.windows ||
    TargetPlatform.macOS ||
    TargetPlatform.linux => true,
    _ => false,
  };
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Plume PDF',
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'OPPO Sans',
        fontFamilyFallback: const [
          'Microsoft YaHei',
          'Microsoft YaHei UI',
          '微软雅黑',
        ],
        scaffoldBackgroundColor: AppColors.scaffoldBg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.seed,
          brightness: Brightness.dark,
        ),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        useMaterial3: true,
      ),
      initialRoute: AppPages.initial,
      getPages: AppPages.routes,
    );
  }
}
