import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/recipe.dart';
import '../../core/constants/api_constants.dart';

class MealDbService {
  static final _client = http.Client();
  static final _cache = <String, dynamic>{};

  static Future<T?> _get<T>(String endpoint, T Function(Map<String, dynamic>) parser) async {
    if (_cache.containsKey(endpoint)) return _cache[endpoint] as T;
    try {
      final res = await _client.get(Uri.parse('${ApiConstants.mealDbBase}/$endpoint'));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body);
      final result = parser(data);
      _cache[endpoint] = result;
      return result;
    } catch (_) {
      return null;
    }
  }

  static Future<Recipe?> random() async {
    // Pas de cache — chaque appel doit retourner une recette différente
    try {
      final res = await _client.get(Uri.parse('${ApiConstants.mealDbBase}/random.php'));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body);
      return Recipe.fromMealDb((data['meals'] as List).first);
    } catch (_) {
      return null;
    }
  }

  static Future<List<Recipe>> search(String query) async {
    final data = await _get<List<Recipe>>(
      'search.php?s=$query',
      (d) => ((d['meals'] as List?) ?? []).map((m) => Recipe.fromMealDb(m)).toList(),
    );
    return data ?? [];
  }

  static Future<Recipe?> byId(String id) => _get(
        'lookup.php?i=$id',
        (d) => Recipe.fromMealDb((d['meals'] as List).first),
      );

  static Future<List<Recipe>> byCategory(String category) async {
    // Filtre basique puis récupère les détails des 10 premiers
    try {
      final res = await _client.get(
          Uri.parse('${ApiConstants.mealDbBase}/filter.php?c=$category'));
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body);
      final meals = (data['meals'] as List?) ?? [];
      final ids = meals.take(12).map((m) => m['idMeal'].toString()).toList();
      final recipes = await Future.wait(ids.map((id) => byId(id)));
      return recipes.whereType<Recipe>().toList();
    } catch (_) {
      return [];
    }
  }

  // Returns recipes scored by how many of the given ingredients they contain.
  // [scores] is a parallel list: scores[i] = number of matched ingredients for recipes[i].
  static Future<({List<Recipe> recipes, List<int> scores})> byIngredients(
      List<String> ingredients) async {
    const empty = (recipes: <Recipe>[], scores: <int>[]);
    if (ingredients.isEmpty) return empty;
    try {
      final idScores = <String, int>{};
      for (final ing in ingredients.take(4)) {
        final encoded = Uri.encodeComponent(ing.trim());
        final res = await _client.get(
            Uri.parse('${ApiConstants.mealDbBase}/filter.php?i=$encoded'));
        if (res.statusCode != 200) continue;
        final data = jsonDecode(res.body);
        final meals = (data['meals'] as List?) ?? [];
        for (final m in meals) {
          final id = m['idMeal'].toString();
          idScores[id] = (idScores[id] ?? 0) + 1;
        }
      }
      if (idScores.isEmpty) return empty;

      final sorted = idScores.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final top = sorted.take(12).toList();

      final fetched = await Future.wait(top.map((e) => byId(e.key)));
      final outRecipes = <Recipe>[];
      final outScores = <int>[];
      for (int i = 0; i < top.length; i++) {
        final r = fetched[i];
        if (r != null) {
          outRecipes.add(r);
          outScores.add(top[i].value);
        }
      }
      return (recipes: outRecipes, scores: outScores);
    } catch (_) {
      return empty;
    }
  }

  static Future<List<Map<String, String>>> categories() async {
    final data = await _get<List<Map<String, String>>>(
      'categories.php',
      (d) => ((d['categories'] as List?) ?? [])
          .map((c) => {'name': c['strCategory'].toString(), 'thumb': c['strCategoryThumb'].toString()})
          .toList(),
    );
    return data ?? [];
  }

  static Future<List<Recipe>> random10() async {
    final results = await Future.wait(List.generate(10, (_) => random()));
    return results.whereType<Recipe>().toList();
  }
}
