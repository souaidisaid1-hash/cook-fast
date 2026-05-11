import 'dart:convert';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../../core/constants/api_constants.dart';
import '../models/recipe.dart';
import '../models/translated_content.dart';
import '../models/user_profile.dart';

class GeminiService {
  static void _report(Object e, StackTrace s) =>
      Sentry.captureException(e, stackTrace: s);
  static GenerativeModel? _model;
  static GenerativeModel? _visionModel;

  static GenerativeModel get _chat {
    _model ??= GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: ApiConstants.geminiKey,
    );
    return _model!;
  }

  static GenerativeModel get _vision {
    _visionModel ??= GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: ApiConstants.geminiKey,
    );
    return _visionModel!;
  }

  // ─── Nutrition ──────────────────────────────────────────────────────────────

  static Future<Map<String, int>?> estimateNutrition(List<String> ingredients, List<String> measures) async {
    try {
      final ingredientList = List.generate(
        ingredients.length,
        (i) => '${measures.elementAtOrNull(i) ?? ''} ${ingredients[i]}'.trim(),
      ).join(', ');

      final response = await _chat.generateContent([
        Content.text(
          'Estime les valeurs nutritionnelles TOTALES pour cette recette avec ces ingrédients : $ingredientList. '
          'Réponds UNIQUEMENT en JSON sans texte autour : {"calories": X, "protein": X, "carbs": X, "fat": X} '
          'avec des nombres entiers. Valeurs pour la recette entière.',
        ),
      ]);

      final text = response.text ?? '';
      final jsonStr = RegExp(r'\{.*\}', dotAll: true).firstMatch(text)?.group(0);
      if (jsonStr == null) return null;
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      return {
        'calories': (data['calories'] as num?)?.toInt() ?? 0,
        'protein': (data['protein'] as num?)?.toInt() ?? 0,
        'carbs': (data['carbs'] as num?)?.toInt() ?? 0,
        'fat': (data['fat'] as num?)?.toInt() ?? 0,
      };
    } catch (e, s) { _report(e, s);
      return null;
    }
  }

  // ─── Mood → Recettes ────────────────────────────────────────────────────────

  static Future<List<String>> recipesForMood(String mood, UserProfile profile) async {
    try {
      final prompt = '''
Tu es un chef cuisinier expert. Suggère 6 noms de recettes adaptées à quelqu'un qui se sent "$mood".
Profil : régime ${profile.dietLabel}, ${profile.persons} personne(s), objectif ${profile.goalLabel}.
Réponds UNIQUEMENT avec un tableau JSON de noms de recettes en anglais (pour la recherche API) : ["recipe1", "recipe2", ...]
''';
      final response = await _chat.generateContent([Content.text(prompt)]);
      final text = response.text ?? '';
      final jsonStr = RegExp(r'\[.*\]', dotAll: true).firstMatch(text)?.group(0);
      if (jsonStr == null) return [];
      return List<String>.from(jsonDecode(jsonStr));
    } catch (e, s) { _report(e, s);
      return [];
    }
  }

  // ─── Plan semaine ───────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> generateWeekPlan(
    UserProfile profile, {
    void Function(int progress)? onProgress,
  }) async {
    try {
      onProgress?.call(10);
      // ignore: avoid_print
      print('[Gemini] Starting generateWeekPlan...');
      final prompt = '''
Génère un plan de repas pour une semaine complète.
Profil : régime ${profile.dietLabel}, ${profile.persons} personne(s), objectif ${profile.goalLabel}, budget ${profile.weeklyBudget}€/semaine.

Réponds UNIQUEMENT en JSON (sans texte autour) avec cette structure exacte :
{
  "Lundi": {"Petit-déj": "nom_recette_anglais", "Déjeuner": "nom_recette_anglais", "Dîner": "nom_recette_anglais"},
  "Mardi": {...},
  "Mercredi": {...},
  "Jeudi": {...},
  "Vendredi": {...},
  "Samedi": {...},
  "Dimanche": {...}
}
Utilise des noms de recettes simples en anglais pour faciliter la recherche (ex: "Chicken Pasta", "Beef Stew").
''';
      onProgress?.call(30);
      final response = await _chat.generateContent([Content.text(prompt)]);
      onProgress?.call(70);
      final text = response.text ?? '';
      // ignore: avoid_print
      print('[Gemini] Raw response (first 500 chars): ${text.length > 500 ? text.substring(0, 500) : text}');
      final jsonStr = RegExp(r'\{.*\}', dotAll: true).firstMatch(text)?.group(0);
      if (jsonStr == null) {
        // ignore: avoid_print
        print('[Gemini] JSON parsing failed — no {} found in response');
        return null;
      }
      onProgress?.call(90);
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e, s) {
      _report(e, s);
      return null;
    }
  }

  // ─── Suggestion repas unique ─────────────────────────────────────────────────

  static Future<String?> suggestMeal(UserProfile profile, String slot) async {
    try {
      final prompt = 'Suggère un nom de recette en anglais pour le "$slot" adapté à : '
          'régime ${profile.dietLabel}, ${profile.persons} personne(s). '
          'Réponds UNIQUEMENT avec le nom de la recette, rien d\'autre.';
      final response = await _chat.generateContent([Content.text(prompt)]);
      return response.text?.trim();
    } catch (e, s) { _report(e, s);
      return null;
    }
  }

  // ─── Vision frigo ────────────────────────────────────────────────────────────

  static Future<List<String>> recognizeIngredients(Uint8List imageBytes) async {
    try {
      final response = await _vision.generateContent([
        Content.multi([
          TextPart(
            'Liste tous les ingrédients alimentaires visibles dans cette image de frigo/placard. '
            'Réponds UNIQUEMENT avec un tableau JSON de noms d\'ingrédients en français : '
            '["ingredient1", "ingredient2", ...]. Maximum 15 ingrédients.',
          ),
          DataPart('image/jpeg', imageBytes),
        ]),
      ]);
      final text = response.text ?? '';
      final jsonStr = RegExp(r'\[.*\]', dotAll: true).firstMatch(text)?.group(0);
      if (jsonStr == null) return [];
      return List<String>.from(jsonDecode(jsonStr));
    } catch (e, s) { _report(e, s);
      return [];
    }
  }

  // ─── Suggestions depuis frigo ────────────────────────────────────────────────

  static Future<List<String>> suggestFromFridge(
      List<String> ingredients, UserProfile profile) async {
    try {
      final prompt = 'J\'ai ces ingrédients : ${ingredients.join(', ')}. '
          'Profil : régime ${profile.dietLabel}, ${profile.persons} personne(s), objectif ${profile.goalLabel}. '
          'Suggère 5 noms de recettes que je peux faire avec ces ingrédients. '
          'Réponds UNIQUEMENT en tableau JSON de noms en anglais : ["recipe1", ...]';
      final response = await _chat.generateContent([Content.text(prompt)]);
      final text = response.text ?? '';
      final jsonStr = RegExp(r'\[.*\]', dotAll: true).firstMatch(text)?.group(0);
      if (jsonStr == null) return [];
      return List<String>.from(jsonDecode(jsonStr));
    } catch (e, s) { _report(e, s);
      return [];
    }
  }

  // ─── Plan semaine depuis frigo ────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> generateWeekPlanFromFridge(
    List<String> fridgeIngredients,
    UserProfile profile, {
    void Function(int progress)? onProgress,
  }) async {
    try {
      onProgress?.call(10);
      final prompt = '''
Génère un plan de repas pour une semaine complète en utilisant au maximum ces ingrédients du frigo : ${fridgeIngredients.join(', ')}.

Profil : régime ${profile.dietLabel}, ${profile.persons} personne(s), objectif ${profile.goalLabel}, budget ${profile.weeklyBudget}€/semaine.

Privilégie les recettes qui utilisent les ingrédients disponibles. Tu peux suggérer des recettes nécessitant quelques ingrédients supplémentaires simples.

Réponds UNIQUEMENT en JSON (sans texte autour) avec cette structure exacte :
{
  "Lundi": {"Petit-déj": "nom_recette_anglais", "Déjeuner": "nom_recette_anglais", "Dîner": "nom_recette_anglais"},
  "Mardi": {"Petit-déj": "...", "Déjeuner": "...", "Dîner": "..."},
  "Mercredi": {"Petit-déj": "...", "Déjeuner": "...", "Dîner": "..."},
  "Jeudi": {"Petit-déj": "...", "Déjeuner": "...", "Dîner": "..."},
  "Vendredi": {"Petit-déj": "...", "Déjeuner": "...", "Dîner": "..."},
  "Samedi": {"Petit-déj": "...", "Déjeuner": "...", "Dîner": "..."},
  "Dimanche": {"Petit-déj": "...", "Déjeuner": "...", "Dîner": "..."}
}
Utilise des noms simples en anglais (ex: "Chicken Pasta", "Omelette").
''';
      onProgress?.call(30);
      final response = await _chat.generateContent([Content.text(prompt)]);
      onProgress?.call(70);
      final text = response.text ?? '';
      final jsonStr = RegExp(r'\{.*\}', dotAll: true).firstMatch(text)?.group(0);
      if (jsonStr == null) return null;
      onProgress?.call(90);
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e, s) { _report(e, s);
      return null;
    }
  }

  // ─── Parallel Cooking Engine ─────────────────────────────────────────────────

  static Future<List<CookingStep>?> generateParallelTimeline(
    String recipeTitle,
    List<String> steps,
  ) async {
    try {
      final stepsText = steps.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n');
      final prompt = '''
Tu es un chef expert en organisation culinaire. Analyse ces étapes de recette et génère une timeline optimisée avec des étapes parallèles.

Recette : $recipeTitle
Étapes originales :
$stepsText

Génère une timeline JSON optimisée. Réponds UNIQUEMENT avec ce JSON :
[
  {
    "id": 1,
    "description": "description courte de l'étape",
    "startMinute": 0,
    "durationMinutes": 5,
    "parallel": false,
    "parallelWith": null,
    "tip": "conseil optionnel"
  }
]
Règles :
- Les étapes passives (bouillir, mijoter, reposer) peuvent être parallèles avec des étapes actives
- startMinute doit refléter quand commencer réellement
- parallelWith = id d'une autre étape si elles sont simultanées
- Maximum 10 étapes
''';
      final response = await _chat.generateContent([Content.text(prompt)]);
      final text = response.text ?? '';
      final jsonStr = RegExp(r'\[.*\]', dotAll: true).firstMatch(text)?.group(0);
      if (jsonStr == null) return null;
      final list = jsonDecode(jsonStr) as List;
      return list.map((e) => CookingStep.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e, s) { _report(e, s);
      return null;
    }
  }

  // ─── Sous-Chef vocal ─────────────────────────────────────────────────────────

  static Future<String?> askSousChef(
    String question, {
    required String recipeTitle,
    required List<String> ingredients,
    required int currentStep,
    required String currentStepDescription,
  }) async {
    try {
      final prompt = '''
Tu es un sous-chef assistant culinaire expert. L'utilisateur est en train de cuisiner.

Recette : $recipeTitle
Ingrédients : ${ingredients.take(10).join(', ')}
Étape actuelle ($currentStep) : $currentStepDescription

Question : $question

Réponds de manière concise et pratique en français (2-3 phrases max). Sois direct et utile.
''';
      final response = await _chat.generateContent([Content.text(prompt)]);
      return response.text?.trim();
    } catch (e, s) { _report(e, s);
      return null;
    }
  }

  // ─── Batch Cooking Timeline ──────────────────────────────────────────────────

  static Future<List<BatchStep>?> generateBatchTimeline(List<Recipe> recipes) async {
    try {
      final recipesText = recipes.asMap().entries.map((e) {
        final steps = e.value.steps.take(5).toList().asMap().entries
            .map((s) => '  ${s.key + 1}. ${s.value}').join('\n');
        return 'Recette ${e.key + 1} (id:${e.value.id}): ${e.value.title}\n$steps';
      }).join('\n\n');

      final prompt = '''
Tu es un chef expert. Optimise la cuisson simultanée de ces ${recipes.length} recettes pour minimiser le temps total.

$recipesText

Réponds UNIQUEMENT avec un tableau JSON (max 15 étapes) :
[
  {
    "id": 1,
    "recipeId": "id_de_la_recette",
    "recipeTitle": "nom",
    "description": "action courte et précise",
    "startMinute": 0,
    "durationMinutes": 5,
    "isParallel": false
  }
]
Règles : les tâches passives (mijoter, bouillir, cuire au four, reposer) d'une recette DOIVENT être en parallèle avec la préparation d'une autre. Alterne les recettes pour minimiser le temps.
''';

      final response = await _chat.generateContent([Content.text(prompt)]);
      final text = response.text ?? '';
      final jsonStr = RegExp(r'\[.*\]', dotAll: true).firstMatch(text)?.group(0);
      if (jsonStr == null) return null;
      final list = jsonDecode(jsonStr) as List;
      return list.map((e) => BatchStep.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e, s) { _report(e, s);
      return null;
    }
  }

  // ─── Translation ─────────────────────────────────────────────────────────────

  static Future<TranslatedContent?> translateRecipe({
    required String recipeId,
    required String title,
    required List<String> steps,
    required List<String> ingredients,
    required String targetLang,
  }) async {
    if (targetLang == 'en') return null;
    try {
      final langName = targetLang == 'fr' ? 'français' : 'anglais';
      final stepsJson = jsonEncode(steps);
      final ingsJson = jsonEncode(ingredients);

      final prompt = '''
Traduis cette recette en $langName. Conserve exactement le même nombre d'étapes et d'ingrédients.

Titre : $title
Étapes (JSON) : $stepsJson
Ingrédients (JSON) : $ingsJson

Réponds UNIQUEMENT avec ce JSON (sans texte autour) :
{
  "title": "titre traduit",
  "steps": ["étape 1 traduite", "étape 2 traduite"],
  "ingredients": ["ingrédient 1 traduit", "ingrédient 2 traduit"]
}
Conserve les mesures (g, ml, tsp, cup…) sans les traduire.
''';
      final response = await _chat.generateContent([Content.text(prompt)]);
      final text = response.text ?? '';
      final jsonStr = RegExp(r'\{.*\}', dotAll: true).firstMatch(text)?.group(0);
      if (jsonStr == null) return null;
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      return TranslatedContent(
        recipeId: recipeId,
        title: data['title']?.toString() ?? title,
        steps: data['steps'] is List ? List<String>.from(data['steps']) : steps,
        ingredients: data['ingredients'] is List ? List<String>.from(data['ingredients']) : ingredients,
      );
    } catch (e, s) { _report(e, s);
      return null;
    }
  }

  // ─── Leftover Reinventions ───────────────────────────────────────────────────

  static Future<List<String>> suggestLeftoverReinventions(
    String originalRecipe,
    List<String> leftoverIngredients,
  ) async {
    try {
      final prompt = '''
Il me reste des ingrédients de "$originalRecipe" : ${leftoverIngredients.join(', ')}.
Suggère 3 façons de réutiliser ces restes dans de nouvelles recettes ou plats.
Réponds en tableau JSON : [{"title": "nom du plat", "description": "comment faire en 1 phrase"}]
''';
      final response = await _chat.generateContent([Content.text(prompt)]);
      final text = response.text ?? '';
      final jsonStr = RegExp(r'\[.*\]', dotAll: true).firstMatch(text)?.group(0);
      if (jsonStr == null) return [];
      final list = jsonDecode(jsonStr) as List;
      return list.map((e) => '${e['title']} — ${e['description']}').toList();
    } catch (e, s) { _report(e, s);
      return [];
    }
  }
}

class BatchStep {
  final int id;
  final String recipeId;
  final String recipeTitle;
  final String description;
  final int startMinute;
  final int durationMinutes;
  final bool isParallel;

  const BatchStep({
    required this.id,
    required this.recipeId,
    required this.recipeTitle,
    required this.description,
    required this.startMinute,
    required this.durationMinutes,
    this.isParallel = false,
  });

  factory BatchStep.fromJson(Map<String, dynamic> json) => BatchStep(
        id: (json['id'] as num?)?.toInt() ?? 0,
        recipeId: json['recipeId']?.toString() ?? '',
        recipeTitle: json['recipeTitle']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        startMinute: (json['startMinute'] as num?)?.toInt() ?? 0,
        durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 5,
        isParallel: json['isParallel'] as bool? ?? false,
      );
}

class CookingStep {
  final int id;
  final String description;
  final int startMinute;
  final int durationMinutes;
  final bool parallel;
  final int? parallelWith;
  final String? tip;

  const CookingStep({
    required this.id,
    required this.description,
    required this.startMinute,
    required this.durationMinutes,
    this.parallel = false,
    this.parallelWith,
    this.tip,
  });

  factory CookingStep.fromJson(Map<String, dynamic> json) => CookingStep(
        id: json['id'] as int? ?? 0,
        description: json['description']?.toString() ?? '',
        startMinute: json['startMinute'] as int? ?? 0,
        durationMinutes: json['durationMinutes'] as int? ?? 5,
        parallel: json['parallel'] as bool? ?? false,
        parallelWith: json['parallelWith'] as int?,
        tip: json['tip']?.toString(),
      );
}
