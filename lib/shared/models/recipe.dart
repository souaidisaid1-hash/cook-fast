class Recipe {
  final String id;
  final String title;
  final String? imageUrl;
  final String? category;
  final String? area;
  final List<String> ingredients;
  final List<String> measures;
  final List<String> steps;
  final String? youtubeUrl;
  final String? source;
  final bool isVegetarian;
  final int? cookTimeMinutes;

  const Recipe({
    required this.id,
    required this.title,
    this.imageUrl,
    this.category,
    this.area,
    required this.ingredients,
    required this.measures,
    required this.steps,
    this.youtubeUrl,
    this.source,
    this.isVegetarian = false,
    this.cookTimeMinutes,
  });

  factory Recipe.fromMealDb(Map<String, dynamic> json) {
    final ingredients = <String>[];
    final measures = <String>[];

    for (int i = 1; i <= 20; i++) {
      final ingredient = json['strIngredient$i'];
      final measure = json['strMeasure$i'];
      if (ingredient != null && ingredient.toString().trim().isNotEmpty) {
        ingredients.add(ingredient.toString().trim());
        measures.add(measure?.toString().trim() ?? '');
      }
    }

    final instructionsRaw = json['strInstructions'] as String? ?? '';
    final steps = instructionsRaw
        .split(RegExp(r'\r\n|\n|\r'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && s.length > 5)
        .toList();

    return Recipe(
      id: json['idMeal']?.toString() ?? '',
      title: json['strMeal']?.toString() ?? '',
      imageUrl: json['strMealThumb']?.toString(),
      category: json['strCategory']?.toString(),
      area: json['strArea']?.toString(),
      ingredients: ingredients,
      measures: measures,
      steps: steps,
      youtubeUrl: json['strYoutube']?.toString(),
      source: json['strSource']?.toString(),
      isVegetarian: json['strCategory']?.toString().toLowerCase() == 'vegetarian',
    );
  }

  factory Recipe.fromLocal(Map<String, dynamic> json) {
    return Recipe(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      imageUrl: json['image']?.toString(),
      category: json['type']?.toString(),
      ingredients: List<String>.from(json['ingredients'] ?? []),
      measures: List<String>.from(json['measures'] ?? []),
      steps: List<String>.from(json['steps'] ?? []),
      cookTimeMinutes: json['time'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'imageUrl': imageUrl,
        'category': category,
        'area': area,
        'ingredients': ingredients,
        'measures': measures,
        'steps': steps,
        'youtubeUrl': youtubeUrl,
        'isVegetarian': isVegetarian,
        'cookTimeMinutes': cookTimeMinutes,
      };

  factory Recipe.fromJson(Map<String, dynamic> json) => Recipe(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        imageUrl: json['imageUrl']?.toString(),
        category: json['category']?.toString(),
        area: json['area']?.toString(),
        ingredients: List<String>.from(json['ingredients'] ?? []),
        measures: List<String>.from(json['measures'] ?? []),
        steps: List<String>.from(json['steps'] ?? []),
        youtubeUrl: json['youtubeUrl']?.toString(),
        isVegetarian: json['isVegetarian'] as bool? ?? false,
        cookTimeMinutes: json['cookTimeMinutes'] as int?,
      );
}
