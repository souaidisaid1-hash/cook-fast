import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/recipe.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/services/meal_db_service.dart';

// ── Duration filter ────────────────────────────────────────────────────────────

enum _DurationFilter {
  any('Toutes', null, null),
  quick('⚡ Rapide', 0, 20),
  medium('⏱️ Moyen', 21, 45),
  long('🕐 Long', 46, null);

  final String label;
  final int? min;
  final int? max;
  const _DurationFilter(this.label, this.min, this.max);
}

// ── Categories (MealDB names) ─────────────────────────────────────────────────

const _kCategories = [
  ('🥩', 'Beef'),
  ('🍗', 'Chicken'),
  ('🐑', 'Lamb'),
  ('🥓', 'Pork'),
  ('🐟', 'Seafood'),
  ('🥗', 'Vegetarian'),
  ('🍮', 'Dessert'),
  ('🥞', 'Breakfast'),
  ('🍝', 'Pasta'),
  ('🍲', 'Miscellaneous'),
];

// ── Duration estimator ────────────────────────────────────────────────────────

int _estimateDuration(List<String> steps) {
  int total = 0;
  for (final step in steps) {
    final lower = step.toLowerCase();
    final m = RegExp(r'(\d+)\s*min').firstMatch(lower);
    if (m != null) {
      total += int.tryParse(m.group(1)!) ?? 5;
    } else if (lower.contains('hour') || lower.contains('heure')) {
      total += 60;
    } else if (lower.contains('mijoter') || lower.contains('simmer')) {
      total += 20;
    } else if (lower.contains('cuire') || lower.contains('bouillir')) {
      total += 15;
    } else {
      total += 5;
    }
  }
  return total.clamp(5, 300);
}

bool _matchesDuration(Recipe r, _DurationFilter f) {
  if (f == _DurationFilter.any) return true;
  final dur = _estimateDuration(r.steps);
  if (f.min != null && dur < f.min!) return false;
  if (f.max != null && dur > f.max!) return false;
  return true;
}

// ── Screen ────────────────────────────────────────────────────────────────────

class IngredientSearchScreen extends ConsumerStatefulWidget {
  const IngredientSearchScreen({super.key});

  @override
  ConsumerState<IngredientSearchScreen> createState() =>
      _IngredientSearchScreenState();
}

class _IngredientSearchScreenState
    extends ConsumerState<IngredientSearchScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  // Filters state
  final List<String> _ingredients = [];
  String? _selectedCategory;
  _DurationFilter _duration = _DurationFilter.any;

  // Results
  List<Recipe> _results = [];
  List<int> _scores = [];
  bool _loading = false;
  bool _searched = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ── Ingredient tags ──────────────────────────────────────────────────────────

  void _addIngredient(String val) {
    final t = val.trim();
    if (t.isEmpty) return;
    if (_ingredients.any((i) => i.toLowerCase() == t.toLowerCase())) return;
    setState(() => _ingredients.add(t));
    _ctrl.clear();
    _focus.requestFocus();
  }

  void _removeIngredient(String tag) =>
      setState(() => _ingredients.remove(tag));

  void _useFridge() {
    final fridge = ref.read(fridgeProvider);
    setState(() {
      for (final ing in fridge) {
        if (!_ingredients.any((i) => i.toLowerCase() == ing.toLowerCase())) {
          _ingredients.add(ing);
        }
      }
    });
  }

  // ── Search ───────────────────────────────────────────────────────────────────

  bool get _hasFilters =>
      _ingredients.isNotEmpty ||
      _selectedCategory != null ||
      _duration != _DurationFilter.any;

  Future<void> _search() async {
    FocusScope.of(context).unfocus();
    setState(() { _loading = true; _searched = false; });

    List<Recipe> raw = [];
    List<int> rawScores = [];

    if (_ingredients.isNotEmpty) {
      // Search by ingredients, optionally filtered by category
      final res = await MealDbService.byIngredients(_ingredients);
      raw = res.recipes;
      rawScores = res.scores;
      // Filter by category client-side
      if (_selectedCategory != null) {
        final filtered = <Recipe>[];
        final filteredScores = <int>[];
        for (int i = 0; i < raw.length; i++) {
          if ((raw[i].category ?? '').toLowerCase() ==
              _selectedCategory!.toLowerCase()) {
            filtered.add(raw[i]);
            filteredScores.add(rawScores[i]);
          }
        }
        raw = filtered;
        rawScores = filteredScores;
      }
    } else if (_selectedCategory != null) {
      // Search by category only
      raw = await MealDbService.byCategory(_selectedCategory!);
      rawScores = List.filled(raw.length, 1);
    }

    // Apply duration filter client-side
    final finalRecipes = <Recipe>[];
    final finalScores = <int>[];
    for (int i = 0; i < raw.length; i++) {
      if (_matchesDuration(raw[i], _duration)) {
        finalRecipes.add(raw[i]);
        finalScores.add(rawScores[i]);
      }
    }

    setState(() {
      _results = finalRecipes;
      _scores = finalScores;
      _loading = false;
      _searched = true;
    });
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightCard;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final subColor =
        isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary;
    final fridge = ref.watch(fridgeProvider);
    final navBar = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        iconTheme: IconThemeData(color: textColor),
        title: Text('Recherche & Filtres',
            style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 17, color: textColor)),
        elevation: 0,
      ),
      body: Column(
        children: [
          // ── Filters panel ───────────────────────────────────────────────────
          Container(
            color: surfaceColor,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Ingredient input ─────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        focusNode: _focus,
                        style: TextStyle(color: textColor, fontSize: 14),
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Ajouter un ingrédient…',
                          hintStyle:
                              TextStyle(color: subColor, fontSize: 14),
                          filled: true,
                          fillColor: bg,
                          prefixIcon: const Icon(Icons.egg_alt_rounded,
                              color: AppColors.primary, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                          isDense: true,
                        ),
                        onSubmitted: _addIngredient,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _PillBtn(
                      label: '+',
                      color: AppColors.primary,
                      onTap: () => _addIngredient(_ctrl.text),
                    ),
                    if (fridge.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _PillBtn(
                        label: '🧊',
                        color: AppColors.blue,
                        onTap: _useFridge,
                      ),
                    ],
                  ],
                ),

                // Ingredient tags
                if (_ingredients.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _ingredients
                        .map((t) => _Tag(
                              label: t,
                              color: AppColors.primary,
                              onRemove: () => _removeIngredient(t),
                            ))
                        .toList(),
                  ),
                ],

                const SizedBox(height: 12),
                _divider(isDark),
                const SizedBox(height: 10),

                // ── Type filter ──────────────────────────────────────────────
                Text('Type',
                    style: TextStyle(
                        color: subColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _kCategories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (_, i) {
                      final cat = _kCategories[i];
                      final selected = _selectedCategory == cat.$2;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _selectedCategory =
                              selected ? null : cat.$2;
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.green.withValues(alpha: 0.18)
                                : bg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected
                                  ? AppColors.green
                                  : (isDark
                                      ? AppColors.darkBorder
                                      : AppColors.lightBorder),
                            ),
                          ),
                          child: Text(
                            '${cat.$1} ${cat.$2}',
                            style: TextStyle(
                              color: selected
                                  ? AppColors.green
                                  : textColor,
                              fontSize: 12,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 10),
                _divider(isDark),
                const SizedBox(height: 10),

                // ── Duration filter ──────────────────────────────────────────
                Row(
                  children: [
                    Text('Durée',
                        style: TextStyle(
                            color: subColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8)),
                    const SizedBox(width: 12),
                    ..._DurationFilter.values.map((f) {
                      final selected = _duration == f;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: GestureDetector(
                          onTap: () => setState(() => _duration = f),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.yellow.withValues(alpha: 0.18)
                                  : bg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: selected
                                    ? AppColors.yellow
                                    : (isDark
                                        ? AppColors.darkBorder
                                        : AppColors.lightBorder),
                              ),
                            ),
                            child: Text(
                              f.label,
                              style: TextStyle(
                                color: selected
                                    ? AppColors.yellow
                                    : textColor,
                                fontSize: 12,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),

                const SizedBox(height: 12),

                // ── Search button ────────────────────────────────────────────
                Row(
                  children: [
                    if (_hasFilters)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _ingredients.clear();
                            _selectedCategory = null;
                            _duration = _DurationFilter.any;
                            _searched = false;
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: Colors.red.withValues(alpha: 0.3)),
                            ),
                            child: const Text('Effacer',
                                style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: (!_hasFilters || _loading) ? null : _search,
                        icon: _loading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.search_rounded, size: 18),
                        label: Text(
                          _loading ? 'Recherche…' : 'Rechercher',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Results ──────────────────────────────────────────────────────────
          Expanded(
            child: !_searched
                ? _buildIdle(textColor, subColor)
                : _results.isEmpty
                    ? _buildNoResults(textColor, subColor)
                    : _buildGrid(cardColor, textColor, subColor, isDark, navBar),
          ),
        ],
      ),
    );
  }

  Widget _divider(bool isDark) => Container(
        height: 1,
        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      );

  Widget _buildIdle(Color textColor, Color subColor) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🔍', style: TextStyle(fontSize: 52)),
              const SizedBox(height: 16),
              Text('Recherche avancée',
                  style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                'Combine ingrédients, type de plat\net durée de préparation.',
                style:
                    TextStyle(color: subColor, fontSize: 14, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );

  Widget _buildNoResults(Color textColor, Color subColor) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('😕', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text('Aucune recette trouvée',
                  style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Essaie d\'élargir les filtres.',
                  style: TextStyle(color: subColor, fontSize: 13),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );

  Widget _buildGrid(Color cardColor, Color textColor, Color subColor,
      bool isDark, double navBar) {
    final total = _ingredients.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Text(
            '${_results.length} recette${_results.length > 1 ? 's' : ''}',
            style: TextStyle(
                color: subColor,
                fontSize: 13,
                fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + navBar),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.80,
            ),
            itemCount: _results.length,
            itemBuilder: (_, i) {
              final r = _results[i];
              final dur = _estimateDuration(r.steps);
              return _RecipeCard(
                recipe: r,
                matched: total > 0 ? _scores[i] : null,
                total: total,
                durationMin: dur,
                isDark: isDark,
                cardColor: cardColor,
                textColor: textColor,
                subColor: subColor,
                onTap: () =>
                    context.push('/recipe/${r.id}', extra: r),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _PillBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _PillBtn(
      {required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(10)),
          child: Center(
              child: Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700))),
        ),
      );
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onRemove;
  const _Tag(
      {required this.label, required this.color, required this.onRemove});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onRemove,
              child: Icon(Icons.close_rounded, size: 15, color: color),
            ),
          ],
        ),
      );
}

class _RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final int? matched;
  final int total;
  final int durationMin;
  final bool isDark;
  final Color cardColor;
  final Color textColor;
  final Color subColor;
  final VoidCallback onTap;

  const _RecipeCard({
    required this.recipe,
    required this.matched,
    required this.total,
    required this.durationMin,
    required this.isDark,
    required this.cardColor,
    required this.textColor,
    required this.subColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final matchColor = matched == null
        ? AppColors.green
        : total <= 1
            ? AppColors.green
            : matched! == total
                ? AppColors.green
                : matched! >= total * 0.6
                    ? AppColors.yellow
                    : AppColors.primary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
            color: cardColor, borderRadius: BorderRadius.circular(16)),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: recipe.imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: recipe.imageUrl!,
                          height: 108,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          height: 108,
                          color: isDark
                              ? AppColors.darkBg
                              : AppColors.lightBg,
                          child: const Center(
                              child: Text('🍽️',
                                  style: TextStyle(fontSize: 30)))),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(recipe.title,
                          style: TextStyle(
                              color: textColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          // Duration badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.yellow
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '⏱ ${durationMin}min',
                              style: const TextStyle(
                                  color: AppColors.yellow,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (recipe.category != null) ...[
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(recipe.category!,
                                  style: TextStyle(
                                      color: subColor, fontSize: 10),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Ingredient match badge (only when searching by ingredient)
            if (matched != null)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: matchColor.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    total <= 1 ? '✓' : '$matched/$total',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
