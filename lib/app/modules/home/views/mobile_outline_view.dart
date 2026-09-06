import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../reader/models/pdf_outline_entry.dart';
import '../../reader/views/widgets/reader_sidebar.dart';
import '../controllers/home_controller.dart';
import '../../../theme/app_colors.dart';

class MobileOutlineView extends GetView<HomeController> {
  const MobileOutlineView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: const Text('目录'),
        backgroundColor: AppColors.scaffoldBg,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: GetBuilder<HomeController>(
          id: HomeController.viewId,
          builder: (HomeController controller) {
            return ReaderSidebar(
              fullWidth: true,
              outline: controller.state.outline,
              selectedOutlineId: controller.state.selectedOutlineId,
              onOpenOutlinePage: (PdfOutlineEntry entry) {
                controller.jumpToOutlinePage(entry);
                Get.back<void>();
              },
            );
          },
        ),
      ),
    );
  }
}
