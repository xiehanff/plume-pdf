export 'deepseek_service.dart' show AiToolAction;
import 'deepseek_service.dart';

class AiPrompts {
  const AiPrompts._();

  static String systemPrompt(AiToolAction action) {
    switch (action) {
      case AiToolAction.translate:
        return '你是一个专业翻译。先输出译文本身（原文是中文则译为英文，原文是英文则译为简体中文），'
            '然后另起一行紧跟输出"**总结**："，用简体中文用 1-2 句话概括译文的主要内容。'
            '不要解释、不要评论、不要复述原文、不要添加其他内容。';
      case AiToolAction.explain:
        return '你是一个解释助手。请使用 Markdown 输出，先给简要解释，再用分点展开。'
            '直接输出解释，不要复述问题或提及输入形式。';
    }
  }

  static String userPrompt(AiToolAction action, String selectionText, {String? pageContext}) {
    final String actionLabel = action.label;
    if (pageContext != null && pageContext.trim().isNotEmpty) {
      if (action == AiToolAction.translate) {
        return '请将以下【框选内容】翻译为${_targetLanguage(selectionText)}，只输出译文；'
            '译文之后另起一行紧跟输出"**总结**："，用简体中文用 1-2 句话概括译文的主要内容：\n\n'
            '【框选内容】\n$selectionText\n\n'
            '【页面全文参考】\n$pageContext';
      }
      return '请$actionLabel以下【框选内容】，页面全文仅作上下文参考：\n\n【框选内容】\n$selectionText\n\n【页面全文参考】\n$pageContext';
    }
    switch (action) {
      case AiToolAction.translate:
        return '请将下面内容翻译为${_targetLanguage(selectionText)}，只输出译文，保留原意；'
            '译文之后另起一行紧跟输出"**总结**："，用简体中文用 1-2 句话概括译文的主要内容：\n\n$selectionText';
      case AiToolAction.explain:
        return '请用简洁中文解释下面内容，并补充必要背景：\n\n$selectionText';
    }
  }

  static String visionUserPrompt(AiToolAction action) {
    switch (action) {
      case AiToolAction.translate:
        return '请将框选区域图片中的文字翻译为另一种语言：图片内容是中文则译为英文，是英文则译为简体中文。'
            '直接输出译文；译文之后另起一行紧跟输出"**总结**："，用简体中文用 1-2 句话概括译文的主要内容。不要提及图片或框选。';
      case AiToolAction.explain:
        return '请用简洁中文解释框选区域的内容，并补充必要背景。直接输出解释，不要提及图片或框选。';
    }
  }

  /// 根据原文语言判断目标语言：含中文（占比 ≥ 15%）→ 英文，否则 → 简体中文。
  static String _targetLanguage(String text) {
    if (text.trim().isEmpty) {
      return '简体中文';
    }
    int chineseCount = 0;
    for (final int code in text.codeUnits) {
      if (code >= 0x4E00 && code <= 0x9FFF) {
        chineseCount++;
      }
    }
    if (chineseCount == 0) {
      return '简体中文';
    }
    final double ratio = chineseCount / text.length;
    return ratio >= 0.15 ? '英文' : '简体中文';
  }
}
