class UserProfile {
  final String diet; // omnivore, vegetarian, vegan, gluten_free
  final int persons;
  final String goal; // weight_loss, maintain, muscle_gain
  final int weeklyBudget; // en €
  final List<String> preferredCuisines;
  final List<String> excludedIngredients;

  const UserProfile({
    this.diet = 'omnivore',
    this.persons = 2,
    this.goal = 'maintain',
    this.weeklyBudget = 50,
    this.preferredCuisines = const [],
    this.excludedIngredients = const [],
  });

  Map<String, dynamic> toJson() => {
        'diet': diet,
        'persons': persons,
        'goal': goal,
        'weeklyBudget': weeklyBudget,
        'preferredCuisines': preferredCuisines,
        'excludedIngredients': excludedIngredients,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        diet: json['diet']?.toString() ?? 'omnivore',
        persons: json['persons'] as int? ?? 2,
        goal: json['goal']?.toString() ?? 'maintain',
        weeklyBudget: json['weeklyBudget'] as int? ?? 50,
        preferredCuisines: List<String>.from(json['preferredCuisines'] ?? []),
        excludedIngredients: List<String>.from(json['excludedIngredients'] ?? []),
      );

  UserProfile copyWith({
    String? diet,
    int? persons,
    String? goal,
    int? weeklyBudget,
    List<String>? preferredCuisines,
    List<String>? excludedIngredients,
  }) =>
      UserProfile(
        diet: diet ?? this.diet,
        persons: persons ?? this.persons,
        goal: goal ?? this.goal,
        weeklyBudget: weeklyBudget ?? this.weeklyBudget,
        preferredCuisines: preferredCuisines ?? this.preferredCuisines,
        excludedIngredients: excludedIngredients ?? this.excludedIngredients,
      );

  String get dietLabel => switch (diet) {
        'vegetarian' => 'Végétarien',
        'vegan' => 'Vegan',
        'gluten_free' => 'Sans gluten',
        _ => 'Omnivore',
      };

  String get goalLabel => switch (goal) {
        'weight_loss' => 'Perte de poids',
        'muscle_gain' => 'Prise de masse',
        _ => 'Maintien',
      };

  static void registerAdapter() {
    // Hive box utilisé avec JSON, pas d'adapter TypeAdapter nécessaire
  }
}
