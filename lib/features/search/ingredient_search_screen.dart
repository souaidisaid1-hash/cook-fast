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
  ConsumerState<IngredientSearchScreen> createState() => _IngredientSearchScreenState();
}

class _IngredientSearchScreenState extends ConsumerState<IngredientSearchScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  final List<String> _ingredients = [];
  String? _selectedCategory;
  _DurationFilter _duration = _DurationFilter.any;

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

  void _addIngredient(String val) {
    final t = val.trim();
    if (t.isEmpty) return;
    if (_ingredients.any((i) => i.toLowerCase() == t.toLowerCase())) return;
    setState(() => _ingredients.add(t));
    _ctrl.clear();
    _focus.requestFocus();
  }

  void _removeIngredient(String tag) => setState(() => _ingredients.remove(tag));

  void _useFridge() {
    final fridge = ref.read(fridgeProvider);
    setState(() {
      for (final item in fridge) {
        if (!_ingredients.any((i) => i.toLowerCase() == item.name.toLowerCase())) {
          _ingredients.add(item.name);
        }
      }
    });
  }

  bool get _hasFilters =>
      _ingredients.isNotEmpty || _selectedCategory != null || _duration != _DurationFilter.any;

  Future<void> _search() async {
    FocusScope.of(context).unfocus();
    setState(() { _loading = true; _searched = false; });

    List<Recipe> raw = [];
    List<int> rawScores = [];

    if (_ingredients.isNotEmpty) {
      final res = await MealDbService.byIngredients(_ingredients);
      raw = res.recipes;
      rawScores = res.scores;
      if (_selectedCategory != null) {
        final filtered = <Recipe>[];
        final filteredScores = <int>[];
        for (int i = 0; i < raw.length; i++) {
          if ((raw[i].category ?? '').toLowerCase() == _selectedCategory!.toLowerCase()) {
            filtered.add(raw[i]);
            filteredScores.add(rawScores[i]);
          }
        }
        raw = filtered;
        rawScores = filteredScores;
      }
    } else if (_selectedCategory != null) {
      raw = await MealDbService.byCategory(_selectedCategory!);
      rawScores = List.filled(raw.length, 1);
    }

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

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final bg = isDark ? AppColors.darkBg : const Color(0xFFF5F2EE);
    final cardBg = isDark ? AppColors.darkCard : Colors.white;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final subColor = isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary;
    final fridge = ref.watch(fridgeProvider);
    final navBar = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          Container(
            color: bg,
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 14, 20, 14),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 4, height: 22,
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
                        Text('Recherche', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: textColor)),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 14),
                      child: Text('Filtre par ingrédients & type',
                          style: TextStyle(fontSize: 12, color: subColor)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Filter panel ─────────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Ingredient input ───────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                        ),
                        child: TextField(
                          controller: _ctrl,
                          focusNode: _focus,
                          style: TextStyle(color: textColor, fontSize: 14),
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: 'Ajouter un ingrédient…',
                            hintStyle: TextStyle(color: subColor, fontSize: 14),
                            prefixIcon: const Icon(Icons.egg_alt_rounded, color: AppColors.primary, size: 20),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            isDense: true,
                          ),
                          onSubmitted: _addIngredient,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _iconBtn(Icons.add_rounded, AppColors.primary, () => _addIngredient(_ctrl.text)),
                    if (fridge.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _emojiBtn('🧊', AppColors.blue, _useFridge),
                    ],
                  ],
                ),

                // Ingredient tags
                if (_ingredients.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _ingredients.map((t) => _IngTag(label: t, onRemove: () => _removeIngredient(t))).toList(),
                  ),
                ],

                const SizedBox(height: 14),
                _accentDivider(isDark),
                const SizedBox(height: 12),

                // ── Type filter ────────────────────────────────────────────────
                _filterLabel('TYPE DE PLAT', subColor),
                const SizedBox(height: 8),
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _kCategories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (_, i) {
                      final cat = _kCategories[i];
                      final selected = _selectedCategory == cat.$2;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedCategory = selected ? null : cat.$2),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: selected
                                ? const LinearGradient(colors: [AppColors.green, Color(0xFF27AE60)])
                                : null,
                            color: selected ? null : bg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected ? Colors.transparent : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                            ),
                            boxShadow: selected
                                ? [BoxShadow(color: AppColors.green.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))]
                                : null,
                          ),
                          child: Text(
                            '${cat.$1} ${cat.$2}',
                            style: TextStyle(
                              color: selected ? Colors.white : textColor,
                              fontSize: 12,
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 12),
                _accentDivider(isDark),
                const SizedBox(height: 12),

                // ── Duration filter ────────────────────────────────────────────
                Row(
                  children: [
                    _filterLabel('DURÉE', subColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _DurationFilter.values.map((f) {
                            final selected = _duration == f;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: GestureDetector(
                                onTap: () => setState(() => _duration = f),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    gradient: selected
                                        ? const LinearGradient(colors: [AppColors.primary, AppColors.yellow])
                                        : null,
                                    color: selected ? null : bg,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: selected ? Colors.transparent : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                    ),
                                    boxShadow: selected
                                        ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))]
                                        : null,
                                  ),
                                  child: Text(
                                    f.label,
                                    style: TextStyle(
                                      color: selected ? Colors.white : textColor,
                                      fontSize: 12,
                                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // ── Search button ──────────────────────────────────────────────
                Row(
                  children: [
                    if (_hasFilters)
                      GestureDetector(
                        onTap: () => setState(() {
                          _ingredients.clear();
                          _selectedCategory = null;
                          _duration = _DurationFilter.any;
                          _searched = false;
                        }),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                          ),
                          child: const Text('Effacer',
                              style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    Expanded(
                      child: GestureDetector(
                        onTap: (!_hasFilters || _loading) ? null : _search,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: _hasFilters && !_loading
                                ? const LinearGradient(colors: [AppColors.primary, AppColors.yellow])
                                : null,
                            color: !_hasFilters || _loading
                                ? (isDark ? AppColors.darkBorder : AppColors.lightBorder)
                                : null,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: _hasFilters && !_loading
                                ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_loading)
                                const SizedBox(
                                  width: 18, height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              else
                                const Icon(Icons.search_rounded, size: 18, color: Colors.white),
                              const SizedBox(width: 8),
                              Text(
                                _loading ? 'Recherche…' : 'Rechercher',
                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
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
                ? _buildIdle(textColor, subColor, isDark)
                : _results.isEmpty
                    ? _buildNoResults(textColor, subColor)
                    : _buildGrid(textColor, subColor, isDark, navBar),
          ),
        ],
      ),
    );
  }

  static Widget _filterLabel(String text, Color subColor) => Text(
        text,
        style: TextStyle(color: subColor, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8),
      );

  static Widget _accentDivider(bool isDark) => Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary.withValues(alpha: 0.3), Colors.transparent],
          ),
        ),
      );

  static Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color, AppColors.yellow]),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      );

  static Widget _emojiBtn(String emoji, Color color, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 18))),
        ),
      );

  Widget _buildIdle(Color textColor, Color subColor, bool isDark) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary.withValues(alpha: 0.15), AppColors.yellow.withValues(alpha: 0.08)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Center(child: Text('🔍', style: TextStyle(fontSize: 40))),
              ),
              const SizedBox(height: 20),
              Text('Recherche avancée',
                  style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                'Combine ingrédients, type de plat\net durée de préparation.',
                style: TextStyle(color: subColor, fontSize: 14, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: ['🥩 Viande', '🥗 Légumes', '🍝 Pâtes', '🐟 Poisson']
                    .map((t) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                            borderRadius: BorderRadius.circular(20),
                            color: isDark ? AppColors.darkCard : Colors.white,
                          ),
                          child: Text(t, style: TextStyle(color: subColor, fontSize: 12, fontWeight: FontWeight.w500)),
                        ))
                    .toList(),
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
                  style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text("Essaie d'élargir les filtres.",
                  style: TextStyle(color: subColor, fontSize: 13),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );

  Widget _buildGrid(Color textColor, Color subColor, bool isDark, double navBar) {
    final total = _ingredients.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Text(
            '${_results.length} recette${_results.length > 1 ? 's' : ''}',
            style: TextStyle(color: subColor, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + navBar),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.75,
            ),
            itemCount: _results.length,
            itemBuilder: (_, i) {
              final r = _results[i];
              final dur = _estimateDuration(r.steps);
              return GestureDetector(
                onTap: () => context.push('/recipe/${r.id}', extra: r),
                child: _SearchRecipeCard(
                  recipe: r,
                  matched: total > 0 ? _scores[i] : null,
                  total: total,
                  durationMin: dur,
                  isDark: isDark,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Ingredient tag ─────────────────────────────────────────────────────────────

class _IngTag extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _IngTag({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary.withValues(alpha: 0.15), AppColors.yellow.withValues(alpha: 0.08)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onRemove,
              child: const Icon(Icons.close_rounded, size: 15, color: AppColors.primary),
            ),
          ],
        ),
      );
}

// ── Search result card ─────────────────────────────────────────────────────────

class _SearchRecipeCard extends StatelessWidget {
  final Recipe recipe;
  final int? matched;
  final int total;
  final int durationMin;
  final bool isDark;

  const _SearchRecipeCard({
    required this.recipe,
    required this.matched,
    required this.total,
    required this.durationMin,
    required this.isDark,
  });

  Color get _matchColor {
    if (matched == null || total <= 1) return AppColors.green;
    if (matched! == total) return AppColors.green;
    if (matched! >= total * 0.6) return AppColors.yellow;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Photo
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        recipe.imageUrl != null
                            ? CachedNetworkImage(imageUrl: recipe.imageUrl!, fit: BoxFit.cover)
                            : Container(
                                color: isDark ? AppColors.darkBg : const Color(0xFFF5F2EE),
                                child: const Center(child: Text('🍽️', style: TextStyle(fontSize: 32))),
                              ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)],
                              stops: const [0.5, 1.0],
                            ),
                          ),
                        ),
                        if (recipe.category != null)
                          Positioned(
                            bottom: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                recipe.category!,
                                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Info
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipe.title,
                        style: TextStyle(
                          color: isDark ? AppColors.textDark : AppColors.textLight,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.yellow.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '⏱ ${durationMin}min',
                          style: const TextStyle(color: AppColors.yellow, fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Match badge
            if (matched != null)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: _matchColor.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [BoxShadow(color: _matchColor.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: Text(
                    total <= 1 ? '✓' : '$matched/$total',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
          ],
        ),
      );
}
