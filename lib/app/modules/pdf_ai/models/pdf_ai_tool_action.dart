/// PDF 阅读场景提供的 AI 快捷动作。
///
/// 这是 Plume 的产品领域概念，不属于具体模型 Provider，也不应该放进
/// `plume_ai_chat` 的通用 transport/runtime 层。
enum AiToolAction {
  translate('翻译'),
  explain('解释'),
  deepDive('深度理解');

  const AiToolAction(this.label);

  final String label;
}
