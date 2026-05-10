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

// ─── State ─────────────────────────────────────────────────────────────────────

class _HomeState {
  final String? selectedMood;
  final Recipe? featuredRecipe;
  final List<Recipe> moodRecipes;
  final List<Recipe> quickRecipes;
  final bool isLoading;
  final bool isMoodLoading;

  const _HomeState({
    this.selectedMood,
    this.featuredRecipe,
    this.moodRecipes = const [],
    this.quickRecipes = const [],
    this.isLoading = true,
    this.isMoodLoading = false,
  });

  _HomeState copyWith({
    String? selectedMood,
    Recipe? featuredRecipe,
    List<Recipe>? moodRecipes,
    List<Recipe>? quickRecipes,
    bool? isLoading,
    bool? isMoodLoading,
  }) =>
      _HomeState(
        selectedMood: selectedMood ?? this.selectedMood,
        featuredRecipe: featuredRecipe ?? this.featuredRecipe,
        moodRecipes: moodRecipes ?? this.moodRecipes,
        quickRecipes: quickRecipes ?? this.quickRecipes,
        isLoading: isLoading ?? this.isLoading,
        isMoodLoading: isMoodLoading ?? this.isMoodLoading,
      );
}

class HomeNotifier extends StateNotifier<_HomeState> {
  HomeNotifier() : super(const _HomeState()) {
    _init();
  }

  Future<void> _init() async {
    final results = await Future.wait([
      MealDbService.random(),
      MealDbService.random10(),
    ]);
    state = state.copyWith(
      featuredRecipe: results[0] as Recipe?,
      quickRecipes: (results[1] as List<Recipe>).take(8).toList(),
      isLoading: false,
    );
  }

  Future<void> selectMood(String mood, dynamic profile) async {
    state = state.copyWith(selectedMood: mood, isMoodLoading: true, moodRecipes: []);
    try {
      final names = await GeminiService.recipesForMood(mood, profile);
      final recipes = await Future.wait(
          names.take(4).map((n) => MealDbService.search(n).then((r) => r.firstOrNull)));
      state = state.copyWith(
        moodRecipes: recipes.whereType<Recipe>().toList(),
        isMoodLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isMoodLoading: false);
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    await _init();
  }
}

final homeProvider =
    StateNotifierProvider.autoDispose<HomeNotifier, _HomeState>((ref) {
  return HomeNotifier();
});

// ─── Screen ─────────────────────────────────────────────────────────────────────

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _moods = [
    ('Fatigué', '😴', Color(0xFF6B73FF)),
    ('Pressé', '⚡', Color(0xFFFF9F43)),
    ('Normal', '😊', Color(0xFF4CAF7D)),
    ('Festif', '🎉', Color(0xFFFF6B35)),
    ('Malade', '🤒', Color(0xFF54A0FF)),
    ('Amoureux', '❤️', Color(0xFFFF6B9D)),
  ];

  static const _challengeBanners = [
    ('🍝', 'Semaine Italienne', [Color(0xFF2ECC71), Color(0xFF27AE60)]),
    ('🐔', 'Défi Poulet', [Color(0xFFFF9F43), Color(0xFFEE5A24)]),
    ('🥗', 'Veggie Week', [Color(0xFF6AB04C), Color(0xFF1e3799)]),
    ('🦐', 'Fruits de Mer', [Color(0xFF0652DD), Color(0xFF1289A7)]),
    ('🍳', 'Brunch du Dimanche', [Color(0xFFF9CA24), Color(0xFFF0932B)]),
    ('🥩', 'Bœuf de Compétition', [Color(0xFFB71540), Color(0xFF6F1E51)]),
    ('🍰', 'Dessert Surprise', [Color(0xFFFF6B9D), Color(0xFFa55eea)]),
    ('🌍', 'Cuisine du Monde', [Color(0xFF4a00e0), Color(0xFF8e2de2)]),
    ('🍲', 'Soupe Maîtresse', [Color(0xFF11998e), Color(0xFF38ef7d)]),
    ('🥟', 'Entrée Raffinée', [Color(0xFFfd746c), Color(0xFFff9068)]),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider);
    final homeState = ref.watch(homeProvider);
    final profile = ref.watch(userProfileProvider);
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final subColor =
        isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary;

    final week = DateTime.now().difference(DateTime(2024, 1, 1)).inDays ~/ 7;
    final banner = _challengeBanners[week % _challengeBanners.length];

    return Scaffold(
      backgroundColor: bg,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(homeProvider.notifier).refresh(),
        child: CustomScrollView(
          slivers: [
            // ── Top bar ─────────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_greeting(),
                                style: TextStyle(
                                    fontSize: 12,
                                    color: subColor,
                                    fontWeight: FontWeight.w500)),
                            const Text('CookFast',
                                style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
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

            // ── Hero "Recette du jour" ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: homeState.isLoading
                    ? _heroShimmer(isDark)
                    : homeState.featuredRecipe != null
                        ? _heroCard(
                            context, homeState.featuredRecipe!, isDark, ref)
                        : const SizedBox.shrink(),
              ),
            ),

            // ── Mood picker ──────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                    child: Row(
                      children: [
                        Text('Comment tu te sens ?',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: textColor)),
                        const SizedBox(width: 8),
                        Text("L'IA s'adapte",
                            style: TextStyle(fontSize: 12, color: subColor)),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 44,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _moods.length,
                      itemBuilder: (context, i) {
                        final mood = _moods[i];
                        final selected = homeState.selectedMood == mood.$1;
                        return GestureDetector(
                          onTap: () => ref
                              .read(homeProvider.notifier)
                              .selectMood(mood.$1, profile),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: selected
                                  ? mood.$3.withValues(alpha: 0.15)
                                  : (isDark
                                      ? AppColors.darkCard
                                      : AppColors.lightCard),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: selected
                                    ? mood.$3
                                    : (isDark
                                        ? AppColors.darkBorder
                                        : AppColors.lightBorder),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(mood.$2,
                                    style: const TextStyle(fontSize: 16)),
                                const SizedBox(width: 6),
                                Text(mood.$1,
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: selected ? mood.$3 : subColor)),
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

            // ── Mood results ─────────────────────────────────────────────────────
            if (homeState.selectedMood != null)
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
                      child: Row(
                        children: [
                          Text('Pour toi ce soir',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: textColor)),
                          const Text(' ✨',
                              style: TextStyle(fontSize: 16)),
                          const Spacer(),
                          if (homeState.isMoodLoading)
                            const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary)),
                        ],
                      ),
                    ),
                    if (!homeState.isMoodLoading &&
                        homeState.moodRecipes.isNotEmpty)
                      SizedBox(
                        height: 230,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: homeState.moodRecipes.length,
                          itemBuilder: (_, i) => _PremiumCard(
                            recipe: homeState.moodRecipes[i],
                          ),
                        ),
                      ),
                    if (homeState.isMoodLoading)
                      SizedBox(
                        height: 230,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: 3,
                          itemBuilder: (_, __) =>
                              _cardShimmer(isDark, width: 190),
                        ),
                      ),
                  ],
                ),
              ),

            // ── Challenge banner ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: GestureDetector(
                  onTap: () => context.push('/challenge'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: banner.$3,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                            color: (banner.$3.first)
                                .withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Text(banner.$1,
                            style: const TextStyle(fontSize: 40)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('🏆 DÉFI DE LA SEMAINE',
                                  style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8)),
                              const SizedBox(height: 4),
                              Text(banner.$2,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              const Text('Rejoins la communauté →',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.chevron_right_rounded,
                              color: Colors.white, size: 20),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── À découvrir ──────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 16, 12),
                    child: Row(
                      children: [
                        Text('À découvrir',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: textColor)),
                        const Spacer(),
                        TextButton(
                          onPressed: () =>
                              context.push('/ingredient-search'),
                          child: const Text('Voir tout',
                              style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                  if (homeState.isLoading)
                    SizedBox(
                      height: 230,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: 4,
                        itemBuilder: (_, __) =>
                            _cardShimmer(isDark, width: 190),
                      ),
                    )
                  else if (homeState.quickRecipes.isNotEmpty)
                    SizedBox(
                      height: 230,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: homeState.quickRecipes.length,
                        itemBuilder: (_, i) => _PremiumCard(
                          recipe: homeState.quickRecipes[i],
                        ),
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

  // ── Hero card ───────────────────────────────────────────────────────────────

  Widget _heroCard(
      BuildContext context, Recipe recipe, bool isDark, WidgetRef ref) {
    return GestureDetector(
      onTap: () => context.push('/recipe/${recipe.id}', extra: recipe),
      child: Container(
        height: 280,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.18),
                blurRadius: 24,
                offset: const Offset(0, 10)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image
              recipe.imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: recipe.imageUrl!, fit: BoxFit.cover)
                  : Container(
                      color: AppColors.darkCard,
                      child: const Icon(Icons.restaurant_rounded,
                          size: 60, color: AppColors.primary)),
              // Gradient
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0xDD000000)],
                    stops: [0.25, 1.0],
                  ),
                ),
              ),
              // "Recette du jour" pill — top left
              Positioned(
                top: 14,
                left: 14,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('✨ Recette du jour',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
              ),
              // Fav button — top right
              Positioned(
                top: 12,
                right: 12,
                child: Consumer(builder: (_, r, __) {
                  final isFav =
                      r.watch(favoritesProvider).any((f) => f.id == recipe.id);
                  return GestureDetector(
                    onTap: () =>
                        ref.read(favoritesProvider.notifier).toggle(recipe),
                    child: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          shape: BoxShape.circle),
                      child: Icon(
                        isFav
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: isFav ? Colors.red : Colors.white,
                        size: 20,
                      ),
                    ),
                  );
                }),
              ),
              // Bottom info
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          if (recipe.category != null)
                            _glassPill(recipe.category!),
                          if (recipe.area != null) ...[
                            const SizedBox(width: 6),
                            _glassPill('🌍 ${recipe.area!}'),
                          ],
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(recipe.title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              height: 1.15)),
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

  Widget _glassPill(String text) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.3), width: 1),
        ),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      );

  // ── Shimmer ─────────────────────────────────────────────────────────────────

  Widget _heroShimmer(bool isDark) => Shimmer.fromColors(
        baseColor: isDark ? AppColors.darkCard : AppColors.lightBorder,
        highlightColor: isDark ? AppColors.darkBorder : Colors.grey[100]!,
        child: Container(
          height: 280,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
          ),
        ),
      );

  Widget _cardShimmer(bool isDark, {double width = 190}) =>
      Padding(
        padding: const EdgeInsets.only(right: 14),
        child: Shimmer.fromColors(
          baseColor: isDark ? AppColors.darkCard : AppColors.lightBorder,
          highlightColor:
              isDark ? AppColors.darkBorder : Colors.grey[100]!,
          child: Container(
            width: width,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      );

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Widget _iconBtn(IconData icon, VoidCallback onTap, bool isDark,
      {Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Icon(icon, size: 20, color: color ?? AppColors.primary),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bonjour 👋';
    if (h < 18) return 'Bon après-midi 👋';
    return 'Bonsoir 👋';
  }
}

// ─── Premium Recipe Card ──────────────────────────────────────────────────────

class _PremiumCard extends ConsumerWidget {
  final Recipe recipe;

  const _PremiumCard({required this.recipe});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider);
    final isFav =
        ref.watch(favoritesProvider).any((f) => f.id == recipe.id);
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;

    return GestureDetector(
      onTap: () => context.push('/recipe/${recipe.id}', extra: recipe),
      child: Container(
        width: 190,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black
                    .withValues(alpha: isDark ? 0.28 : 0.08),
                blurRadius: 14,
                offset: const Offset(0, 4)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image section
              Stack(
                children: [
                  recipe.imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: recipe.imageUrl!,
                          height: 145,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          height: 145,
                          color: isDark
                              ? AppColors.darkBg
                              : AppColors.lightBg,
                          child: const Center(
                              child: Icon(Icons.restaurant_rounded,
                                  color: AppColors.primary, size: 40)),
                        ),
                  // Fav
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () =>
                          ref.read(favoritesProvider.notifier).toggle(recipe),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            shape: BoxShape.circle),
                        child: Icon(
                          isFav
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: isFav ? Colors.red : Colors.white,
                          size: 15,
                        ),
                      ),
                    ),
                  ),
                  // Category pill bottom-left
                  if (recipe.category != null)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(12)),
                        child: Text(recipe.category!,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                ],
              ),
              // Info section
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.textDark
                              : AppColors.textLight,
                          height: 1.3),
                    ),
                    if (recipe.area != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.place_rounded,
                              size: 11,
                              color: isDark
                                  ? AppColors.textDarkSecondary
                                  : AppColors.textLightSecondary),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              recipe.area!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? AppColors.textDarkSecondary
                                      : AppColors.textLightSecondary),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
