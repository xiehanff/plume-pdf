import 'dart:typed_data';

class PdfAiPanelState {
  const PdfAiPanelState({
    this.apiKey = '',
    this.loading = false,
    this.sessionId = 0,
    this.actionLabel,
    this.actionId,
    this.actionSelectionText,
    this.actionSelectionImage,
    this.result,
    this.reasoning,
    this.followUpSuggestions = const <String>[],
    this.errorMessage,
  });

  final String apiKey;
  final bool loading;
  final int sessionId;
  final String? actionLabel;
  final int? actionId;
  final String? actionSelectionText;
  final Uint8List? actionSelectionImage;
  final String? result;
  final String? reasoning;
  final List<String> followUpSuggestions;
  final String? errorMessage;

  PdfAiPanelState copyWith({
    String? apiKey,
    bool? loading,
    int? sessionId,
    Object? actionLabel = _sentinel,
    Object? actionId = _sentinel,
    Object? actionSelectionText = _sentinel,
    Object? actionSelectionImage = _sentinel,
    Object? result = _sentinel,
    Object? reasoning = _sentinel,
    List<String>? followUpSuggestions,
    Object? errorMessage = _sentinel,
  }) {
    return PdfAiPanelState(
      apiKey: apiKey ?? this.apiKey,
      loading: loading ?? this.loading,
      sessionId: sessionId ?? this.sessionId,
      actionLabel: identical(actionLabel, _sentinel)
          ? this.actionLabel
          : actionLabel as String?,
      actionId: identical(actionId, _sentinel)
          ? this.actionId
          : actionId as int?,
      actionSelectionText: identical(actionSelectionText, _sentinel)
          ? this.actionSelectionText
          : actionSelectionText as String?,
      actionSelectionImage: identical(actionSelectionImage, _sentinel)
          ? this.actionSelectionImage
          : actionSelectionImage as Uint8List?,
      result: identical(result, _sentinel) ? this.result : result as String?,
      reasoning: identical(reasoning, _sentinel)
          ? this.reasoning
          : reasoning as String?,
      followUpSuggestions: followUpSuggestions ?? this.followUpSuggestions,
      errorMessage: identical(errorMessage, _sentinel)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

const Object _sentinel = Object();
