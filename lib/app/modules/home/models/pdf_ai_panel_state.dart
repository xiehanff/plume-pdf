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
    this.errorMessage,
  });

  final String apiKey;
  final bool loading;
  final int sessionId;
  final String? actionLabel;
  final int? actionId;

  /// 触发动作时框选区域识别出的文本（用于用户气泡展示）。
  final String? actionSelectionText;

  /// 触发动作时框选区域的截图（PNG，用于用户气泡展示）。
  final Uint8List? actionSelectionImage;

  final String? result;
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
      errorMessage: identical(errorMessage, _sentinel)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

const Object _sentinel = Object();
