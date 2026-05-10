import 'dart:convert';
import 'package:http/http.dart' as http;

class OFFProduct {
  final String barcode;
  final String name;
  final String brand;
  final String? imageUrl;
  final String category;

  const OFFProduct({
    required this.barcode,
    required this.name,
    required this.brand,
    this.imageUrl,
    required this.category,
  });
}

class OpenFoodFactsService {
  static Future<OFFProduct?> lookup(String barcode) async {
    try {
      final uri = Uri.parse(
          'https://world.openfoodfacts.org/api/v0/product/$barcode.json');
      final res = await http.get(uri, headers: {
        'User-Agent': 'CookFast/1.0 (Flutter app)',
      }).timeout(const Duration(seconds: 8));

      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      if (json['status'] != 1) return null;

      final p = json['product'] as Map<String, dynamic>;

      final name = (p['product_name_fr']?.toString().trim().isNotEmpty == true
              ? p['product_name_fr']
              : p['product_name']?.toString().trim().isNotEmpty == true
                  ? p['product_name']
                  : null)
          ?.toString()
          .trim();
      if (name == null || name.isEmpty) return null;

      final brand = p['brands']?.toString().split(',').first.trim() ?? '';
      final imageUrl = (p['image_front_url'] ?? p['image_url'])?.toString();

      final cats = (p['categories_tags'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      final category = _mapCategory(cats);

      return OFFProduct(
        barcode: barcode,
        name: name,
        brand: brand,
        imageUrl: imageUrl?.isNotEmpty == true ? imageUrl : null,
        category: category,
      );
    } catch (_) {
      return null;
    }
  }

  static String _mapCategory(List<String> tags) {
    for (final t in tags) {
      if (t.contains('meat') || t.contains('viand') || t.contains('fish') || t.contains('poisson')) {
        return 'Viandes & Poissons';
      }
      if (t.contains('dairy') || t.contains('lait') || t.contains('fromage') || t.contains('yaourt')) {
        return 'Produits laitiers';
      }
      if (t.contains('fruit') || t.contains('vegetable') || t.contains('legume')) {
        return 'Fruits & Légumes';
      }
      if (t.contains('cereal') || t.contains('pasta') || t.contains('bread') || t.contains('pain')) {
        return 'Féculents';
      }
    }
    return 'Épicerie';
  }
}
