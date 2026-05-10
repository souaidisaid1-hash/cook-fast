import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstants {
  static String get geminiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  static const String mealDbBase = 'https://www.themealdb.com/api/json/v1/1';
  static const String openFoodFactsBase = 'https://world.openfoodfacts.org/api/v0/product';
}
