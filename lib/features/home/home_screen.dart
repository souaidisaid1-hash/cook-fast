import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/models/recipe.dart';
import '../../shared/services/meal_db_service.dart';
import '../../shared/services/gemini_service.dart';

// ─── Category model ────────────────────────────────────────────────────────────

class _Cat {
  final String label;
  final String emoji;
  final List<Color> gradient;
  final String? mealDb;
  final String? search;
  const _Cat(this.label, this.emoji, this.gradient, {this.mealDb, this.search});
}

class _Country {
  final String flag;
  final String label;
  final String area;
  final List<Color> gradient;
  const _Country(this.flag, this.label, this.area, this.gradient);
}

class _Tip {
  final String emoji;
  final String title;
  final String desc;
  final List<Color> gradient;
  const _Tip(this.emoji, this.title, this.desc, this.gradient);
}

const _kCats = [
  _Cat('Dessert',       '🍰', [Color(0xFFFF6B9D), Color(0xFFa55eea)], mealDb: 'Dessert'),
  _Cat('Poulet',        '🍗', [Color(0xFFFF9F43), Color(0xFFEE5A24)], mealDb: 'Chicken'),
  _Cat('Pâtes',         '🍝', [Color(0xFF2ECC71), Color(0xFF27AE60)], mealDb: 'Pasta'),
  _Cat('Fruits de mer', '🦐', [Color(0xFF0652DD), Color(0xFF1289A7)], mealDb: 'Seafood'),
  _Cat('Végétarien',    '🥦', [Color(0xFF6AB04C), Color(0xFF1e3799)], mealDb: 'Vegetarian'),
  _Cat('Bœuf',          '🥩', [Color(0xFFB71540), Color(0xFF6F1E51)], mealDb: 'Beef'),
  _Cat('Petit-déj',     '🍳', [Color(0xFFF9CA24), Color(0xFFF0932B)], mealDb: 'Breakfast'),
  _Cat('Salade',        '🥗', [Color(0xFF11998e), Color(0xFF38ef7d)], search: 'salad'),
  _Cat('Smoothie',      '🥤', [Color(0xFF4a00e0), Color(0xFF8e2de2)], search: 'smoothie'),
  _Cat('Soupe',         '🍲', [Color(0xFF11998e), Color(0xFF74ebd5)], search: 'soup'),
  _Cat('Entrée',        '🥟', [Color(0xFFfd746c), Color(0xFFff9068)], mealDb: 'Starter'),
  _Cat('Vegan',         '🌿', [Color(0xFF56ab2f), Color(0xFFa8e063)], mealDb: 'Vegan'),
];

const _kCountries = [
  _Country('🇫🇷', 'Français',    'French',    [Color(0xFF003087), Color(0xFF4A90D9)]),
  _Country('🇮🇹', 'Italien',     'Italian',   [Color(0xFF009246), Color(0xFF2ECC71)]),
  _Country('🇯🇵', 'Japonais',    'Japanese',  [Color(0xFFBC002D), Color(0xFFFF6B9D)]),
  _Country('🇲🇦', 'Marocain',    'Moroccan',  [Color(0xFFC1272D), Color(0xFFFF7A00)]),
  _Country('🇮🇳', 'Indien',      'Indian',    [Color(0xFFFF9933), Color(0xFFFF6B35)]),
  _Country('🇲🇽', 'Mexicain',    'Mexican',   [Color(0xFF006847), Color(0xFF27AE60)]),
  _Country('🇹🇭', 'Thaïlandais', 'Thai',      [Color(0xFF2D2A4A), Color(0xFF4A90D9)]),
  _Country('🇬🇷', 'Grec',        'Greek',     [Color(0xFF0D5EAF), Color(0xFF00B4D8)]),
  _Country('🇨🇳', 'Chinois',     'Chinese',   [Color(0xFFDE2910), Color(0xFFFFDE00)]),
  _Country('🇺🇸', 'Américain',   'American',  [Color(0xFF3C3B6E), Color(0xFFB22234)]),
];

const _kTips = [
  _Tip('🔪', 'Couteau aiguisé',    'Un couteau tranchant est plus sûr et plus précis qu\'un couteau émoussé.', [Color(0xFF2C3E50), Color(0xFF4CA1AF)]),
  _Tip('🧂', 'Salez l\'eau',       'Salez généreusement l\'eau de cuisson — c\'est la seule chance d\'assaisonner les pâtes de l\'intérieur.', [Color(0xFF1289A7), Color(0xFF0652DD)]),
  _Tip('🥩', 'Repos de la viande', 'Laissez reposer 5 min après cuisson pour que les jus se redistribuent uniformément.', [Color(0xFFB71540), Color(0xFFFF6B35)]),
  _Tip('🍳', 'Poêle chaude',       'Chauffez toujours la poêle avant d\'ajouter le gras pour éviter que ça attache.', [Color(0xFFFF9F43), Color(0xFFF9CA24)]),
  _Tip('🍋', 'Touche d\'acidité',  'Un filet de citron ou un trait de vinaigre en fin de cuisson relève n\'importe quel plat.', [Color(0xFF56ab2f), Color(0xFF38ef7d)]),
  _Tip('🫙', 'Mise en place',      'Préparez et mesurez tous vos ingrédients avant de commencer à cuisiner.', [Color(0xFF8360C3), Color(0xFF2EBF91)]),
  _Tip('🌡️', 'Temp. ambiante',    'Sortez viandes, œufs et beurre 20 min avant de cuisiner pour une cuisson uniforme.', [Color(0xFF4e54c8), Color(0xFF8f94fb)]),
  _Tip('🧄', 'Ail écrasé',         'Écraser l\'ail libère plus d\'arômes que de le couper — votre plat sera plus savoureux.', [Color(0xFF11998e), Color(0xFF6AB04C)]),
];

// ─── Mood → fallback catégorie MealDB ─────────────────────────────────────────

const _moodFallback = {
  'Fatigué':  'Pasta',
  'Pressé':   'Chicken',
  'Normal':   'Beef',
  'Festif':   'Dessert',
  'Malade':   'Starter',
  'Amoureux': 'Seafood',
};

// ─── Helpers globaux ───────────────────────────────────────────────────────────

String _estimateTime(Recipe r) {
  if (r.cookTimeMinutes != null) return '${r.cookTimeMinutes} min';
  final est = (r.steps.length * 5).clamp(15, 90);
  return '~$est min';
}

Color _categoryColor(String? cat) {
  switch (cat?.toLowerCase()) {
    case 'dessert':    return const Color(0xFFFF6B9D);
    case 'chicken':    return const Color(0xFFFF9F43);
    case 'pasta':      return const Color(0xFF2ECC71);
    case 'seafood':    return const Color(0xFF54A0FF);
    case 'vegetarian': return const Color(0xFF6AB04C);
    case 'beef':       return const Color(0xFFE74C3C);
    case 'breakfast':  return const Color(0xFFF9CA24);
    case 'vegan':      return const Color(0xFF56ab2f);
    case 'starter':    return const Color(0xFFfd746c);
    default:           return AppColors.primary;
  }
}

String _catEmoji(String? cat) {
  final idx = _kCats.indexWhere((c) => c.mealDb?.toLowerCase() == cat?.toLowerCase());
  return idx >= 0 ? _kCats[idx].emoji : '🍽️';
}

// ─── State ─────────────────────────────────────────────────────────────────────

class _HomeState {
  final String? selectedMood;
  final String? selectedCategory;
  final String? selectedCountry;
  final List<Recipe> featuredRecipes;
  final List<Recipe> moodRecipes;
  final List<Recipe> quickRecipes;
  final List<Recipe> categoryRecipes;
  final List<Recipe> countryRecipes;
  final List<Recipe> healthyRecipes;
  final bool isLoading;
  final bool isMoodLoading;
  final bool isCategoryLoading;
  final bool isCountryLoading;

  const _HomeState({
    this.selectedMood,
    this.selectedCategory,
    this.selectedCountry,
    this.featuredRecipes = const [],
    this.moodRecipes = const [],
    this.quickRecipes = const [],
    this.categoryRecipes = const [],
    this.countryRecipes = const [],
    this.healthyRecipes = const [],
    this.isLoading = true,
    this.isMoodLoading = false,
    this.isCategoryLoading = false,
    this.isCountryLoading = false,
  });

  static const _s = Object();

  _HomeState copyWith({
    Object? selectedMood = _s,
    Object? selectedCategory = _s,
    Object? selectedCountry = _s,
    List<Recipe>? featuredRecipes,
    List<Recipe>? moodRecipes,
    List<Recipe>? quickRecipes,
    List<Recipe>? categoryRecipes,
    List<Recipe>? countryRecipes,
    List<Recipe>? healthyRecipes,
    bool? isLoading,
    bool? isMoodLoading,
    bool? isCategoryLoading,
    bool? isCountryLoading,
  }) =>
      _HomeState(
        selectedMood:     identical(selectedMood, _s)     ? this.selectedMood     : selectedMood as String?,
        selectedCategory: identical(selectedCategory, _s) ? this.selectedCategory : selectedCategory as String?,
        selectedCountry:  identical(selectedCountry, _s)  ? this.selectedCountry  : selectedCountry as String?,
        featuredRecipes:  featuredRecipes  ?? this.featuredRecipes,
        moodRecipes:      moodRecipes      ?? this.moodRecipes,
        quickRecipes:     quickRecipes     ?? this.quickRecipes,
        categoryRecipes:  categoryRecipes  ?? this.categoryRecipes,
        countryRecipes:   countryRecipes   ?? this.countryRecipes,
        healthyRecipes:   healthyRecipes   ?? this.healthyRecipes,
        isLoading:        isLoading        ?? this.isLoading,
        isMoodLoading:    isMoodLoading    ?? this.isMoodLoading,
        isCategoryLoading:isCategoryLoading?? this.isCategoryLoading,
        isCountryLoading: isCountryLoading ?? this.isCountryLoading,
      );
}

// ─── Notifier ──────────────────────────────────────────────────────────────────

class HomeNotifier extends StateNotifier<_HomeState> {
  HomeNotifier() : super(const _HomeState()) {
    _init();
  }

  Future<void> _init() async {
    final results = await Future.wait([
      ...List.generate(5, (_) => MealDbService.random()),
      MealDbService.random10(),
    ]);
    final featured = results.take(5).whereType<Recipe>().toList();
    final quick = (results[5] as List<Recipe>).take(8).toList();
    state = state.copyWith(
      featuredRecipes: featured,
      quickRecipes: quick,
      isLoading: false,
    );
    _loadHealthy();
  }

  Future<void> _loadHealthy() async {
    try {
      final r = await MealDbService.byCategory('Vegetarian');
      state = state.copyWith(healthyRecipes: r.take(8).toList());
    } catch (_) {}
  }

  Future<void> selectMood(String mood, dynamic profile) async {
    state = state.copyWith(selectedMood: mood, isMoodLoading: true, moodRecipes: []);
    try {
      // Essai Gemini → noms anglais → recherche MealDB
      final names = await GeminiService.recipesForMood(mood, profile);
      if (names.isNotEmpty) {
        final recipes = await Future.wait(
            names.take(6).map((n) => MealDbService.search(n).then((r) => r.firstOrNull)));
        final found = recipes.whereType<Recipe>().toList();
        if (found.isNotEmpty) {
          state = state.copyWith(moodRecipes: found, isMoodLoading: false);
          return;
        }
      }
      // Fallback fiable : catégorie MealDB selon humeur
      final cat = _moodFallback[mood] ?? 'Chicken';
      final fallback = await MealDbService.byCategory(cat);
      state = state.copyWith(
        moodRecipes: fallback.take(6).toList(),
        isMoodLoading: false,
      );
    } catch (_) {
      try {
        final cat = _moodFallback[mood] ?? 'Chicken';
        final fallback = await MealDbService.byCategory(cat);
        state = state.copyWith(moodRecipes: fallback.take(6).toList(), isMoodLoading: false);
      } catch (_) {
        state = state.copyWith(isMoodLoading: false);
      }
    }
  }

  // ignore: library_private_types_in_public_api
  Future<void> selectCategory(String? label, _Cat? cat) async {
    if (label == null || state.selectedCategory == label) {
      state = state.copyWith(selectedCategory: null, categoryRecipes: []);
      return;
    }
    state = state.copyWith(selectedCategory: label, isCategoryLoading: true, categoryRecipes: []);
    try {
      final r = cat!.mealDb != null
          ? await MealDbService.byCategory(cat.mealDb!)
          : await MealDbService.search(cat.search!);
      state = state.copyWith(categoryRecipes: r.take(10).toList(), isCategoryLoading: false);
    } catch (_) {
      state = state.copyWith(isCategoryLoading: false);
    }
  }

  // ignore: library_private_types_in_public_api
  Future<void> selectCountry(String? label, _Country? country) async {
    if (label == null || state.selectedCountry == label) {
      state = state.copyWith(selectedCountry: null, countryRecipes: []);
      return;
    }
    state = state.copyWith(selectedCountry: label, isCountryLoading: true, countryRecipes: []);
    try {
      final r = await MealDbService.byArea(country!.area);
      state = state.copyWith(countryRecipes: r.take(10).toList(), isCountryLoading: false);
    } catch (_) {
      state = state.copyWith(isCountryLoading: false);
    }
  }

  Future<void> refresh() async {
    state = const _HomeState(isLoading: true);
    await _init();
  }
}

final homeProvider =
    StateNotifierProvider.autoDispose<HomeNotifier, _HomeState>((ref) {
  return HomeNotifier();
});

// ─── Screen ────────────────────────────────────────────────────────────────────

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final PageController _pageCtrl;
  Timer? _heroTimer;
  int _heroPage = 0;

  static const _moods = [
    ('Fatigué',  '😴', Color(0xFF6B73FF)),
    ('Pressé',   '⚡', Color(0xFFFF9F43)),
    ('Normal',   '😊', Color(0xFF4CAF7D)),
    ('Festif',   '🎉', Color(0xFFFF6B35)),
    ('Malade',   '🤒', Color(0xFF54A0FF)),
    ('Amoureux', '❤️', Color(0xFFFF6B9D)),
  ];

  static const _challengeBanners = [
    ('🍝', 'Semaine Italienne',   [Color(0xFF2ECC71), Color(0xFF27AE60)]),
    ('🐔', 'Défi Poulet',          [Color(0xFFFF9F43), Color(0xFFEE5A24)]),
    ('🥗', 'Veggie Week',          [Color(0xFF6AB04C), Color(0xFF1e3799)]),
    ('🦐', 'Fruits de Mer',        [Color(0xFF0652DD), Color(0xFF1289A7)]),
    ('🍳', 'Brunch du Dimanche',   [Color(0xFFF9CA24), Color(0xFFF0932B)]),
    ('🥩', 'Bœuf de Compétition',  [Color(0xFFB71540), Color(0xFF6F1E51)]),
    ('🍰', 'Dessert Surprise',     [Color(0xFFFF6B9D), Color(0xFFa55eea)]),
    ('🌍', 'Cuisine du Monde',     [Color(0xFF4a00e0), Color(0xFF8e2de2)]),
    ('🍲', 'Soupe Maîtresse',      [Color(0xFF11998e), Color(0xFF38ef7d)]),
    ('🥟', 'Entrée Raffinée',      [Color(0xFFfd746c), Color(0xFFff9068)]),
  ];

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _heroTimer = Timer.periodic(const Duration(seconds: 5), _advanceHero);
  }

  void _advanceHero(Timer _) {
    final featured = ref.read(homeProvider).featuredRecipes;
    if (featured.length < 2 || !mounted) return;
    final next = (_heroPage + 1) % featured.length;
    _pageCtrl.animateToPage(next,
        duration: const Duration(milliseconds: 700), curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _heroTimer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final s = ref.watch(homeProvider);
    final profile = ref.watch(userProfileProvider);
    final bg = isDark ? AppColors.darkBg : const Color(0xFFF5F2EE);
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final subColor = isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary;

    final week = DateTime.now().difference(DateTime(2024, 1, 1)).inDays ~/ 7;
    final banner = _challengeBanners[week % _challengeBanners.length];

    // Recettes rapides filtrées depuis les quick
    final fast = s.quickRecipes.where((r) {
      final t = r.cookTimeMinutes ?? (r.steps.length * 5).clamp(15, 90);
      return t <= 35;
    }).toList();

    return Scaffold(
      backgroundColor: bg,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(homeProvider.notifier).refresh(),
        child: CustomScrollView(
          slivers: [

            // ── Top bar ────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_greeting(),
                                style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.primary.withValues(alpha: 0.8),
                                    fontWeight: FontWeight.w600)),
                            const Text('CookFast',
                                style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.primary,
                                    letterSpacing: -0.5,
                                    height: 1.1)),
                          ],
                        ),
                      ),
                      _iconBtn(Icons.search_rounded,
                          () => context.push('/ingredient-search'), isDark),
                      const SizedBox(width: 8),
                      _iconBtn(Icons.favorite_rounded,
                          () => context.push('/favorites'), isDark,
                          color: Colors.red),
                      const SizedBox(width: 8),
                      _iconBtn(
                        isDark ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded,
                        () => ref.read(themeProvider.notifier).toggle(),
                        isDark,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Hero carousel ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                child: s.isLoading
                    ? _heroShimmer(isDark)
                    : s.featuredRecipes.isNotEmpty
                        ? Column(
                            children: [
                              SizedBox(
                                height: 380,
                                child: PageView.builder(
                                  controller: _pageCtrl,
                                  itemCount: s.featuredRecipes.length,
                                  onPageChanged: (i) =>
                                      setState(() => _heroPage = i),
                                  itemBuilder: (_, i) =>
                                      _heroCard(context, s.featuredRecipes[i]),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  s.featuredRecipes.length,
                                  (i) => AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    margin: const EdgeInsets.symmetric(horizontal: 3),
                                    width: _heroPage == i ? 24 : 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      gradient: _heroPage == i
                                          ? const LinearGradient(colors: [
                                              AppColors.primary, AppColors.yellow])
                                          : null,
                                      color: _heroPage == i
                                          ? null
                                          : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
              ),
            ),

            // ── Catégories ─────────────────────────────────────────────────
            SliverToBoxAdapter(child: _sectionTitle('Catégories', null, textColor)),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _allPill(s.selectedCategory == null, isDark, subColor,
                        () => ref.read(homeProvider.notifier).selectCategory(null, null)),
                    const SizedBox(width: 8),
                    ..._kCats.map((cat) {
                      final sel = s.selectedCategory == cat.label;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _gradientPill(
                          cat.emoji, cat.label, sel, cat.gradient, isDark, subColor,
                          () => ref.read(homeProvider.notifier).selectCategory(cat.label, cat),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            // ── Résultats catégorie ────────────────────────────────────────
            if (s.selectedCategory != null)
              SliverToBoxAdapter(
                child: _recipesRow(
                  title: '${_kCats.firstWhere((c) => c.label == s.selectedCategory!).emoji}  ${s.selectedCategory!}',
                  recipes: s.categoryRecipes,
                  loading: s.isCategoryLoading,
                  isDark: isDark, textColor: textColor,
                ),
              ),

            // ── Prêt en 30 min ─────────────────────────────────────────────
            if (!s.isLoading && fast.length >= 2)
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('⚡ Prêt en 30 min', null, textColor),
                    SizedBox(
                      height: 265,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: fast.length,
                        itemBuilder: (_, i) => _RecipeCard(recipe: fast[i]),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Mood picker ────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
                    child: Row(
                      children: [
                        _accentBar(),
                        const SizedBox(width: 10),
                        Text('Comment tu te sens ?',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w800, color: textColor)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [Color(0xFF6B73FF), Color(0xFF9B59B6)]),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('IA ✨',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 46,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _moods.length,
                      itemBuilder: (context, i) {
                        final mood = _moods[i];
                        final sel = s.selectedMood == mood.$1;
                        return GestureDetector(
                          onTap: () => ref
                              .read(homeProvider.notifier)
                              .selectMood(mood.$1, profile),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: sel
                                  ? mood.$3
                                  : (isDark ? AppColors.darkCard : Colors.white),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: sel
                                    ? Colors.transparent
                                    : mood.$3.withValues(alpha: 0.35),
                                width: 1.5,
                              ),
                              boxShadow: sel
                                  ? [BoxShadow(
                                      color: mood.$3.withValues(alpha: 0.4),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4))]
                                  : [],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(mood.$2, style: const TextStyle(fontSize: 16)),
                                const SizedBox(width: 6),
                                Text(mood.$1,
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: sel ? Colors.white : subColor)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // ── Mood results ───────────────────────────────────────────────
            if (s.selectedMood != null)
              SliverToBoxAdapter(
                child: _recipesRow(
                  title: 'Pour toi ce soir ✨',
                  recipes: s.moodRecipes,
                  loading: s.isMoodLoading,
                  isDark: isDark, textColor: textColor,
                ),
              ),

            // ── Conseils du chef ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('💡 Conseils du chef', null, textColor),
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _kTips.length,
                      itemBuilder: (_, i) => _TipCard(tip: _kTips[i]),
                    ),
                  ),
                ],
              ),
            ),

            // ── Tour du monde ──────────────────────────────────────────────
            SliverToBoxAdapter(child: _sectionTitle('🌍 Tour du monde', null, textColor)),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _allPill(s.selectedCountry == null, isDark, subColor,
                        () => ref.read(homeProvider.notifier).selectCountry(null, null)),
                    const SizedBox(width: 8),
                    ..._kCountries.map((c) {
                      final sel = s.selectedCountry == c.label;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _gradientPill(
                          c.flag, c.label, sel, c.gradient, isDark, subColor,
                          () => ref.read(homeProvider.notifier).selectCountry(c.label, c),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            if (s.selectedCountry != null)
              SliverToBoxAdapter(
                child: _recipesRow(
                  title: '${_kCountries.firstWhere((c) => c.label == s.selectedCountry!).flag}  ${s.selectedCountry!}',
                  recipes: s.countryRecipes,
                  loading: s.isCountryLoading,
                  isDark: isDark, textColor: textColor,
                ),
              ),

            // ── Challenge banner ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
                child: GestureDetector(
                  onTap: () => context.push('/challenge'),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: banner.$3,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                            color: (banner.$3.first).withValues(alpha: 0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 64, height: 64,
                          decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle),
                          child: Center(child: Text(banner.$1, style: const TextStyle(fontSize: 32))),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8)),
                                child: const Text('🏆 DÉFI DE LA SEMAINE',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8)),
                              ),
                              const SizedBox(height: 6),
                              Text(banner.$2,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      height: 1.1)),
                              const SizedBox(height: 4),
                              const Text('Rejoins la communauté →',
                                  style: TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Manger sain ────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('🥗 Manger sain', null, textColor),
                  if (s.healthyRecipes.isEmpty)
                    SizedBox(
                      height: 265,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: 4,
                        itemBuilder: (_, _) => _cardShimmer(isDark),
                      ),
                    )
                  else
                    SizedBox(
                      height: 265,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: s.healthyRecipes.length,
                        itemBuilder: (_, i) => _RecipeCard(recipe: s.healthyRecipes[i]),
                      ),
                    ),
                ],
              ),
            ),

            // ── Populaire en ce moment ─────────────────────────────────────
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 16, 14),
                    child: Row(
                      children: [
                        _accentBar(),
                        const SizedBox(width: 10),
                        Text('Populaire en ce moment',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w800, color: textColor)),
                        const Text(' 🔥', style: TextStyle(fontSize: 16)),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => context.push('/ingredient-search'),
                          child: const Text('Voir tout',
                              style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                  if (s.isLoading)
                    SizedBox(
                      height: 265,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: 4,
                        itemBuilder: (_, _) => _cardShimmer(isDark),
                      ),
                    )
                  else if (s.quickRecipes.isNotEmpty)
                    SizedBox(
                      height: 265,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: s.quickRecipes.length,
                        itemBuilder: (_, i) => _RecipeCard(recipe: s.quickRecipes[i]),
                      ),
                    ),
                ],
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 110)),
          ],
        ),
      ),
    );
  }

  // ── Hero card ──────────────────────────────────────────────────────────────

  Widget _heroCard(BuildContext context, Recipe recipe) {
    final isFav = ref.watch(favoritesProvider).any((f) => f.id == recipe.id);
    final catColor = _categoryColor(recipe.category);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: GestureDetector(
        onTap: () => context.push('/recipe/${recipe.id}', extra: recipe),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 30, offset: const Offset(0, 14)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              fit: StackFit.expand,
              children: [
                recipe.imageUrl != null
                    ? CachedNetworkImage(imageUrl: recipe.imageUrl!, fit: BoxFit.cover)
                    : Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: [AppColors.darkCard, catColor.withValues(alpha: 0.3)],
                              begin: Alignment.topLeft, end: Alignment.bottomRight),
                        ),
                        child: Center(child: Text(_catEmoji(recipe.category),
                            style: const TextStyle(fontSize: 80)))),
                const _GradientOverlay(),
                Positioned(
                  top: 16, left: 16, right: 16,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.yellow]),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.5),
                              blurRadius: 10, offset: const Offset(0, 3))],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('⚡', style: TextStyle(fontSize: 11)),
                            SizedBox(width: 4),
                            Text('Recette phare',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => ref.read(favoritesProvider.notifier).toggle(recipe),
                        child: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15))),
                          child: Icon(
                            isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: isFav ? Colors.red : Colors.white, size: 19),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(children: [
                          if (recipe.category != null)
                            _colorPill(recipe.category!, catColor),
                          if (recipe.area != null) ...[
                            const SizedBox(width: 8),
                            _glassPill('🌍 ${recipe.area!}'),
                          ],
                        ]),
                        const SizedBox(height: 10),
                        Text(recipe.title,
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 26,
                                fontWeight: FontWeight.w900, height: 1.1,
                                letterSpacing: -0.3)),
                        const SizedBox(height: 14),
                        Row(children: [
                          _statChip('⏱', _estimateTime(recipe)),
                          const SizedBox(width: 8),
                          _statChip('📋', '${recipe.steps.length} étapes'),
                          const SizedBox(width: 8),
                          _statChip('🧅', '${recipe.ingredients.length} ingr.'),
                        ]),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [AppColors.primary, AppColors.yellow],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.5),
                                blurRadius: 16, offset: const Offset(0, 6))],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Cuisiner maintenant',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 15,
                                      fontWeight: FontWeight.w700)),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded,
                                  color: Colors.white, size: 18),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Shared recipe row (category / mood / country results) ──────────────────

  Widget _recipesRow({
    required String title,
    required List<Recipe> recipes,
    required bool loading,
    required bool isDark,
    required Color textColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
          child: Row(
            children: [
              _accentBar(),
              const SizedBox(width: 10),
              Expanded(child: Text(title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800, color: textColor))),
              if (loading)
                const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary)),
            ],
          ),
        ),
        if (!loading && recipes.isNotEmpty)
          SizedBox(
            height: 265,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: recipes.length,
              itemBuilder: (_, i) => _RecipeCard(recipe: recipes[i]),
            ),
          ),
        if (loading)
          SizedBox(
            height: 265,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: 3,
              itemBuilder: (_, _) => _cardShimmer(isDark),
            ),
          ),
      ],
    );
  }

  // ── Reusable widgets ───────────────────────────────────────────────────────

  Widget _gradientPill(
    String emoji, String label, bool selected, List<Color> gradient,
    bool isDark, Color subColor, VoidCallback onTap,
  ) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(colors: gradient,
                    begin: Alignment.topLeft, end: Alignment.bottomRight)
                : null,
            color: selected ? null : (isDark ? AppColors.darkCard : Colors.white),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? Colors.transparent : gradient[0].withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: selected
                ? [BoxShadow(
                    color: gradient[0].withValues(alpha: 0.4),
                    blurRadius: 12, offset: const Offset(0, 4))]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : subColor)),
            ],
          ),
        ),
      );

  Widget _allPill(bool selected, bool isDark, Color subColor, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(colors: [AppColors.primary, AppColors.yellow])
                : null,
            color: selected ? null : (isDark ? AppColors.darkCard : Colors.white),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? Colors.transparent : AppColors.primary.withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: selected
                ? [BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 10, offset: const Offset(0, 4))]
                : [],
          ),
          child: Text('✦ Tout',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : subColor)),
        ),
      );

  Widget _statChip(String emoji, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 11)),
            const SizedBox(width: 4),
            Text(text,
                style: const TextStyle(
                    color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Widget _colorPill(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(10)),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
      );

  Widget _glassPill(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
      );

  Widget _accentBar() => Container(
        width: 4, height: 22,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.yellow],
              begin: Alignment.topCenter, end: Alignment.bottomCenter),
          borderRadius: BorderRadius.circular(2),
        ),
      );

  Widget _sectionTitle(String title, String? emoji, Color textColor) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
        child: Row(
          children: [
            _accentBar(),
            const SizedBox(width: 10),
            Text('$title${emoji ?? ''}',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, color: textColor)),
          ],
        ),
      );

  Widget _heroShimmer(bool isDark) => Shimmer.fromColors(
        baseColor: isDark ? AppColors.darkCard : AppColors.lightBorder,
        highlightColor: isDark ? AppColors.darkBorder : Colors.grey[100]!,
        child: Container(height: 380,
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(28))),
      );

  Widget _cardShimmer(bool isDark) => Padding(
        padding: const EdgeInsets.only(right: 14),
        child: Shimmer.fromColors(
          baseColor: isDark ? AppColors.darkCard : AppColors.lightBorder,
          highlightColor: isDark ? AppColors.darkBorder : Colors.grey[100]!,
          child: Container(width: 180, height: 265,
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(22))),
        ),
      );

  Widget _iconBtn(IconData icon, VoidCallback onTap, bool isDark, {Color? color}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: Icon(icon, size: 20, color: color ?? AppColors.primary),
        ),
      );

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bonjour 👋';
    if (h < 18) return 'Bon après-midi 👋';
    return 'Bonsoir 👋';
  }
}

// ─── Gradient overlay (const widget) ──────────────────────────────────────────

class _GradientOverlay extends StatelessWidget {
  const _GradientOverlay();

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x00000000), Color(0x20000000), Color(0xF5000000)],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
      );
}

// ─── Tip Card ──────────────────────────────────────────────────────────────────

class _TipCard extends StatelessWidget {
  final _Tip tip;
  const _TipCard({required this.tip});

  @override
  Widget build(BuildContext context) => Container(
        width: 180,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: tip.gradient,
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: tip.gradient[0].withValues(alpha: 0.3),
                blurRadius: 12, offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Text(tip.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(tip.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
            const SizedBox(height: 8),
            Text(tip.desc,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 11, height: 1.4),
                maxLines: 3,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      );
}

// ─── Recipe Card ───────────────────────────────────────────────────────────────

class _RecipeCard extends ConsumerWidget {
  final Recipe recipe;
  const _RecipeCard({required this.recipe});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider);
    final isFav = ref.watch(favoritesProvider).any((f) => f.id == recipe.id);
    final catColor = _categoryColor(recipe.category);

    return GestureDetector(
      onTap: () => context.push('/recipe/${recipe.id}', extra: recipe),
      child: Container(
        width: 180,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.1),
              blurRadius: 18, offset: const Offset(0, 6))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            fit: StackFit.expand,
            children: [
              recipe.imageUrl != null
                  ? CachedNetworkImage(imageUrl: recipe.imageUrl!, fit: BoxFit.cover)
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [catColor.withValues(alpha: 0.8), catColor.withValues(alpha: 0.4)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(child: Text(_catEmoji(recipe.category),
                          style: const TextStyle(fontSize: 64)))),
              const _GradientOverlay(),
              Positioned(
                top: 10, right: 10,
                child: GestureDetector(
                  onTap: () => ref.read(favoritesProvider.notifier).toggle(recipe),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.12))),
                    child: Icon(
                      isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: isFav ? Colors.red : Colors.white, size: 14),
                  ),
                ),
              ),
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (recipe.category != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: catColor, borderRadius: BorderRadius.circular(8)),
                          child: Text(recipe.category!,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                        ),
                      const SizedBox(height: 6),
                      Text(recipe.title,
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14,
                              fontWeight: FontWeight.w800, height: 1.25)),
                      const SizedBox(height: 8),
                      Row(children: [
                        const Icon(Icons.timer_outlined, size: 11, color: Colors.white60),
                        const SizedBox(width: 3),
                        Text(_estimateTime(recipe),
                            style: const TextStyle(color: Colors.white60, fontSize: 10)),
                        const SizedBox(width: 10),
                        const Icon(Icons.format_list_bulleted_rounded,
                            size: 11, color: Colors.white60),
                        const SizedBox(width: 3),
                        Text('${recipe.steps.length} étapes',
                            style: const TextStyle(color: Colors.white60, fontSize: 10)),
                      ]),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
