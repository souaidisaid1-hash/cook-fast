import 'dart:convert';

class TranslatedContent {
  final String recipeId;
  final String title;
  final List<String> steps;
  final List<String> ingredients;

  const TranslatedContent({
    required this.recipeId,
    required this.title,
    required this.steps,
    required this.ingredients,
  });

  Map<String, dynamic> toJson() => {
        'recipeId': recipeId,
        'title': title,
        'steps': steps,
        'ingredients': ingredients,
      };

  factory TranslatedContent.fromJson(Map<String, dynamic> json) => TranslatedContent(
        recipeId: json['recipeId']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        steps: List<String>.from(json['steps'] ?? []),
        ingredients: List<String>.from(json['ingredients'] ?? []),
      );

  static TranslatedContent? tryParseFromHive(dynamic raw) {
    if (raw == null) return null;
    try {
      return TranslatedContent.fromJson(Map<String, dynamic>.from(jsonDecode(raw as String)));
    } catch (_) {
      return null;
    }
  }
}
