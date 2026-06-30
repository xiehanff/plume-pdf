import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

class AiModelConfig {
  const AiModelConfig({
    required this.modelId,
    required this.provider,
    required this.label,
    required this.supportsVision,
  });

  final String modelId;
  final String provider;
  final String label;
  final bool supportsVision;

  factory AiModelConfig.fromJson(Map<String, dynamic> json) {
    return AiModelConfig(
      modelId: json['id'] as String,
      provider: json['provider'] as String,
      label: json['label'] as String,
      supportsVision: json['supportsVision'] as bool,
    );
  }
}

class AiModelRegistry {
  AiModelRegistry._(this.models);

  final List<AiModelConfig> models;

  static AiModelRegistry _instance = AiModelRegistry._(const <AiModelConfig>[]);
  static AiModelRegistry get instance => _instance;

  static Future<void> initialize() async {
    final String json = await rootBundle.loadString('assets/config/ai_models.json');
    final Map<String, dynamic> data = jsonDecode(json) as Map<String, dynamic>;
    final List<dynamic> list = data['models'] as List<dynamic>;
    final List<AiModelConfig> models = list
        .map((dynamic e) => AiModelConfig.fromJson(e as Map<String, dynamic>))
        .toList();
    _instance = AiModelRegistry._(models);
  }

  AiModelConfig? configFor(String modelId) {
    for (final AiModelConfig config in models) {
      if (config.modelId == modelId) return config;
    }
    return null;
  }
}
