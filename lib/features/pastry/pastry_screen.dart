import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/recipe.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/services/meal_db_service.dart';

// ─── Sub-categories ────────────────────────────────────────────────────────────

class _Sub {
  final String emoji;
  final String label;
  final List<Color> gradient;
  final String? mealDb;
  final String? search;
  const _Sub(this.emoji, this.label, this.gradient, {this.mealDb, this.search});
}

const _kSubs = [
  _Sub('✨', 'Tout',        [Color(0xFFFFD93D), Color(0xFFFF6B9D)], mealDb: 'Dessert'),
  _Sub('🎂', 'Gâteaux',    [Color(0xFFFF6B9D), Color(0xFFa55eea)], search: 'cake'),
  _Sub('🥐', 'Viennoiseries', [Color(0xFFFFD93D), Color(0xFFFF9F43)], search: 'pastry'),
  _Sub('🥧', 'Tartes',     [Color(0xFFEE5A24), Color(0xFFB71540)], search: 'tart'),
  _Sub('🍪', 'Biscuits',   [Color(0xFFF9CA24), Color(0xFFF0932B)], search: 'cookie'),
  _Sub('🍮', 'Flans',      [Color(0xFF2ECC71), Color(0xFF27AE60)], search: 'pudding'),
  _Sub('🍩', 'Donuts',     [Color(0xFF4a00e0), Color(0xFF8e2de2)], search: 'donut'),
];

// ─── State ─────────────────────────────────────────────────────────────────────

class _PastryState {
  final String selectedSub;
  final List<Recipe> recipes;
  final bool isLoading;

  const _PastryState({
    this.selectedSub = 'Tout',
    this.recipes = const [],
    this.isLoading = true,
  });

  _PastryState copyWith({
    String? selectedSub,
    List<Recipe>? recipes,
    bool? isLoading,
  }) =>
      _PastryState(
        selectedSub: selectedSub ?? this.selectedSub,
        recipes: recipes ?? this.recipes,
        isLoading: isLoading ?? this.isLoading,
      );
}

// ─── Notifier ──────────────────────────────────────────────────────────────────

class _PastryNotifier extends StateNotifier<_PastryState> {
  _PastryNotifier() : super(const _PastryState()) {
    _load(_kSubs.first);
  }

  Future<void> selectSub(_Sub sub) async {
    if (state.selectedSub == sub.label) return;
    state = state.copyWith(selectedSub: sub.label, isLoading: true, recipes: []);
    await _load(sub);
  }

  Future<void> _load(_Sub sub) async {
    try {
      final List<Recipe> r;
      if (sub.mealDb != null) {
        r = await MealDbService.byCategory(sub.mealDb!);
      } else {
        r = await MealDbService.search(sub.search!);
      }
      state = state.copyWith(recipes: r.take(20).toList(), isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }
}

final _pastryProvider =
    StateNotifierProvider.autoDispose<_PastryNotifier, _PastryState>(
        (_) => _PastryNotifier());

// ─── Screen ────────────────────────────────────────────────────────────────────

class PastryScreen extends ConsumerWidget {
  const PastryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider);
    final s = ref.watch(_pastryProvider);
    final bg = isDark ? AppColors.darkBg : const Color(0xFFF5F2EE);
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final subColor = isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary;

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          // ── Header ────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: isDark ? AppColors.darkBg : const Color(0xFFF5F2EE),
            elevation: 0,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFFFD93D), Color(0xFFFF6B9D)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  // Decorative large emoji
                  const Positioned(
                    right: -10, bottom: -10,
                    child: Text('🥐', style: TextStyle(fontSize: 140)),
                  ),
                  // Top bar with back button
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 12,
                    right: 12,
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => context.pop(),
                          child: Container(
                            width: 38, height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_back_rounded,
                                color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Title at bottom of expanded header
                  Positioned(
                    bottom: 20, left: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('CATÉGORIE',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2)),
                        ),
                        const SizedBox(height: 6),
                        const Text('Pâtisserie',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                height: 1.1,
                                shadows: [Shadow(color: Colors.black26, blurRadius: 8)])),
                        const SizedBox(height: 4),
                        const Text('Gâteaux, tartes, viennoiseries & co.',
                            style: TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Sub-categories ────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
              child: SizedBox(
                height: 48,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _kSubs.length,
                  itemBuilder: (_, i) {
                    final sub = _kSubs[i];
                    final sel = s.selectedSub == sub.label;
                    return GestureDetector(
                      onTap: () => ref.read(_pastryProvider.notifier).selectSub(sub),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: sel
                              ? LinearGradient(
                                  colors: sub.gradient,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight)
                              : null,
                          color: sel
                              ? null
                              : (isDark ? AppColors.darkCard : Colors.white),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: sel
                                ? Colors.transparent
                                : sub.gradient[0].withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                          boxShadow: sel
                              ? [BoxShadow(
                                  color: sub.gradient[0].withValues(alpha: 0.4),
                                  blurRadius: 12, offset: const Offset(0, 4))]
                              : [],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(sub.emoji, style: const TextStyle(fontSize: 15)),
                            const SizedBox(width: 7),
                            Text(sub.label,
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: sel ? Colors.white : subColor)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // ── Section title ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 16, 16),
              child: Row(
                children: [
                  Container(
                    width: 4, height: 20,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFFFFD93D), Color(0xFFFF6B9D)],
                          begin: Alignment.topCenter, end: Alignment.bottomCenter),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(s.selectedSub,
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w800, color: textColor)),
                  if (s.isLoading) ...[
                    const SizedBox(width: 12),
                    const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary)),
                  ] else ...[
                    const SizedBox(width: 8),
                    Text('${s.recipes.length} recettes',
                        style: TextStyle(fontSize: 13, color: subColor)),
                  ],
                ],
              ),
            ),
          ),

          // ── Recipe grid ───────────────────────────────────────────────
          s.isLoading
              ? SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.72,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (_, _) => _shimmerCard(isDark),
                      childCount: 6,
                    ),
                  ),
                )
              : s.recipes.isEmpty
                  ? SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(
                          child: Column(
                            children: [
                              const Text('🍰', style: TextStyle(fontSize: 48)),
                              const SizedBox(height: 12),
                              Text('Aucune recette trouvée',
                                  style: TextStyle(fontSize: 16, color: subColor)),
                            ],
                          ),
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.72,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (_, i) => _PastryCard(recipe: s.recipes[i]),
                          childCount: s.recipes.length,
                        ),
                      ),
                    ),

          const SliverToBoxAdapter(child: SizedBox(height: 110)),
        ],
      ),
    );
  }

  static Widget _shimmerCard(bool isDark) => Shimmer.fromColors(
        baseColor: isDark ? AppColors.darkCard : AppColors.lightBorder,
        highlightColor: isDark ? AppColors.darkBorder : Colors.grey[100]!,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      );
}

// ─── Pastry Recipe Card ────────────────────────────────────────────────────────

class _PastryCard extends ConsumerWidget {
  final Recipe recipe;
  const _PastryCard({required this.recipe});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider);
    final isFav = ref.watch(favoritesProvider).any((f) => f.id == recipe.id);
    final hasVideo = recipe.youtubeUrl != null && recipe.youtubeUrl!.isNotEmpty;

    return GestureDetector(
      onTap: () => context.push('/recipe/${recipe.id}', extra: recipe),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                blurRadius: 16, offset: const Offset(0, 5)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image
              recipe.imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: recipe.imageUrl!, fit: BoxFit.cover)
                  : Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                            colors: [Color(0xFFFFD93D), Color(0xFFFF6B9D)]),
                      ),
                      child: const Center(
                          child: Text('🥐',
                              style: TextStyle(fontSize: 56)))),
              // Gradient
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0x20000000), Color(0xF0000000)],
                    stops: [0.0, 0.45, 1.0],
                  ),
                ),
              ),
              // Video badge
              if (hasVideo)
                Positioned(
                  top: 8, left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 12),
                        SizedBox(width: 2),
                        Text('Vidéo',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              // Favorite button
              Positioned(
                top: 8, right: 8,
                child: GestureDetector(
                  onTap: () => ref.read(favoritesProvider.notifier).toggle(recipe),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        shape: BoxShape.circle),
                    child: Icon(
                      isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: isFav ? Colors.red : Colors.white, size: 14),
                  ),
                ),
              ),
              // Title + info
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
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [Color(0xFFFFD93D), Color(0xFFFF6B9D)]),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(recipe.category!,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700)),
                        ),
                      const SizedBox(height: 5),
                      Text(recipe.title,
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              height: 1.25)),
                      const SizedBox(height: 6),
                      Row(children: [
                        const Icon(Icons.timer_outlined, size: 11, color: Colors.white60),
                        const SizedBox(width: 3),
                        Text(_estimateTime(recipe),
                            style: const TextStyle(color: Colors.white60, fontSize: 10)),
                        if (hasVideo) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.videocam_outlined,
                              size: 11, color: Colors.red),
                        ],
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

  String _estimateTime(Recipe r) {
    if (r.cookTimeMinutes != null) return '${r.cookTimeMinutes} min';
    return '~${(r.steps.length * 5).clamp(15, 90)} min';
  }
}
