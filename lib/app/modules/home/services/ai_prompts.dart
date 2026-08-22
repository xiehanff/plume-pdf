export 'deepseek_service.dart' show AiToolAction;
import 'deepseek_service.dart';

class AiPrompts {
  const AiPrompts._();

  static String systemPrompt(AiToolAction action) {
    switch (action) {
      case AiToolAction.translate:
        return '你是一个翻译助手。请使用 Markdown 输出，简洁、自然、结构化。直接输出译文，不要复述问题或提及输入形式。';
      case AiToolAction.explain:
        return '你是一个解释助手。请使用 Markdown 输出，先给简要解释，再用分点展开。直接输出解释，不要复述问题或提及输入形式。';
    }
  }

  static String userPrompt(AiToolAction action, String selectionText, {String? pageContext}) {
    final String actionLabel = action.label;
    if (pageContext != null && pageContext.trim().isNotEmpty) {
      return '请$actionLabel以下【框选内容】，页面全文仅作上下文参考：\n\n【框选内容】\n$selectionText\n\n【页面全文参考】\n$pageContext';
    }
    switch (action) {
      case AiToolAction.translate:
        return '请将下面内容翻译成简体中文，并保留原意：\n\n$selectionText';
      case AiToolAction.explain:
        return '请用简洁中文解释下面内容，并补充必要背景：\n\n$selectionText';
    }
  }

  static String visionUserPrompt(AiToolAction action) {
    switch (action) {
      case AiToolAction.translate:
        return '请将框选区域的文字翻译成简体中文，保留原意。直接输出译文，不要提及图片或框选。';
      case AiToolAction.explain:
        return '请用简洁中文解释框选区域的内容，并补充必要背景。直接输出解释，不要提及图片或框选。';
    }
  }
}
