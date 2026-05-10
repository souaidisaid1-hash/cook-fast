import 'package:uuid/uuid.dart';

class ShoppingItem {
  final String id;
  final String name;
  final String measure;
  final String category;
  final bool isChecked;
  final String? recipeTitle;

  ShoppingItem({
    String? id,
    required this.name,
    this.measure = '',
    this.category = 'Autre',
    this.isChecked = false,
    this.recipeTitle,
  }) : id = id ?? const Uuid().v4();

  ShoppingItem copyWith({
    String? name,
    String? measure,
    String? category,
    bool? isChecked,
    String? recipeTitle,
  }) =>
      ShoppingItem(
        id: id,
        name: name ?? this.name,
        measure: measure ?? this.measure,
        category: category ?? this.category,
        isChecked: isChecked ?? this.isChecked,
        recipeTitle: recipeTitle ?? this.recipeTitle,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'measure': measure,
        'category': category,
        'isChecked': isChecked,
        'recipeTitle': recipeTitle,
      };

  factory ShoppingItem.fromJson(Map<String, dynamic> json) => ShoppingItem(
        id: json['id']?.toString(),
        name: json['name']?.toString() ?? '',
        measure: json['measure']?.toString() ?? '',
        category: json['category']?.toString() ?? 'Autre',
        isChecked: json['isChecked'] as bool? ?? false,
        recipeTitle: json['recipeTitle']?.toString(),
      );

  static String categorizeIngredient(String name) {
    final n = name.toLowerCase();
    if (_matches(n, ['poulet', 'boeuf', 'agneau', 'porc', 'veau', 'dinde', 'canard', 'saumon', 'thon', 'crevette', 'cabillaud'])) return 'Viandes & Poissons';
    if (_matches(n, ['lait', 'beurre', 'crème', 'fromage', 'yaourt', 'oeuf', 'mozzarella', 'parmesan'])) return 'Produits laitiers';
    if (_matches(n, ['tomate', 'carotte', 'oignon', 'ail', 'poivron', 'courgette', 'aubergine', 'salade', 'épinard', 'brocoli', 'champignon', 'pomme de terre'])) return 'Fruits & Légumes';
    if (_matches(n, ['pâtes', 'riz', 'farine', 'pain', 'quinoa', 'semoule', 'avoine'])) return 'Féculents';
    if (_matches(n, ['huile', 'sel', 'poivre', 'sucre', 'vinaigre', 'sauce', 'moutarde', 'ketchup'])) return 'Épicerie';
    if (_matches(n, ['pomme', 'banane', 'citron', 'orange', 'fraise', 'framboise', 'mangue', 'ananas'])) return 'Fruits & Légumes';
    return 'Autre';
  }

  static bool _matches(String name, List<String> keywords) =>
      keywords.any((k) => name.contains(k));
}
