import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:super_clipboard/super_clipboard.dart';

import '../../../../theme/app_colors.dart';
import '../../models/ai_chat_input.dart';
import '../../services/local_image_attachment_loader.dart';

class ChatInputBar extends StatefulWidget {
  const ChatInputBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isLoading,
    required this.onSend,
    required this.onNewSession,
    required this.onSettingsTap,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;
  final Future<void> Function(AiChatInput input) onSend;
  final VoidCallback onNewSession;
  final VoidCallback onSettingsTap;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  static const double _kInputBoxHeight = 104;

  AiImageAttachment? _imageAttachment;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
      child: SizedBox(
        height: _kInputBoxHeight,
        width: double.infinity,
        child: Stack(
          children: <Widget>[
            Focus(
              onKeyEvent: _handleKeyEvent,
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                expands: true,
                minLines: null,
                maxLines: null,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: widget.isLoading ? '思考中…' : '请问倒我…',
                  hintStyle: const TextStyle(
                    color: AppColors.textHint,
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceBg,
                  contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 44),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.borderSoft),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.borderSoft),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: AppColors.borderFocused,
                    ),
                  ),
                ),
                enabled: !widget.isLoading,
              ),
            ),
            if (_imageAttachment != null) _buildImagePreview(),
            Positioned(
              right: 4,
              bottom: 4,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IconButton(
                    // 新建会话：任务进行中（loading）不可点击。
                    onPressed: widget.isLoading
                        ? null
                        : () {
                            _clearImageAttachment();
                            widget.onNewSession();
                          },
                    tooltip: '新建会话',
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedPlusSign,
                      size: 18,
                      strokeWidth: 1.5,
                    ),
                    color: AppColors.textSecondary,
                    style: _buttonStyle(32),
                  ),
                  IconButton(
                    onPressed: widget.isLoading ? null : _submit,
                    tooltip: '发送',
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedSent,
                      size: 18,
                      strokeWidth: 1.5,
                    ),
                    color: AppColors.textSecondary,
                    style: _buttonStyle(32),
                  ),
                  IconButton(
                    onPressed: widget.onSettingsTap,
                    tooltip: '模型设置',
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedAiSetting,
                      size: 15,
                      strokeWidth: 1.5,
                    ),
                    color: AppColors.textSecondary,
                    style: _buttonStyle(28),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  ButtonStyle _buttonStyle(double size) {
    return IconButton.styleFrom(
      minimumSize: Size(size, size),
      maximumSize: Size(size, size),
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  Widget _buildImagePreview() {
    final AiImageAttachment attachment = _imageAttachment!;
    return Positioned(
      left: 8,
      bottom: 6,
      child: Tooltip(
        message: attachment.label ?? '已附加图片',
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.memory(
                attachment.bytes,
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
            Positioned(
              right: -7,
              top: -7,
              child: InkWell(
                onTap: _clearImageAttachment,
                borderRadius: BorderRadius.circular(10),
                child: const Icon(
                  Icons.cancel,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.keyV) {
      return KeyEventResult.ignored;
    }
    final bool pasteShortcut =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (!pasteShortcut || widget.isLoading) {
      return KeyEventResult.ignored;
    }
    unawaited(_pasteClipboardContent());
    return KeyEventResult.handled;
  }

  Future<void> _pasteClipboardContent() async {
    final SystemClipboard? clipboard = SystemClipboard.instance;
    if (clipboard == null) {
      return;
    }

    try {
      final ClipboardReader reader = await clipboard.read();
      for (final FileFormat format in <FileFormat>[
        Formats.png,
        Formats.jpeg,
        Formats.webp,
        Formats.gif,
        Formats.bmp,
        Formats.tiff,
      ]) {
        if (!reader.canProvide(format)) {
          continue;
        }
        final Uint8List? bytes = await _readClipboardFile(reader, format);
        if (bytes == null || bytes.isEmpty) {
          continue;
        }
        if (!mounted) {
          return;
        }
        setState(() {
          _imageAttachment = AiImageAttachment(
            bytes: bytes,
            mimeType: _mimeTypeForFormat(format),
            label: '剪贴板图片',
          );
        });
        return;
      }

      final String? text = await reader.readValue(Formats.plainText);
      if (text != null && text.isNotEmpty) {
        final AiImageAttachment? attachment =
            await LocalImageAttachmentLoader.load(text);
        if (attachment != null) {
          if (!mounted) {
            return;
          }
          setState(() {
            _imageAttachment = attachment;
          });
          return;
        }
        _insertPastedText(text);
      }
    } catch (_) {
      // 剪贴板内容可能由系统延迟生成；读取失败时保留输入框原内容。
    }
  }

  Future<Uint8List?> _readClipboardFile(
    ClipboardReader reader,
    FileFormat format,
  ) {
    final Completer<Uint8List?> completer = Completer<Uint8List?>();
    final ReadProgress? progress = reader.getFile(
      format,
      (DataReaderFile file) async {
        try {
          completer.complete(await file.readAll());
        } catch (error) {
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        }
      },
      onError: (Object error) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
    );
    if (progress == null) {
      completer.complete(null);
    }
    return completer.future;
  }

  void _insertPastedText(String text) {
    final TextEditingValue value = widget.controller.value;
    final TextSelection selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    final String nextText = value.text.replaceRange(
      selection.start,
      selection.end,
      text,
    );
    widget.controller.value = value.copyWith(
      text: nextText,
      selection: TextSelection.collapsed(offset: selection.start + text.length),
      composing: TextRange.empty,
    );
  }

  Future<void> _submit() async {
    if (widget.isLoading) {
      return;
    }

    String text = widget.controller.text.trim();
    AiImageAttachment? attachment = _imageAttachment;
    if (attachment == null && text.isNotEmpty) {
      attachment = await LocalImageAttachmentLoader.load(text);
      if (attachment != null) {
        text = '';
      }
    }
    if (text.isEmpty && attachment == null) {
      return;
    }

    widget.controller.clear();
    _clearImageAttachment();
    await widget.onSend(AiChatInput(text: text, image: attachment));
  }

  String _mimeTypeForFormat(FileFormat format) {
    if (format == Formats.jpeg) return 'image/jpeg';
    if (format == Formats.gif) return 'image/gif';
    if (format == Formats.webp) return 'image/webp';
    if (format == Formats.bmp) return 'image/bmp';
    if (format == Formats.tiff) return 'image/tiff';
    return 'image/png';
  }

  void _clearImageAttachment() {
    if (_imageAttachment == null || !mounted) {
      return;
    }
    setState(() {
      _imageAttachment = null;
    });
  }
}
