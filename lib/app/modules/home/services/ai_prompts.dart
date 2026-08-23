export 'deepseek_service.dart' show AiToolAction;
import 'ai_response_parser.dart';
import 'deepseek_service.dart';

class AiPrompts {
  const AiPrompts._();

  static String systemPrompt(AiToolAction action) {
    switch (action) {
      case AiToolAction.translate:
        return '你是一个专业翻译。先输出译文本身（原文是中文则译为英文，原文是英文则译为简体中文），'
            '然后另起一行紧跟输出"**总结**："，用简体中文用 1-2 句话概括译文的主要内容。'
            '不要解释、不要评论、不要复述原文、不要添加其他内容。\n\n'
            '${AiResponseParser.followUpInstruction}';
      case AiToolAction.explain:
        return '你是一个解释助手。请使用 Markdown 输出，先给简要解释，再用分点展开。'
            '直接输出解释，不要复述问题或提及输入形式。\n\n'
            '${AiResponseParser.followUpInstruction}';
      case AiToolAction.deepDive:
        return '你是一位严谨、耐心的技术讲师，把用户当作完全没有背景知识的新手，'
            '输出一篇结构完整、内容深入的 Markdown 长文讲稿。请深入思考后输出，'
            '篇幅可以较长（1000 字以上），但不要为凑字数而重复。严格遵循以下教学规则：\n'
            '1. 从一个能体现该知识点价值的真实问题或经典问题切入，先说明现有做法的痛点；简单问题无需刻意编造复杂场景。\n'
            '2. 依次讲清“为什么需要 → 它是什么 → 如何工作 → 最小示例”，再逐步增加示例复杂度。\n'
            '3. 明确它解决的问题类型、前提、优点、缺点和失败边界；不要默认它在所有场景都是最优方案。\n'
            '4. 与容易混淆或可替代的概念做对比，说明选择标准，并为关键差异提供具体例子。\n'
            '5. 概念建立后再扩展到其他应用场景；若有更合适的方案，说明为什么以及如何替换。\n'
            '6. API 只讲与主题和示例相关的部分；用户要求完整参考时，再系统列出方法、属性、参数和返回值。\n'
            '7. 涉及当前模型、产品能力、版本、价格或限制时，先查官方一手资料，并区分官方事实与推断。\n\n'
            '${AiResponseParser.followUpInstruction}';
    }
  }

  static String chatSystemPrompt() => AiResponseParser.chatSystemPrompt();

  static String userPrompt(
    AiToolAction action,
    String selectionText, {
    String? pageContext,
  }) {
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
      case AiToolAction.deepDive:
        return '请以零基础新手的视角，深入讲解以下内容。用通俗的语言、具体的例子，按上面规则把概念讲透：\n\n$selectionText';
    }
  }

  static String visionUserPrompt(AiToolAction action) {
    switch (action) {
      case AiToolAction.translate:
        return '请将框选区域图片中的文字翻译为另一种语言：图片内容是中文则译为英文，是英文则译为简体中文。'
            '直接输出译文；译文之后另起一行紧跟输出"**总结**："，用简体中文用 1-2 句话概括译文的主要内容。不要提及图片或框选。';
      case AiToolAction.explain:
        return '请用简洁中文解释框选区域的内容，并补充必要背景。直接输出解释，不要提及图片或框选。';
      case AiToolAction.deepDive:
        return '请以零基础新手的视角，深入讲解图片中框选区域的内容。用通俗的语言、具体的例子，按上面规则把内容讲透。不要提及图片或框选。';
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
