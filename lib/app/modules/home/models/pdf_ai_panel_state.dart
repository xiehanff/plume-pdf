enum AiProvider {
  deepseek,
  siliconFlow,
}

class PdfAiPanelState {
  const PdfAiPanelState({
    this.apiKey = '',
    this.siliconFlowApiKey = '',
    this.selectedProvider = AiProvider.deepseek,
    this.loading = false,
    this.sessionId = 0,
    this.actionLabel,
    this.actionId,
    this.result,
    this.errorMessage,
  });

  final String apiKey;
  final String siliconFlowApiKey;
  final AiProvider selectedProvider;
  final bool loading;
  final int sessionId;
  final String? actionLabel;
  final int? actionId;
  final String? result;
  final String? errorMessage;

  PdfAiPanelState copyWith({
    String? apiKey,
    String? siliconFlowApiKey,
    AiProvider? selectedProvider,
    bool? loading,
    int? sessionId,
    Object? actionLabel = _sentinel,
    Object? actionId = _sentinel,
    Object? result = _sentinel,
    Object? errorMessage = _sentinel,
  }) {
    return PdfAiPanelState(
      apiKey: apiKey ?? this.apiKey,
      siliconFlowApiKey: siliconFlowApiKey ?? this.siliconFlowApiKey,
      selectedProvider: selectedProvider ?? this.selectedProvider,
      loading: loading ?? this.loading,
      sessionId: sessionId ?? this.sessionId,
      actionLabel: identical(actionLabel, _sentinel)
          ? this.actionLabel
          : actionLabel as String?,
      actionId: identical(actionId, _sentinel)
          ? this.actionId
          : actionId as int?,
      result: identical(result, _sentinel) ? this.result : result as String?,
      errorMessage: identical(errorMessage, _sentinel)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

const Object _sentinel = Object();
