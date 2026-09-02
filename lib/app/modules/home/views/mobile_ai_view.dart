import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import 'widgets/ai_sidebar.dart';

class MobileAiView extends StatelessWidget {
  const MobileAiView({super.key});

  @override
  Widget build(BuildContext context) {
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
          padding: EdgeInsets.only(bottom: 20),
          child: AiSidebar(fullWidth: true),
        ),
      ),
    );
  }
}
