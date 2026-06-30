import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../theme/app_colors.dart';
import '../../models/pdf_ai_panel_state.dart';
import '../../services/ai_model_config.dart';
import '../../services/deepseek_service.dart';
import '../../services/silicon_flow_service.dart';

class AiSidebarSettingsHeader extends StatelessWidget {
  const AiSidebarSettingsHeader({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 5, 12, 5),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: onBack,
            tooltip: '返回',
            style: IconButton.styleFrom(
              minimumSize: const Size(30, 30),
              maximumSize: const Size(30, 30),
              padding: EdgeInsets.zero,
              foregroundColor: AppColors.textSecondary,
            ),
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedArrowLeft01,
              size: 16,
              strokeWidth: 1.5,
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            '设置',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class AiSidebarSettingsList extends StatelessWidget {
  const AiSidebarSettingsList({
    super.key,
    required this.deepSeekController,
    required this.siliconFlowController,
    required this.selectedProvider,
    required this.onDeepSeekChanged,
    required this.onSiliconFlowChanged,
    required this.onProviderChanged,
    required this.onSaveDeepSeek,
    required this.onSaveSiliconFlow,
  });

  final TextEditingController deepSeekController;
  final TextEditingController siliconFlowController;
  final AiProvider selectedProvider;
  final ValueChanged<String> onDeepSeekChanged;
  final ValueChanged<String> onSiliconFlowChanged;
  final ValueChanged<AiProvider> onProviderChanged;
  final VoidCallback onSaveDeepSeek;
  final VoidCallback onSaveSiliconFlow;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 18),
      children: <Widget>[
        _ProviderSelector(
          selectedProvider: selectedProvider,
          onChanged: onProviderChanged,
        ),
        ApiKeyCard(
          title: 'DeepSeek',
          hintText: '输入 DeepSeek API Key',
          controller: deepSeekController,
          onChanged: onDeepSeekChanged,
          onSave: onSaveDeepSeek,
        ),
        ApiKeyCard(
          title: '硅基流动 (SiliconFlow)',
          hintText: '输入硅基流动 API Key',
          controller: siliconFlowController,
          onChanged: onSiliconFlowChanged,
          onSave: onSaveSiliconFlow,
        ),
      ],
    );
  }
}

class _ProviderSelector extends StatelessWidget {
  const _ProviderSelector({
    required this.selectedProvider,
    required this.onChanged,
  });

  final AiProvider selectedProvider;
  final ValueChanged<AiProvider> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.fillSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '当前 AI 模型',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<AiProvider>(
            value: selectedProvider,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.fieldBg,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
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
                borderSide: const BorderSide(color: AppColors.borderFocused),
              ),
            ),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
            ),
            dropdownColor: AppColors.surfaceBg,
            items: _buildItems(),
            onChanged: (AiProvider? value) {
              if (value != null) {
                onChanged(value);
              }
            },
          ),
        ],
      ),
    );
  }

  List<DropdownMenuItem<AiProvider>> _buildItems() {
    final List<DropdownMenuItem<AiProvider>> items = <DropdownMenuItem<AiProvider>>[];
    for (final AiProvider provider in AiProvider.values) {
      final String modelId = provider == AiProvider.siliconFlow
          ? SiliconFlowService.model
          : DeepSeekService.model;
      final AiModelConfig? config = AiModelRegistry.instance.configFor(modelId);
      final String label = config?.label ?? provider.name;
      items.add(DropdownMenuItem<AiProvider>(
        value: provider,
        child: Text(label),
      ));
    }
    return items;
  }
}

class ApiKeyCard extends StatefulWidget {
  const ApiKeyCard({
    super.key,
    required this.title,
    required this.hintText,
    required this.controller,
    required this.onChanged,
    required this.onSave,
  });

  final String title;
  final String hintText;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onSave;

  @override
  State<ApiKeyCard> createState() => _ApiKeyCardState();
}

class _ApiKeyCardState extends State<ApiKeyCard> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.fillSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            widget.title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: widget.controller,
            onChanged: widget.onChanged,
            obscureText: _obscure,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
            ),
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: const TextStyle(
                color: AppColors.textHint,
                fontSize: 13,
              ),
              filled: true,
              fillColor: AppColors.fieldBg,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
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
                borderSide: const BorderSide(color: AppColors.borderFocused),
              ),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                tooltip: _obscure ? '显示' : '隐藏',
                icon: HugeIcon(
                  icon: _obscure
                      ? HugeIcons.strokeRoundedViewOffSlash
                      : HugeIcons.strokeRoundedView,
                  size: 16,
                  strokeWidth: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: widget.onSave,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accentSurface,
                foregroundColor: AppColors.textPrimary,
              ),
              child: const Text('保存'),
            ),
          ),
        ],
      ),
    );
  }
}
