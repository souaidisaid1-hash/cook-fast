class ApiConstants {
  static const geminiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const sentryDsn = String.fromEnvironment('SENTRY_DSN');

  static const mealDbBase = 'https://www.themealdb.com/api/json/v1/1';
  static const openFoodFactsBase = 'https://world.openfoodfacts.org/api/v0/product';
}
