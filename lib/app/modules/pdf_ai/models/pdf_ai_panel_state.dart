class PdfAiPanelState {
  const PdfAiPanelState({
    this.apiKey = '',
    this.loading = false,
  });

  final String apiKey;

  /// Host-side PDF/OCR preflight only.
  ///
  /// Generic chat preparation, streaming, result, reasoning and error state are
  /// owned by `AiChatController` in `plume_ai_chat`.
  final bool loading;

  PdfAiPanelState copyWith({
    String? apiKey,
    bool? loading,
  }) {
    return PdfAiPanelState(
      apiKey: apiKey ?? this.apiKey,
      loading: loading ?? this.loading,
    );
  }
}
