import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/ai_sidebar_controller.dart';
import '../controllers/home_controller.dart';
import '../controllers/streaming_ai_sidebar_controller.dart';
import '../../../theme/app_colors.dart';
import 'widgets/ai_sidebar.dart';

class MobileAiView extends GetView<HomeController> {
  const MobileAiView({super.key});

  @override
  Widget build(BuildContext context) {
    // 路由打开时确保侧栏控制器已注册（会话历史在路由关闭后仍保留）。
    // 后续状态统一由 HomeController._applyState → updateExternalState
    // 单向同步，本视图不再监听 HomeController 重复同步，避免流式期间
    // 每个状态变更触发多次侧栏全量重建。
    _ensureAiController(controller);
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: const Text('AI'),
        backgroundColor: AppColors.scaffoldBg,
        surfaceTintColor: Colors.transparent,
      ),
      body: const SafeArea(
        top: false,
        child: Padding(
          // SafeArea 先避开系统底部区域，再额外保留 20px。
          // 某些 Android 设备 bottom padding 为 0，也能保证输入框
          // 不会直接贴到屏幕底边。
          padding: EdgeInsets.only(bottom: 20),
          child: AiSidebar(fullWidth: true),
        ),
      ),
    );
  }

  AiSidebarController _ensureAiController(HomeController homeController) {
    if (Get.isRegistered<AiSidebarController>(tag: AiSidebarController.tag)) {
      return Get.find<AiSidebarController>(tag: AiSidebarController.tag);
    }
    return Get.put<AiSidebarController>(
      StreamingAiSidebarController(
        state: homeController.state.aiPanelState,
        onApiKeyChanged: homeController.updateAiApiKey,
        onSaveApiKey: homeController.saveAiApiKey,
        onSendChat: homeController.sendAiChat,
        onNewSession: homeController.startNewAiSession,
        documentPath: homeController.state.filePath,
        leftSidebarWidth: 0,
      ),
      tag: AiSidebarController.tag,
    );
  }
}
