import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/ai_sidebar_controller.dart';
import '../controllers/home_controller.dart';
import '../../../theme/app_colors.dart';
import 'widgets/ai_sidebar.dart';

class MobileAiView extends GetView<HomeController> {
  const MobileAiView({super.key});

  @override
  Widget build(BuildContext context) {
    _ensureAiController(controller);
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: const Text('AI'),
        backgroundColor: AppColors.scaffoldBg,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: GetBuilder<HomeController>(
          id: HomeController.viewId,
          builder: (HomeController homeController) {
            _scheduleAiStateSync(homeController);
            return const AiSidebar(fullWidth: true);
          },
        ),
      ),
    );
  }

  AiSidebarController _ensureAiController(HomeController homeController) {
    if (Get.isRegistered<AiSidebarController>(tag: AiSidebarController.tag)) {
      return Get.find<AiSidebarController>(tag: AiSidebarController.tag);
    }
    return Get.put<AiSidebarController>(
      AiSidebarController(
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

  void _scheduleAiStateSync(HomeController homeController) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!Get.isRegistered<AiSidebarController>(tag: AiSidebarController.tag)) {
        return;
      }
      Get.find<AiSidebarController>(
        tag: AiSidebarController.tag,
      ).updateExternalState(
        state: homeController.state.aiPanelState,
        onApiKeyChanged: homeController.updateAiApiKey,
        onSaveApiKey: homeController.saveAiApiKey,
        onSendChat: homeController.sendAiChat,
        onNewSession: homeController.startNewAiSession,
        documentPath: homeController.state.filePath,
        leftSidebarWidth: 0,
      );
    });
  }
}
