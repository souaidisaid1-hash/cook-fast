import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/recipe.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/services/meal_db_service.dart';

class BatchSelectScreen extends ConsumerStatefulWidget {
  const BatchSelectScreen({super.key});

  @override
  ConsumerState<BatchSelectScreen> createState() => _BatchSelectScreenState();
}

class _BatchSelectScreenState extends ConsumerState<BatchSelectScreen> {
  final _searchCtrl = TextEditingController();
  final List<Recipe> _selected = [];
  List<Recipe> _results = [];
  bool _searching = false;

  static const _maxPremium = 5;
  static const _maxFree = 2;
  static const _min = 2;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    final res = await MealDbService.search(q.trim());
    setState(() {
      _results = res;
      _searching = false;
    });
  }

  void _toggle(Recipe recipe) {
    final isPremium = ref.read(premiumProvider);
    final max = isPremium ? _maxPremium : _maxFree;
    setState(() {
      final idx = _selected.indexWhere((r) => r.id == recipe.id);
      if (idx >= 0) {
        _selected.removeAt(idx);
      } else if (_selected.length < max) {
        _selected.add(recipe);
      } else if (!isPremium) {
        _showUpgradeHint();
      }
    });
  }

  void _showUpgradeHint() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('👑 Premium requis pour plus de 2 recettes'),
      action: SnackBarAction(label: 'Voir', onPressed: () => context.push('/premium')),
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF1a0533),
    ));
  }

  bool _isSelected(String id) => _selected.any((r) => r.id == id);

  void _start() {
    if (_selected.length < _min) return;
    context.push('/batch-cook', extra: List<Recipe>.from(_selected));
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = ref.watch(premiumProvider);
    final max = isPremium ? _maxPremium : _maxFree;
    final favorites = ref.watch(favoritesProvider);

    final isDark = ref.watch(themeProvider);
    final bg = isDark ? AppColors.darkBg : const Color(0xFFF5F2EE);
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final canStart = _selected.length >= _min;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        iconTheme: IconThemeData(color: textColor),
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 4, height: 20,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.primary, AppColors.yellow], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text('Batch Cooking 🍳', style: TextStyle(color: textColor, fontWeight: FontWeight.w800, fontSize: 17)),
          ],
        ),
        actions: [
          if (!isPremium)
            GestureDetector(
              onTap: () => context.push('/premium'),
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF8C00)]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('👑 2 max', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: GestureDetector(
            onTap: canStart ? _start : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: canStart ? const LinearGradient(colors: [AppColors.primary, AppColors.yellow]) : null,
                color: canStart ? null : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                borderRadius: BorderRadius.circular(14),
                boxShadow: canStart ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))] : [],
              ),
              child: Center(
                child: Text(
                  _selected.length < _min
                      ? 'Sélectionne au moins $_min recettes'
                      : 'Démarrer la session (${_selected.length} recettes) 🚀',
                  style: TextStyle(
                    color: canStart ? Colors.white : (isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          if (_selected.isNotEmpty) _buildSelectedBar(isDark),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchCtrl,
              style: TextStyle(color: textColor),
              onChanged: _search,
              decoration: InputDecoration(
                hintText: 'Rechercher une recette...',
                prefixIcon: Icon(Icons.search, color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                      )
                    : null,
                filled: true,
                fillColor: isDark ? AppColors.darkCard : Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: _searchCtrl.text.isNotEmpty
                ? _buildGrid(_results, 'Résultats de recherche', max: max, isDark: isDark, textColor: textColor)
                : _buildGrid(favorites, 'Mes favoris', max: max, isDark: isDark, textColor: textColor, emptyMsg: 'Ajoute des favoris depuis les recettes\nou recherche ci-dessus.'),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedBar(bool isDark) => Container(
        height: 56,
        color: isDark ? AppColors.darkSurface : const Color(0xFFEDEAE4),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: _selected.length,
          itemBuilder: (_, i) {
            final r = _selected[i];
            return Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _recipeColor(i).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _recipeColor(i)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    r.title,
                    style: TextStyle(color: _recipeColor(i), fontSize: 12, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => _toggle(r),
                    child: Icon(Icons.close, size: 14, color: _recipeColor(i)),
                  ),
                ],
              ),
            );
          },
        ),
      );

  Widget _buildGrid(List<Recipe> recipes, String title, {String? emptyMsg, required int max, required bool isDark, required Color textColor}) {
    if (recipes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            emptyMsg ?? 'Aucun résultat',
            textAlign: TextAlign.center,
            style: TextStyle(color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary, fontSize: 14),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(title, style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.85,
            ),
            itemCount: recipes.length,
            itemBuilder: (_, i) => _RecipeSelectCard(
              recipe: recipes[i],
              selected: _isSelected(recipes[i].id),
              isDark: isDark,
              color: _isSelected(recipes[i].id)
                  ? _recipeColor(_selected.indexWhere((r) => r.id == recipes[i].id))
                  : null,
              canAdd: _selected.length < max,
              onTap: () => _toggle(recipes[i]),
            ),
          ),
        ),
      ],
    );
  }
}

Color _recipeColor(int index) {
  const colors = [
    AppColors.primary,
    AppColors.blue,
    AppColors.green,
    AppColors.purple,
    AppColors.yellow,
  ];
  return colors[index.clamp(0, colors.length - 1)];
}

class _RecipeSelectCard extends StatelessWidget {
  final Recipe recipe;
  final bool selected;
  final bool isDark;
  final Color? color;
  final bool canAdd;
  final VoidCallback onTap;

  const _RecipeSelectCard({
    required this.recipe,
    required this.selected,
    required this.isDark,
    this.color,
    required this.canAdd,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = color ?? AppColors.primary;
    return GestureDetector(
      onTap: (selected || canAdd) ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? cardColor : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: selected ? 2 : 1,
          ),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.06), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                  child: recipe.imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: recipe.imageUrl!,
                          height: 100,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          height: 100,
                          color: isDark ? AppColors.darkCard : const Color(0xFFF5F2EE),
                          child: const Center(child: Text('🍽️', style: TextStyle(fontSize: 32))),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    recipe.title,
                    style: TextStyle(color: isDark ? AppColors.textDark : AppColors.textLight, fontSize: 12, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Positioned(
              top: 8,
              right: 8,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: selected ? cardColor : Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: Icon(selected ? Icons.check : Icons.add, color: Colors.white, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
