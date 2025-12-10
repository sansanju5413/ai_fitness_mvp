import 'dart:convert';

import 'package:http/http.dart' as http;

class GeminiAiService {
  GeminiAiService({required this.apiKey});

  final String apiKey;

  bool get isConfigured => apiKey.isNotEmpty;

  static const _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  Future<String> chat(String message) async {
    if (!isConfigured) {
      throw StateError('Gemini API key is not configured.');
    }

    final response = await _postToGemini(
      prompt:
          'You are a concise, friendly fitness and nutrition coach. '
          'Answer clearly in 2-4 sentences.\n\nUser: $message',
    );

    return _extractText(response);
  }

  Future<Map<String, List<String>>> generateWorkoutPlan({
    required String goal,
    required int daysPerWeek,
    String? templateName,
    String? profileSummary,
  }) async {
    if (!isConfigured) {
      throw StateError('Gemini API key is not configured.');
    }

    final contextLines = <String>[];
    if (profileSummary != null && profileSummary.trim().isNotEmpty) {
      contextLines.add('User profile: $profileSummary');
    }
    if (templateName != null && templateName.trim().isNotEmpty) {
      contextLines.add('Preferred template: $templateName.');
    }

    final contextText =
        contextLines.isEmpty ? '' : contextLines.join('\n') + '\n\n';

    final prompt = '''
${contextText}You are an expert strength and conditioning coach.
Goal: $goal (options: fat_loss, muscle_gain, general).
Create a structured $daysPerWeek-day workout plan.
Return ONLY valid JSON with this exact shape:
{"Day 1": ["exercise 1", "exercise 2"], "Day 2": ["exercise 1", "exercise 2"], ...}.
No explanations, just JSON.
''';

    final response = await _postToGemini(prompt: prompt);
    final text = _extractText(response);
    final jsonText = _extractJsonObject(text);
    final decoded = jsonDecode(jsonText) as Map<String, dynamic>;

    return decoded.map((key, value) {
      final list = (value as List).map((e) => e.toString()).toList();
      return MapEntry(key.toString(), list);
    });
  }

  Future<Map<String, dynamic>> _postToGemini({required String prompt}) async {
    final uri = Uri.parse('$_baseUrl/gemini-1.5-flash:generateContent'
        '?key=$apiKey');

    final response = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Gemini error: ${response.statusCode} ${response.body}',
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  String _extractText(Map<String, dynamic> data) {
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('Gemini returned no candidates.');
    }

    final content = candidates.first['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List?;
    if (parts == null || parts.isEmpty) {
      throw Exception('Gemini returned empty content.');
    }

    final text = parts.first['text'] as String?;
    if (text == null || text.trim().isEmpty) {
      throw Exception('Gemini returned empty text.');
    }

    return text.trim();
  }

  String _extractJsonObject(String text) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start != -1 && end != -1 && end > start) {
      return text.substring(start, end + 1);
    }
    return text;
  }
}
