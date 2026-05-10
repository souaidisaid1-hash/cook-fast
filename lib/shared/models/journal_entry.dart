class JournalEntry {
  final String id;
  final String recipeTitle;
  final String? category;
  final DateTime cookedAt;
  final String? photoPath;
  final int rating;
  final String notes;

  const JournalEntry({
    required this.id,
    required this.recipeTitle,
    this.category,
    required this.cookedAt,
    this.photoPath,
    this.rating = 0,
    this.notes = '',
  });

  JournalEntry copyWith({
    String? photoPath,
    int? rating,
    String? notes,
  }) =>
      JournalEntry(
        id: id,
        recipeTitle: recipeTitle,
        category: category,
        cookedAt: cookedAt,
        photoPath: photoPath ?? this.photoPath,
        rating: rating ?? this.rating,
        notes: notes ?? this.notes,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'recipeTitle': recipeTitle,
        'category': category,
        'cookedAt': cookedAt.toIso8601String(),
        'photoPath': photoPath,
        'rating': rating,
        'notes': notes,
      };

  factory JournalEntry.fromJson(Map<String, dynamic> json) => JournalEntry(
        id: json['id']?.toString() ?? '',
        recipeTitle: json['recipeTitle']?.toString() ?? '',
        category: json['category']?.toString(),
        cookedAt: DateTime.tryParse(json['cookedAt']?.toString() ?? '') ?? DateTime.now(),
        photoPath: json['photoPath']?.toString(),
        rating: json['rating'] as int? ?? 0,
        notes: json['notes']?.toString() ?? '',
      );
}
