class FamilyMember {
  final String id;
  final String name;
  final String emoji;
  final String diet; // omnivore, vegetarian, vegan, gluten_free
  final List<String> allergies;
  final bool isChild;
  final bool isActive;

  const FamilyMember({
    required this.id,
    required this.name,
    this.emoji = '🧑',
    this.diet = 'omnivore',
    this.allergies = const [],
    this.isChild = false,
    this.isActive = true,
  });

  FamilyMember copyWith({
    String? name,
    String? emoji,
    String? diet,
    List<String>? allergies,
    bool? isChild,
    bool? isActive,
  }) =>
      FamilyMember(
        id: id,
        name: name ?? this.name,
        emoji: emoji ?? this.emoji,
        diet: diet ?? this.diet,
        allergies: allergies ?? this.allergies,
        isChild: isChild ?? this.isChild,
        isActive: isActive ?? this.isActive,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'diet': diet,
        'allergies': allergies,
        'isChild': isChild,
        'isActive': isActive,
      };

  factory FamilyMember.fromJson(Map<String, dynamic> json) => FamilyMember(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        emoji: json['emoji']?.toString() ?? '🧑',
        diet: json['diet']?.toString() ?? 'omnivore',
        allergies: List<String>.from(json['allergies'] ?? []),
        isChild: json['isChild'] as bool? ?? false,
        isActive: json['isActive'] as bool? ?? true,
      );

  String get dietLabel => switch (diet) {
        'vegetarian' => 'Végétarien',
        'vegan' => 'Vegan',
        'gluten_free' => 'Sans gluten',
        _ => 'Omnivore',
      };
}
