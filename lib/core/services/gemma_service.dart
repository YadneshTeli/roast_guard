import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Thin client for Google's open-weight **Gemma 4** models, served through
/// the Gemini API (`generativelanguage.googleapis.com`).
///
/// Only does transport: send a prompt, try each model in order, return the
/// text or `null`. Roast prompts, fallbacks and provider routing live in
/// `RoastAiService`.
///
/// Environment variables (.env):
/// - `GEMINI_API_KEY` (required) — key from https://aistudio.google.com/apikey
/// - `GEMMA_MODEL`    (optional) — overrides the primary model id
class GemmaService {
  GemmaService._();

  static const _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  /// MoE variant first (fast, only ~4B active params), dense 31B as fallback.
  static const _defaultModels = ['gemma-4-26b-a4b-it', 'gemma-4-31b-it'];

  static final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );

  static String? get _apiKey {
    final key = dotenv.env['GEMINI_API_KEY'];
    return (key == null || key.isEmpty) ? null : key;
  }

  static bool get isConfigured => _apiKey != null;

  static List<String> get _models {
    final override = dotenv.env['GEMMA_MODEL'];
    if (override == null || override.isEmpty) return _defaultModels;
    return [override, ..._defaultModels.where((m) => m != override)];
  }

  /// Sends [system] + [user] to Gemma and returns the response text, or
  /// `null` if no key is configured or every model fails.
  static Future<String?> complete({
    required String system,
    required String user,
    required double temperature,
    required int maxTokens,
  }) async {
    final apiKey = _apiKey;
    if (apiKey == null) return null;

    for (final model in _models) {
      try {
        final response = await _dio.post<Map<String, dynamic>>(
          '$_baseUrl/$model:generateContent',
          options: Options(
            headers: {
              'x-goog-api-key': apiKey,
              'Content-Type': 'application/json',
            },
          ),
          data: {
            // Gemma on the Gemini API has historically rejected
            // `systemInstruction`, so the persona is inlined into the turn.
            'contents': [
              {
                'role': 'user',
                'parts': [
                  {'text': '$system\n\n$user'},
                ],
              },
            ],
            'generationConfig': {
              'temperature': temperature,
              'maxOutputTokens': maxTokens,
              'thinkingConfig': {
                'thinkingBudget': 0, // Disable thinking process so it responds immediately with roast only
              },
            },
          },
        );

        final text = _extractText(response.data);
        if (text != null && text.isNotEmpty) return text;
      } catch (_) {
        // Try the next model in the list
        continue;
      }
    }
    return null;
  }

  /// Joins the non-thought text parts of the first candidate and strips any thinking tags.
  static String? _extractText(Map<String, dynamic>? data) {
    final candidates = data?['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) return null;

    final parts = candidates.first?['content']?['parts'] as List?;
    if (parts == null) return null;

    var text = parts
        .whereType<Map>()
        .where((p) => p['thought'] != true) // skip thinking-mode parts
        .map((p) => p['text'])
        .whereType<String>()
        .join()
        .trim();

    if (text.isEmpty) return null;

    // Strip any closed <think>...</think>
    text = text
        .replaceAll(RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false), '')
        .trim();

    // If unclosed <think> remains, remove thought section or drop if no clean roast left
    if (text.contains(RegExp(r'<think>', caseSensitive: false))) {
      text = text
          .replaceAll(RegExp(r'<think>[\s\S]*', caseSensitive: false), '')
          .trim();
    }

    return text.isEmpty ? null : text;
  }
}
