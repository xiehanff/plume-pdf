import 'package:flutter/material.dart';

import '../models/ai_chat_input.dart';
import '../models/pdf_ai_panel_state.dart';
import 'ai_sidebar_controller.dart';

/// 兼容旧构造入口；流式 rebuild 抑制现已由 [AiSidebarController] 直接负责。
class StreamingAiSidebarController extends AiSidebarController {
  StreamingAiSidebarController({
    required PdfAiPanelState state,
    required ValueChanged<String> onApiKeyChanged,
    required Future<void> Function() onSaveApiKey,
    required SendChatCallback onSendChat,
    required VoidCallback onNewSession,
    String? documentPath,
    double leftSidebarWidth = 0,
  }) : super(
         state: state,
         onApiKeyChanged: onApiKeyChanged,
         onSaveApiKey: onSaveApiKey,
         onSendChat: onSendChat,
         onNewSession: onNewSession,
         documentPath: documentPath,
         leftSidebarWidth: leftSidebarWidth,
       );
}
