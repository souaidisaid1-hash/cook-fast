import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/recipe.dart';
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

  const _DetailState({
    this.recipe,
    this.isLoading = true,
    this.nutrition,
    this.nutritionLoading = false,
    this.portions = 2,
  });

  _DetailState copyWith({
    Recipe? recipe,
    bool? isLoading,
    Map<String, int>? nutrition,
    bool? nutritionLoading,
    int? portions,
  }) =>
      _DetailState(
        recipe: recipe ?? this.recipe,
        isLoading: isLoading ?? this.isLoading,
        nutrition: nutrition ?? this.nutrition,
        nutritionLoading: nutritionLoading ?? this.nutritionLoading,
        portions: portions ?? this.portions,
      );
}

class _DetailNotifier extends StateNotifier<_DetailState> {
  _DetailNotifier(Recipe? initial, String id, int defaultPortions)
      : super(_DetailState(recipe: initial, isLoading: initial == null, portions: defaultPortions)) {
    if (initial == null) _fetchById(id);
    if (initial != null) _loadNutrition(initial);
  }

  Future<void> _fetchById(String id) async {
    final recipe = await MealDbService.byId(id);
    if (recipe != null) {
      state = state.copyWith(recipe: recipe, isLoading: false);
      _loadNutrition(recipe);
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
    state = state.copyWith(nutrition: nutrition, nutritionLoading: false);
  }

  void setPortions(int p) => state = state.copyWith(portions: p);
}

final _detailProvider = StateNotifierProvider.family.autoDispose<_DetailNotifier, _DetailState, (Recipe?, String, int)>(
  (ref, args) => _DetailNotifier(args.$1, args.$2, args.$3),
);

// ─── Screen ─────────────────────────────────────────────────────────────────────

class RecipeDetailScreen extends ConsumerWidget {
  final Recipe? recipe;
  final String id;

  const RecipeDetailScreen({super.key, this.recipe, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider);
    final profile = ref.watch(userProfileProvider);
    final state = ref.watch(_detailProvider((recipe, id, profile.persons)));
    final notifier = ref.read(_detailProvider((recipe, id, profile.persons)).notifier);

    if (state.isLoading) return _loadingScreen(isDark);
    if (state.recipe == null) return _errorScreen(context, isDark);

    final r = state.recipe!;
    final isFav = ref.watch(favoritesProvider).any((fav) => fav.id == r.id);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // ── Hero image ──────────────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 320,
                pinned: true,
                backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
                leading: GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                  ),
                ),
                actions: [
                  GestureDetector(
                    onTap: () => _shareRecipe(r),
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(0, 8, 4, 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.ios_share_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                  if (isFav)
                    GestureDetector(
                      onTap: () => _showCollectionSheet(context, ref, r),
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(0, 8, 4, 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.bookmark_add_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  GestureDetector(
                    onTap: () => ref.read(favoritesProvider.notifier).toggle(r),
                    child: Container(
                      margin: const EdgeInsets.all(8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: isFav ? Colors.red : Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: r.imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: r.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: AppColors.darkCard),
                          errorWidget: (_, __, ___) => _imagePlaceholder(),
                        )
                      : _imagePlaceholder(),
                ),
              ),

              // ── Content ─────────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Titre + badges
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.title,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.textDark : AppColors.textLight,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (r.category != null) _badge(r.category!, AppColors.primary, Colors.white),
                              if (r.area != null) _badge('🌍 ${r.area!}', isDark ? AppColors.darkCard : AppColors.lightBorder, isDark ? AppColors.textDark : AppColors.textLight),
                              if (r.isVegetarian) _badge('🌿 Végétarien', AppColors.green.withValues(alpha: 0.15), AppColors.green),
                              if (r.cookTimeMinutes != null) _badge('⏱ ${r.cookTimeMinutes} min', isDark ? AppColors.darkCard : AppColors.lightBorder, AppColors.primary),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Portions slider ───────────────────────────────────────
                    _card(
                      isDark,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Portions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? AppColors.textDark : AppColors.textLight)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${state.portions} personne${state.portions > 1 ? 's' : ''}',
                                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(8, (i) => Text('${i + 1}', style: TextStyle(fontSize: 11, color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary))),
                          ),
                        ],
                      ),
                    ),

                    // ── Nutrition ──────────────────────────────────────────────
                    if (state.nutritionLoading)
                      _card(isDark, child: _nutritionLoading(isDark))
                    else if (state.nutrition != null)
                      _card(isDark, child: _nutritionCard(state.nutrition!, state.portions, isDark)),

                    // ── Ingrédients ────────────────────────────────────────────
                    _card(
                      isDark,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('🥕', style: TextStyle(fontSize: 20)),
                              const SizedBox(width: 8),
                              Text(
                                'Ingrédients',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? AppColors.textDark : AppColors.textLight),
                              ),
                              const Spacer(),
                              Text(
                                '${r.ingredients.length} items',
                                style: TextStyle(fontSize: 13, color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          ...List.generate(r.ingredients.length, (i) {
                            final measure = r.measures.elementAtOrNull(i) ?? '';
                            final scaled = _scaleMeasure(measure, state.portions, profile.persons);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      r.ingredients[i],
                                      style: TextStyle(fontSize: 14, color: isDark ? AppColors.textDark : AppColors.textLight),
                                    ),
                                  ),
                                  if (scaled.isNotEmpty)
                                    Text(
                                      scaled,
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.primary),
                                    ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),

                    // ── Étapes ────────────────────────────────────────────────
                    if (r.steps.isNotEmpty)
                      _card(
                        isDark,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text('👨‍🍳', style: TextStyle(fontSize: 20)),
                                const SizedBox(width: 8),
                                Text(
                                  'Préparation',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? AppColors.textDark : AppColors.textLight),
                                ),
                                const Spacer(),
                                Text(
                                  '${r.steps.length} étapes',
                                  style: TextStyle(fontSize: 13, color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ...List.generate(r.steps.length, (i) => _stepTile(i, r.steps[i], isDark)),
                          ],
                        ),
                      ),

                    // ── YouTube ────────────────────────────────────────────────
                    if (r.youtubeUrl != null && r.youtubeUrl!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: GestureDetector(
                          onTap: () => _launchUrl(r.youtubeUrl!),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.play_circle_filled_rounded, color: Colors.red, size: 28),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Vidéo de la recette', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red, fontSize: 15)),
                                      Text('Voir sur YouTube', style: TextStyle(color: Colors.red, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                Icon(Icons.open_in_new_rounded, color: Colors.red, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // Espace pour le bouton fixe
                    const SizedBox(height: 140),
                  ],
                ),
              ),
            ],
          ),

          // ── Bouton fixe Démarrer la cuisson ─────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBg : AppColors.lightBg,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: state.recipe != null
                  ? Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => context.push('/cook-mode', extra: r),
                            icon: const Text('👨‍🍳', style: TextStyle(fontSize: 16)),
                            label: const Text('Cuisiner', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 54),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => context.push('/cook-together-create', extra: r),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.blue,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 54),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('👥', style: TextStyle(fontSize: 18)),
                              Text('Ensemble', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
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
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1C1C2E),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 54),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: const BorderSide(color: AppColors.darkBorder),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('🛒', style: TextStyle(fontSize: 18)),
                              Text('Commander', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                            ],
                          ),
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
        return measure.isNotEmpty
            ? '• ${r.ingredients[i]} ($measure)'
            : '• ${r.ingredients[i]}';
      },
    ).join('\n');

    final steps = r.steps.isEmpty
        ? ''
        : '\n\n👨‍🍳 Préparation :\n' +
            r.steps
                .asMap()
                .entries
                .map((e) => '${e.key + 1}. ${e.value}')
                .join('\n');

    final text = '🍽️ ${r.title}'
        '${r.category != null ? ' · ${r.category}' : ''}\n\n'
        '📋 Ingrédients :\n$ingredients'
        '$steps\n\n'
        '📱 Partagé depuis CookFast';

    Share.share(text, subject: r.title);
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  Widget _card(bool isDark, {required Widget child}) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: child,
      );

  Widget _badge(String label, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
      );

  Widget _stepTile(int index, String step, bool isDark) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  step,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: isDark ? AppColors.textDark : AppColors.textLight,
                  ),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _nutritionCard(Map<String, int> n, int portions, bool isDark) {
    final factor = portions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('⚡', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(
              'Valeurs nutritionnelles',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? AppColors.textDark : AppColors.textLight),
            ),
            const Spacer(),
            Text(
              'total recette',
              style: TextStyle(fontSize: 11, color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _nutriStat('${(n['calories'] ?? 0)}', 'kcal', AppColors.primary, isDark),
            _nutriStat('${n['protein'] ?? 0}g', 'Protéines', AppColors.green, isDark),
            _nutriStat('${n['carbs'] ?? 0}g', 'Glucides', AppColors.yellow, isDark),
            _nutriStat('${n['fat'] ?? 0}g', 'Lipides', AppColors.purple, isDark),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Par portion : ~${((n['calories'] ?? 0) / (factor == 0 ? 1 : factor)).round()} kcal',
          style: TextStyle(fontSize: 12, color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary),
        ),
      ],
    );
  }

  Widget _nutriStat(String value, String label, Color color, bool isDark) => Expanded(
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary), textAlign: TextAlign.center),
          ],
        ),
      );

  Widget _nutritionLoading(bool isDark) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('⚡', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text('Calcul nutrition IA...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? AppColors.textDark : AppColors.textLight)),
              const Spacer(),
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
            ],
          ),
        ],
      );

  Widget _imagePlaceholder() => Container(
        color: AppColors.darkCard,
        child: const Center(child: Icon(Icons.restaurant_rounded, size: 60, color: AppColors.primary)),
      );

  Widget _loadingScreen(bool isDark) => Scaffold(
        backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );

  Widget _errorScreen(BuildContext context, bool isDark) => Scaffold(
        backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
        appBar: AppBar(leading: BackButton(onPressed: () => context.pop())),
        body: const Center(child: Text('Recette introuvable')),
      );

  String _scaleMeasure(String measure, int portions, int defaultPortions) {
    if (measure.isEmpty) return '';
    final factor = portions / (defaultPortions == 0 ? 1 : defaultPortions);
    if (factor == 1.0) return measure;

    // Essaie de scaler les nombres dans la mesure
    final result = measure.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)'),
      (match) {
        final val = double.tryParse(match.group(1)!);
        if (val == null) return match.group(0)!;
        final scaled = val * factor;
        return scaled == scaled.roundToDouble() ? scaled.toInt().toString() : scaled.toStringAsFixed(1);
      },
    );
    return result;
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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
    final subColor =
        isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary;
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
          Text('Ajouter à une collection',
              style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
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
                title: Text(col.name,
                    style: TextStyle(color: textColor, fontSize: 14)),
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
            label: const Text('Gérer les collections',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}
