import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

/// Thin client for the GROQ chat-completions API.
///
/// Only does transport: send a prompt, walk the model fallback list, return
/// the text or `null`. Roast prompts, fallbacks and provider routing live in
/// `RoastAiService`.
class GroqService {
  GroqService._();

  static const _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';

  // Model hierarchy
  static const _primaryModel = 'openai/gpt-oss-120b';
  static const _fallbackModel = 'qwen/qwen3.6-27b';

  // Weekly reports: Deep reasoning first, then fast fallbacks
  static const _weeklyModels = [_primaryModel, _fallbackModel];
  // Quick instant roasts: OpenAI OSS 120B primary, Qwen 3.6 fallback
  static const _quickModels = [_primaryModel, _fallbackModel];

  static final _dio =
      Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 10),
          ),
        )
        ..interceptors.add(
          PrettyDioLogger(
            requestHeader: true,
            requestBody: true,
            responseBody: true,
            responseHeader: false,
            error: true,
            compact: true,
            maxWidth: 90,
          ),
        );

  static String? get _apiKey {
    final key = dotenv.env['GROQ_API'];
    return (key == null || key.isEmpty) ? null : key;
  }

  static bool get isConfigured => _apiKey != null;

  /// Sends [system] + [user] to GROQ and returns the cleaned response text,
  /// or `null` if no key is configured or every model fails.
  /// Set [weekly] to use the weekly-report model list.
  static Future<String?> complete({
    required String system,
    required String user,
    required double temperature,
    required int maxTokens,
    bool weekly = false,
  }) async {
    final apiKey = _apiKey;
    if (apiKey == null) return null;

    return _postChatCompletion(
      apiKey: apiKey,
      models: weekly ? _weeklyModels : _quickModels,
      messages: [
        {'role': 'system', 'content': system},
        {'role': 'user', 'content': user},
      ],
      temperature: temperature,
      maxTokens: maxTokens,
    );
  }

  /// Cleans any reasoning / thinking tokens or unclosed tags from the model output.
  static String _cleanRoast(String text) {
    // Strip closed <think>...</think> blocks
    var cleaned = text
        .replaceAll(RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false), '')
        .trim();
    // If unclosed <think> exists (e.g. truncated), remove everything after <think>
    if (cleaned.contains(RegExp(r'<think>', caseSensitive: false))) {
      cleaned = cleaned
          .replaceAll(RegExp(r'<think>[\s\S]*', caseSensitive: false), '')
          .trim();
    }
    return cleaned;
  }

  /// Helper to post chat completions with automatic model fallback
  static Future<String?> _postChatCompletion({
    required String apiKey,
    required List<String> models,
    required List<Map<String, String>> messages,
    required double temperature,
    required int maxTokens,
  }) async {
    for (final model in models) {
      try {
        final body = <String, dynamic>{
          'model': model,
          'messages': messages,
          'temperature': temperature,
          'max_tokens': maxTokens,
        };

        // Suppress CoT / reasoning think tags for reasoning models
        if (model.contains('gpt-oss') ||
            model.contains('qwen') ||
            model.contains('deepseek') ||
            model.contains('r1')) {
          body['reasoning_format'] = 'hidden';
          if (model.contains('qwen')) {
            body['reasoning_effort'] = 'none';
          } else if (model.contains('gpt-oss')) {
            body['reasoning_effort'] = 'low';
          }
        }

        final response = await _dio.post<Map<String, dynamic>>(
          _baseUrl,
          options: Options(
            headers: {
              HttpHeaders.authorizationHeader: 'Bearer $apiKey',
              HttpHeaders.contentTypeHeader: 'application/json',
            },
          ),
          data: body,
        );

        final content =
            response.data?['choices']?[0]?['message']?['content'] as String?;
        if (content != null && content.trim().isNotEmpty) {
          final cleaned = _cleanRoast(content);
          if (cleaned.isNotEmpty) {
            return cleaned;
          }
        }
      } catch (_) {
        // Try next fallback model in the list
        continue;
      }
    }
    return null;
  }
}
