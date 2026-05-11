import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/recipe.dart';
import '../../shared/models/translated_content.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/services/gemini_service.dart';
import '../../shared/services/meal_db_service.dart';
import '../../shared/models/shopping_item.dart';
import '../shopping/order_ingredients_sheet.dart';

// ─── State ─────────────────────────────────────────────────────────────────────

class _DetailState {
  final Recipe? recipe;
  final bool isLoading;
  final Map<String, int>? nutrition;
  final bool nutritionLoading;
  final int portions;
  final String? translatedTitle;
  final List<String>? translatedSteps;
  final List<String>? translatedIngredients;
  final bool translationLoading;

  const _DetailState({
    this.recipe,
    this.isLoading = true,
    this.nutrition,
    this.nutritionLoading = false,
    this.portions = 2,
    this.translatedTitle,
    this.translatedSteps,
    this.translatedIngredients,
    this.translationLoading = false,
  });

  _DetailState copyWith({
    Recipe? recipe,
    bool? isLoading,
    Map<String, int>? nutrition,
    bool? nutritionLoading,
    int? portions,
    String? translatedTitle,
    List<String>? translatedSteps,
    List<String>? translatedIngredients,
    bool? translationLoading,
  }) =>
      _DetailState(
        recipe: recipe ?? this.recipe,
        isLoading: isLoading ?? this.isLoading,
        nutrition: nutrition ?? this.nutrition,
        nutritionLoading: nutritionLoading ?? this.nutritionLoading,
        portions: portions ?? this.portions,
        translatedTitle: translatedTitle ?? this.translatedTitle,
        translatedSteps: translatedSteps ?? this.translatedSteps,
        translatedIngredients: translatedIngredients ?? this.translatedIngredients,
        translationLoading: translationLoading ?? this.translationLoading,
      );
}

class _DetailNotifier extends StateNotifier<_DetailState> {
  _DetailNotifier(Recipe? initial, String id, int defaultPortions, String lang)
      : super(_DetailState(recipe: initial, isLoading: initial == null, portions: defaultPortions)) {
    if (initial == null) {
      _fetchById(id, lang);
    } else {
      _loadNutrition(initial);
      _loadTranslation(initial, lang);
    }
  }

  Future<void> _fetchById(String id, String lang) async {
    final recipe = await MealDbService.byId(id);
    if (recipe != null) {
      state = state.copyWith(recipe: recipe, isLoading: false);
      _loadNutrition(recipe);
      _loadTranslation(recipe, lang);
    } else {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _loadNutrition(Recipe recipe) async {
    if (recipe.ingredients.isEmpty) return;
    state = state.copyWith(nutritionLoading: true);
    final nutrition = await GeminiService.estimateNutrition(
      recipe.ingredients,
      recipe.measures,
    );
    if (mounted) state = state.copyWith(nutrition: nutrition, nutritionLoading: false);
  }

  Future<void> _loadTranslation(Recipe recipe, String lang) async {
    if (lang == 'en' || recipe.steps.isEmpty) return;
    final box = Hive.box('translations');
    final cached = TranslatedContent.tryParseFromHive(box.get(recipe.id));
    if (cached != null) {
      if (mounted) {
        state = state.copyWith(
          translatedTitle: cached.title,
          translatedSteps: cached.steps,
          translatedIngredients: cached.ingredients,
        );
      }
      return;
    }
    if (mounted) state = state.copyWith(translationLoading: true);
    final translated = await GeminiService.translateRecipe(
      recipeId: recipe.id,
      title: recipe.title,
      steps: recipe.steps,
      ingredients: recipe.ingredients,
      targetLang: lang,
    );
    if (!mounted) return;
    if (translated != null) {
      box.put(recipe.id, jsonEncode(translated.toJson()));
      state = state.copyWith(
        translatedTitle: translated.title,
        translatedSteps: translated.steps,
        translatedIngredients: translated.ingredients,
        translationLoading: false,
      );
    } else {
      state = state.copyWith(translationLoading: false);
    }
  }

  void setPortions(int p) => state = state.copyWith(portions: p);
}

final _detailProvider = StateNotifierProvider.family.autoDispose<_DetailNotifier, _DetailState, (Recipe?, String, int, String)>(
  (ref, args) => _DetailNotifier(args.$1, args.$2, args.$3, args.$4),
);

// ─── Screen ─────────────────────────────────────────────────────────────────────

class RecipeDetailScreen extends ConsumerWidget {
  final Recipe? recipe;
  final String id;

  const RecipeDetailScreen({super.key, this.recipe, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider);
    final lang = ref.watch(langProvider);
    final profile = ref.watch(userProfileProvider);
    final state = ref.watch(_detailProvider((recipe, id, profile.persons, lang)));
    final notifier = ref.read(_detailProvider((recipe, id, profile.persons, lang)).notifier);
    final bg = isDark ? AppColors.darkBg : const Color(0xFFF5F2EE);

    if (state.isLoading) return _loadingScreen(isDark);
    if (state.recipe == null) return _errorScreen(context, isDark);

    final r = state.recipe!;
    final isFav = ref.watch(favoritesProvider).any((fav) => fav.id == r.id);
    final estTime = _estimateTime(r);

    final displayIngredients = state.translatedIngredients ?? r.ingredients;
    final displaySteps = state.translatedSteps ?? r.steps;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // ── Hero ──────────────────────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 360,
                pinned: true,
                backgroundColor: isDark ? AppColors.darkBg : const Color(0xFFF5F2EE),
                elevation: 0,
                automaticallyImplyLeading: false,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      r.imageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: r.imageUrl!,
                              fit: BoxFit.cover,
                              placeholder: (_, _) => Container(color: AppColors.darkCard),
                              errorWidget: (_, _, _) => _imagePlaceholder(),
                            )
                          : _imagePlaceholder(),
                      // Gradient overlay — bottom
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.15),
                              Colors.black.withValues(alpha: 0.75),
                            ],
                            stops: const [0.4, 0.65, 1.0],
                          ),
                        ),
                      ),
                      // Gradient overlay — top (for buttons)
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.45),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.35],
                          ),
                        ),
                      ),
                      // Floating action buttons at top
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 8,
                        left: 12,
                        right: 12,
                        child: Row(
                          children: [
                            _circleBtn(Icons.arrow_back_rounded, () => context.pop()),
                            const Spacer(),
                            _circleBtn(Icons.ios_share_rounded, () => _shareRecipe(r)),
                            const SizedBox(width: 8),
                            if (isFav) ...[
                              _circleBtn(Icons.bookmark_add_rounded,
                                  () => _showCollectionSheet(context, ref, r)),
                              const SizedBox(width: 8),
                            ],
                            _circleBtnColored(
                              isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              isFav ? Colors.red : Colors.white,
                              () => ref.read(favoritesProvider.notifier).toggle(r),
                            ),
                          ],
                        ),
                      ),
                      // Recipe title overlay at bottom of hero
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                if (r.category != null)
                                  _gradientPill(r.category!,
                                      [AppColors.primary, AppColors.yellow]),
                                if (r.area != null)
                                  _plainPill('🌍 ${r.area!}', isDark),
                                if (r.isVegetarian)
                                  _plainPill('🌿 Végan', isDark,
                                      color: AppColors.green),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              r.title,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.2,
                                shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                _statChip('⏱', '$estTime min'),
                                const SizedBox(width: 8),
                                _statChip('🥕', '${r.ingredients.length} ingr.'),
                                const SizedBox(width: 8),
                                if (r.steps.isNotEmpty)
                                  _statChip('📋', '${r.steps.length} étapes'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Content ──────────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),

                    // ── Portions ────────────────────────────────────────────────
                    _sectionCard(
                      isDark,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeader('👥', 'Portions', isDark),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              _portionBtn(Icons.remove_rounded,
                                  state.portions > 1 ? () => notifier.setPortions(state.portions - 1) : null,
                                  isDark),
                              Expanded(
                                child: Column(
                                  children: [
                                    Text(
                                      '${state.portions}',
                                      style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    Text(
                                      'personne${state.portions > 1 ? 's' : ''}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _portionBtn(Icons.add_rounded,
                                  state.portions < 8 ? () => notifier.setPortions(state.portions + 1) : null,
                                  isDark),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SliderTheme(
                            data: SliderThemeData(
                              activeTrackColor: AppColors.primary,
                              inactiveTrackColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                              thumbColor: AppColors.primary,
                              overlayColor: AppColors.primary.withValues(alpha: 0.1),
                              trackHeight: 4,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                            ),
                            child: Slider(
                              value: state.portions.toDouble(),
                              min: 1,
                              max: 8,
                              divisions: 7,
                              onChanged: (v) => notifier.setPortions(v.round()),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Nutrition ───────────────────────────────────────────────
                    if (state.nutritionLoading)
                      _sectionCard(isDark, child: _nutritionLoading(isDark))
                    else if (state.nutrition != null)
                      _sectionCard(isDark,
                          child: _nutritionCard(state.nutrition!, state.portions, isDark)),

                    // ── Ingrédients ─────────────────────────────────────────────
                    _sectionCard(
                      isDark,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeader('🥕', 'Ingrédients', isDark,
                              trailing: state.translationLoading
                                  ? Row(mainAxisSize: MainAxisSize.min, children: [
                                      const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                                      const SizedBox(width: 6),
                                      Text('Traduction…', style: TextStyle(fontSize: 11, color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary)),
                                    ])
                                  : Text(
                                      '${displayIngredients.length} items',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary,
                                      ),
                                    )),
                          const SizedBox(height: 16),
                          ...List.generate(displayIngredients.length, (i) {
                            final measure = r.measures.elementAtOrNull(i) ?? '';
                            final scaled = _scaleMeasure(measure, state.portions, profile.persons);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [AppColors.primary, AppColors.yellow],
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      displayIngredients[i],
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isDark ? AppColors.textDark : AppColors.textLight,
                                      ),
                                    ),
                                  ),
                                  if (scaled.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        scaled,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),

                    // ── Étapes ──────────────────────────────────────────────────
                    if (displaySteps.isNotEmpty)
                      _sectionCard(
                        isDark,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionHeader('👨‍🍳', 'Préparation', isDark,
                                trailing: Text(
                                  '${displaySteps.length} étapes',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary,
                                  ),
                                )),
                            const SizedBox(height: 18),
                            ...List.generate(displaySteps.length, (i) => _stepTile(i, displaySteps[i], isDark)),
                          ],
                        ),
                      ),

                    // ── Vidéo ───────────────────────────────────────────────────
                    if (r.youtubeUrl != null && r.youtubeUrl!.isNotEmpty)
                      _YoutubeSection(url: r.youtubeUrl!),

                    const SizedBox(height: 140),
                  ],
                ),
              ),
            ],
          ),

          // ── Bottom action bar ─────────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).viewPadding.bottom + 12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBg.withValues(alpha: 0.97) : const Color(0xFFF5F2EE).withValues(alpha: 0.97),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
                    blurRadius: 24,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: state.recipe != null
                  ? Row(
                      children: [
                        // Cuisiner — gradient CTA
                        Expanded(
                          child: GestureDetector(
                            onTap: () => context.push('/cook-mode', extra: r),
                            child: Container(
                              height: 54,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [AppColors.primary, AppColors.yellow],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.4),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('👨‍🍳', style: TextStyle(fontSize: 18)),
                                  SizedBox(width: 8),
                                  Text('Cuisiner maintenant',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      )),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Ensemble
                        _actionIconBtn(
                          emoji: '👥',
                          label: 'Ensemble',
                          color: AppColors.blue,
                          isDark: isDark,
                          onTap: () => context.push('/cook-together-create', extra: r),
                        ),
                        const SizedBox(width: 8),
                        // Commander
                        _actionIconBtn(
                          emoji: '🛒',
                          label: 'Commander',
                          color: isDark ? const Color(0xFF2A2A3E) : Colors.white,
                          isDark: isDark,
                          onTap: () {
                            final orderItems = List.generate(
                              r.ingredients.length,
                              (i) => ShoppingItem(
                                name: r.ingredients[i],
                                measure: i < r.measures.length ? r.measures[i] : '',
                                category: ShoppingItem.categorizeIngredient(r.ingredients[i]),
                                recipeTitle: r.title,
                              ),
                            );
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => OrderIngredientsSheet(items: orderItems),
                            );
                          },
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  // ─── UI helpers ─────────────────────────────────────────────────────────────

  static Widget _circleBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      );

  static Widget _circleBtnColored(IconData icon, Color iconColor, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
      );

  static Widget _gradientPill(String label, List<Color> colors) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
      );

  static Widget _plainPill(String label, bool isDark, {Color? color}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color != null ? color.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color != null ? color.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.35)),
        ),
        child: Text(
          label,
          style: TextStyle(color: color ?? Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      );

  static Widget _statChip(String emoji, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      );

  static Widget _sectionCard(bool isDark, {required Widget child}) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      );

  static Widget _sectionHeader(String emoji, String title, bool isDark, {Widget? trailing}) => Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.yellow],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.textDark : AppColors.textLight,
            ),
          ),
          if (trailing != null) ...[const Spacer(), trailing],
        ],
      );

  static Widget _portionBtn(IconData icon, VoidCallback? onTap, bool isDark) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: onTap != null ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: onTap != null ? AppColors.primary.withValues(alpha: 0.3) : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
          ),
          child: Icon(icon, color: onTap != null ? AppColors.primary : (isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary), size: 20),
        ),
      );

  static Widget _actionIconBtn({
    required String emoji,
    required String label,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 60,
          height: 54,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
            border: color == Colors.white || color == const Color(0xFF2A2A3E)
                ? Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)
                : null,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: isDark ? AppColors.textDark : AppColors.textLight)),
            ],
          ),
        ),
      );

  Widget _stepTile(int index, String step, bool isDark) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.yellow],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(9),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  step,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.55,
                    color: isDark ? AppColors.textDark : AppColors.textLight,
                  ),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _nutritionCard(Map<String, int> n, int portions, bool isDark) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('⚡', 'Valeurs nutritionnelles', isDark,
              trailing: Text(
                'total recette',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary,
                ),
              )),
          const SizedBox(height: 18),
          Row(
            children: [
              _nutriTile('${n['calories'] ?? 0}', 'kcal', AppColors.primary, isDark),
              _nutriTile('${n['protein'] ?? 0}g', 'Protéines', AppColors.green, isDark),
              _nutriTile('${n['carbs'] ?? 0}g', 'Glucides', AppColors.yellow, isDark),
              _nutriTile('${n['fat'] ?? 0}g', 'Lipides', AppColors.purple, isDark),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Par portion : ~${((n['calories'] ?? 0) / (portions == 0 ? 1 : portions)).round()} kcal',
              style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );

  Widget _nutriTile(String value, String label, Color color, bool isDark) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Text(value,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
              const SizedBox(height: 3),
              Text(label,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary,
                  ),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );

  Widget _nutritionLoading(bool isDark) => Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.primary, AppColors.yellow]),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          const Text('⚡', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 6),
          Text(
            'Calcul nutrition IA...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.textDark : AppColors.textLight,
            ),
          ),
          const Spacer(),
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
          ),
        ],
      );

  Widget _imagePlaceholder() => Container(
        color: AppColors.darkCard,
        child: const Center(child: Icon(Icons.restaurant_rounded, size: 60, color: AppColors.primary)),
      );

  Widget _loadingScreen(bool isDark) => Scaffold(
        backgroundColor: isDark ? AppColors.darkBg : const Color(0xFFF5F2EE),
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );

  Widget _errorScreen(BuildContext context, bool isDark) => Scaffold(
        backgroundColor: isDark ? AppColors.darkBg : const Color(0xFFF5F2EE),
        appBar: AppBar(leading: BackButton(onPressed: () => context.pop())),
        body: const Center(child: Text('Recette introuvable')),
      );

  // ─── Collections ────────────────────────────────────────────────────────────

  void _showCollectionSheet(BuildContext context, WidgetRef ref, Recipe r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CollectionSheet(recipe: r, ref: ref),
    );
  }

  // ─── Share ──────────────────────────────────────────────────────────────────

  void _shareRecipe(Recipe r) {
    final ingredients = List.generate(
      r.ingredients.length,
      (i) {
        final measure = r.measures.elementAtOrNull(i) ?? '';
        return measure.isNotEmpty ? '• ${r.ingredients[i]} ($measure)' : '• ${r.ingredients[i]}';
      },
    ).join('\n');

    final stepsText = r.steps.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n');
    final steps = r.steps.isEmpty ? '' : '\n\n👨‍🍳 Préparation :\n$stepsText';

    final cat = r.category != null ? ' · ${r.category}' : '';
    final text = '🍽️ ${r.title}$cat\n\n📋 Ingrédients :\n$ingredients$steps\n\n📱 Partagé depuis CookFast';

    Share.share(text, subject: r.title);
  }

  // ─── Utils ──────────────────────────────────────────────────────────────────

  static int _estimateTime(Recipe r) {
    final base = r.steps.length * 5;
    return base.clamp(15, 90);
  }

  String _scaleMeasure(String measure, int portions, int defaultPortions) {
    if (measure.isEmpty) return '';
    final factor = portions / (defaultPortions == 0 ? 1 : defaultPortions);
    if (factor == 1.0) return measure;
    final result = measure.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)'),
      (match) {
        final val = double.tryParse(match.group(1)!);
        if (val == null) return match.group(0)!;
        final scaled = val * factor;
        return scaled == scaled.roundToDouble()
            ? scaled.toInt().toString()
            : scaled.toStringAsFixed(1);
      },
    );
    return result;
  }

}

// ─── YouTube Section ──────────────────────────────────────────────────────────

class _YoutubeSection extends StatefulWidget {
  final String url;
  const _YoutubeSection({required this.url});

  @override
  State<_YoutubeSection> createState() => _YoutubeSectionState();
}

class _YoutubeSectionState extends State<_YoutubeSection> {
  YoutubePlayerController? _controller;
  bool _showPlayer = false;
  bool _intercepting = false;

  String? get _videoId => YoutubePlayer.convertUrlToId(widget.url);

  void _launch() {
    final id = _videoId;
    if (id == null) return;
    _controller = YoutubePlayerController(
      initialVideoId: id,
      flags: const YoutubePlayerFlags(autoPlay: true, mute: false),
    );
    _controller!.addListener(_onControllerUpdate);
    setState(() => _showPlayer = true);
  }

  // Intercepte le clic sur le bouton fullscreen natif du player
  void _onControllerUpdate() {
    if (!mounted || _intercepting) return;
    if (_controller?.value.isFullScreen == true) {
      _intercepting = true;
      // Reset le flag interne avant le next frame pour éviter la boucle
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _controller?.toggleFullScreenMode();
        _intercepting = false;
        _pushFullScreen();
      });
    }
  }

  void _pushFullScreen() {
    final id = _videoId;
    final position = _controller?.value.position ?? Duration.zero;
    if (id == null) return;

    // Pause le player embarqué pendant le plein écran
    _controller?.pause();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // rootNavigator: true → pousse AU-DESSUS de GoRouter, pas dans le shell
    Navigator.of(context, rootNavigator: true)
        .push(MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => _FullScreenVideoPage(
            videoId: id,
            startAt: position.inSeconds,
          ),
        ))
        .then((_) {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
          SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
        });
  }

  void _close() {
    _controller?.removeListener(_onControllerUpdate);
    _controller?.dispose();
    _controller = null;
    setState(() => _showPlayer = false);
  }

  @override
  void dispose() {
    _controller?.removeListener(_onControllerUpdate);
    _controller?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = _videoId;
    if (id == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 4, height: 20,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Colors.red, Color(0xFFFF6B9D)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                const Text('🎬', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                const Text('Vidéo de la recette',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700, color: Colors.red)),
                const Spacer(),
                if (_showPlayer)
                  GestureDetector(
                    onTap: _close,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: const Text('Fermer',
                          style: TextStyle(
                              color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ),
              ],
            ),
          ),
          // Player or thumbnail
          if (_showPlayer && _controller != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: YoutubePlayer(
                controller: _controller!,
                showVideoProgressIndicator: true,
                progressIndicatorColor: Colors.red,
                progressColors: const ProgressBarColors(
                  playedColor: Colors.red,
                  handleColor: Colors.redAccent,
                ),
              ),
            )
          else
            GestureDetector(
              onTap: _launch,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: 'https://img.youtube.com/vi/$id/hqdefault.jpg',
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(color: AppColors.darkCard),
                        errorWidget: (_, _, _) => Container(
                          color: AppColors.darkCard,
                          child: const Center(
                            child: Icon(Icons.movie_outlined,
                                size: 48, color: Colors.white38),
                          ),
                        ),
                      ),
                      Container(color: Colors.black.withValues(alpha: 0.28)),
                      Center(
                        child: Container(
                          width: 66, height: 66,
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.92),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.red.withValues(alpha: 0.55),
                                  blurRadius: 22, spreadRadius: 2),
                            ],
                          ),
                          child: const Icon(Icons.play_arrow_rounded,
                              color: Colors.white, size: 42),
                        ),
                      ),
                      Positioned(
                        bottom: 10, left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_circle_outline_rounded,
                                  color: Colors.red, size: 14),
                              SizedBox(width: 5),
                              Text('Appuyer pour lancer la vidéo',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Full Screen Video Page ────────────────────────────────────────────────────

class _FullScreenVideoPage extends StatefulWidget {
  final String videoId;
  final int startAt;
  const _FullScreenVideoPage({required this.videoId, required this.startAt});

  @override
  State<_FullScreenVideoPage> createState() => _FullScreenVideoPageState();
}

class _FullScreenVideoPageState extends State<_FullScreenVideoPage> {
  late final YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: YoutubePlayerFlags(autoPlay: true, startAt: widget.startAt),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: YoutubePlayer(
              controller: _controller,
              showVideoProgressIndicator: true,
              progressIndicatorColor: Colors.red,
              progressColors: const ProgressBarColors(
                playedColor: Colors.red,
                handleColor: Colors.redAccent,
              ),
            ),
          ),
          // Bouton quitter plein écran — toujours visible, au-dessus de la navbar
          Positioned(
            top: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.fullscreen_exit_rounded,
                        color: Colors.white, size: 26),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Collection sheet (inline, avoids import cycle) ───────────────────────────

class _CollectionSheet extends ConsumerWidget {
  final Recipe recipe;
  final WidgetRef ref;

  const _CollectionSheet({required this.recipe, required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef innerRef) {
    final isDark = innerRef.watch(themeProvider);
    final collections = innerRef.watch(collectionsProvider);
    final bg = isDark ? AppColors.darkSurface : Colors.white;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final subColor = isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary;
    final navBar = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + navBar),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.primary, AppColors.yellow]),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text('Ajouter à une collection',
                  style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 14),
          if (collections.isEmpty)
            Text('Aucune collection — crée-en une depuis Mes Favoris.',
                style: TextStyle(color: subColor, fontSize: 13))
          else
            ...collections.map((col) {
              final has = col.recipeIds.contains(recipe.id);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: has
                        ? AppColors.purple.withValues(alpha: 0.15)
                        : (isDark ? AppColors.darkCard : AppColors.lightBorder),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    has ? Icons.check_rounded : Icons.add_rounded,
                    color: has ? AppColors.purple : subColor,
                    size: 18,
                  ),
                ),
                title: Text(col.name, style: TextStyle(color: textColor, fontSize: 14)),
                onTap: () {
                  if (has) {
                    innerRef.read(collectionsProvider.notifier).removeRecipe(col.id, recipe.id);
                  } else {
                    innerRef.read(collectionsProvider.notifier).addRecipe(col.id, recipe.id);
                  }
                },
              );
            }),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => context.push('/favorites'),
            icon: const Icon(Icons.favorite_rounded, color: AppColors.primary, size: 16),
            label: const Text('Gérer les collections', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}
