import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/recipe.dart';
import '../../shared/providers/app_providers.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  String? _selectedCollectionId;

  void _showCollectionSheet(Recipe recipe) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CollectionManagerSheet(recipe: recipe),
    );
  }

  void _showCreateDialog() {
    final ctrl = TextEditingController();
    final isDark = ref.read(themeProvider);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Nouvelle collection',
            style: TextStyle(color: isDark ? AppColors.textDark : AppColors.textLight, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: isDark ? AppColors.textDark : AppColors.textLight),
          decoration: InputDecoration(
            hintText: 'Ex: Repas rapides',
            hintStyle: TextStyle(color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) ref.read(collectionsProvider.notifier).create(v.trim());
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.primary, AppColors.yellow]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextButton(
              onPressed: () {
                if (ctrl.text.trim().isNotEmpty) ref.read(collectionsProvider.notifier).create(ctrl.text.trim());
                Navigator.pop(ctx);
              },
              child: const Text('Créer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  void _showCollectionOptions(RecipeCollection col) {
    final isDark = ref.read(themeProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.of(context).viewPadding.bottom),
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
              Row(children: [
                Container(
                  width: 4, height: 18,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.primary, AppColors.yellow]),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(col.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: isDark ? AppColors.textDark : AppColors.textLight,
                      )),
                ),
              ]),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.edit_rounded, color: AppColors.primary, size: 20),
                ),
                title: Text('Renommer', style: TextStyle(color: isDark ? AppColors.textDark : AppColors.textLight)),
                onTap: () {
                  Navigator.pop(context);
                  final ctrl = TextEditingController(text: col.name);
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: Text('Renommer',
                          style: TextStyle(color: isDark ? AppColors.textDark : AppColors.textLight, fontWeight: FontWeight.w700)),
                      content: TextField(
                        controller: ctrl,
                        autofocus: true,
                        style: TextStyle(color: isDark ? AppColors.textDark : AppColors.textLight),
                        decoration: InputDecoration(
                          hintText: 'Nouveau nom',
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.primary),
                          ),
                        ),
                        onSubmitted: (v) {
                          if (v.trim().isNotEmpty) ref.read(collectionsProvider.notifier).rename(col.id, v.trim());
                          Navigator.pop(ctx);
                        },
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
                        Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [AppColors.primary, AppColors.yellow]),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: TextButton(
                            onPressed: () {
                              if (ctrl.text.trim().isNotEmpty) ref.read(collectionsProvider.notifier).rename(col.id, ctrl.text.trim());
                              Navigator.pop(ctx);
                            },
                            child: const Text('OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                ),
                title: const Text('Supprimer', style: TextStyle(color: Colors.red)),
                onTap: () {
                  ref.read(collectionsProvider.notifier).delete(col.id);
                  if (_selectedCollectionId == col.id) setState(() => _selectedCollectionId = null);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final bg = isDark ? AppColors.darkBg : const Color(0xFFF5F2EE);
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final subColor = isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary;
    final navBar = MediaQuery.of(context).viewPadding.bottom;

    final favorites = ref.watch(favoritesProvider);
    final collections = ref.watch(collectionsProvider);

    final displayedRecipes = _selectedCollectionId == null
        ? favorites
        : () {
            final col = collections.firstWhere(
              (c) => c.id == _selectedCollectionId,
              orElse: () => const RecipeCollection(id: '', name: '', recipeIds: []),
            );
            return favorites.where((r) => col.recipeIds.contains(r.id)).toList();
          }();

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 14, 20, 14),
            color: bg,
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
                        Text('Mes Favoris',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                            )),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 14),
                      child: Text(
                        '${favorites.length} recette${favorites.length != 1 ? 's' : ''} sauvegardée${favorites.length != 1 ? 's' : ''}',
                        style: TextStyle(fontSize: 12, color: subColor),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                if (favorites.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppColors.primary, AppColors.yellow]),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Text(
                      '${favorites.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ),

          // ── Collections row ───────────────────────────────────────────────────
          Container(
            color: bg,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _FilterChip(
                    label: '❤️ Toutes',
                    selected: _selectedCollectionId == null,
                    colors: [AppColors.primary, AppColors.yellow],
                    isDark: isDark,
                    onTap: () => setState(() => _selectedCollectionId = null),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _showCreateDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                        borderRadius: BorderRadius.circular(20),
                        color: AppColors.primary.withValues(alpha: 0.08),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded, size: 14, color: AppColors.primary),
                          SizedBox(width: 4),
                          Text('Nouvelle',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                        ],
                      ),
                    ),
                  ),
                  ...collections.map((col) {
                    final selected = _selectedCollectionId == col.id;
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _FilterChip(
                        label: '📁 ${col.name}',
                        selected: selected,
                        colors: [AppColors.purple, const Color(0xFF9B59B6)],
                        isDark: isDark,
                        onTap: () => setState(() => _selectedCollectionId = selected ? null : col.id),
                        onLongPress: () => _showCollectionOptions(col),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          // ── Recipes ───────────────────────────────────────────────────────────
          Expanded(
            child: favorites.isEmpty
                ? _buildEmptyFavorites(textColor, subColor, isDark)
                : displayedRecipes.isEmpty
                    ? _buildEmptyCollection(textColor, subColor, isDark)
                    : _buildGrid(displayedRecipes, textColor, subColor, isDark, navBar),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyFavorites(Color textColor, Color subColor, bool isDark) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red.withValues(alpha: 0.15), Colors.red.withValues(alpha: 0.05)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Center(child: Text('❤️', style: TextStyle(fontSize: 40))),
              ),
              const SizedBox(height: 20),
              Text('Pas encore de favoris',
                  style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text("Appuie sur ❤️ sur n'importe quelle\nrecette pour la retrouver ici.",
                  style: TextStyle(color: subColor, fontSize: 14, height: 1.5),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );

  Widget _buildEmptyCollection(Color textColor, Color subColor, bool isDark) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.purple.withValues(alpha: 0.15), AppColors.purple.withValues(alpha: 0.05)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Center(child: Text('📂', style: TextStyle(fontSize: 40))),
              ),
              const SizedBox(height: 20),
              Text('Collection vide',
                  style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('Dans "Toutes", appuie longuement\nsur une recette pour l\'ajouter ici.',
                  style: TextStyle(color: subColor, fontSize: 14, height: 1.5),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );

  Widget _buildGrid(List<Recipe> recipes, Color textColor, Color subColor, bool isDark, double navBar) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Text(
            '${recipes.length} recette${recipes.length > 1 ? 's' : ''}',
            style: TextStyle(color: subColor, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 16 + navBar),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.75,
            ),
            itemCount: recipes.length,
            itemBuilder: (_, i) {
              final r = recipes[i];
              return GestureDetector(
                onTap: () => context.push('/recipe/${r.id}', extra: r),
                onLongPress: () => _showCollectionSheet(r),
                child: _FavRecipeCard(
                  recipe: r,
                  isDark: isDark,
                  onUnfavorite: () => ref.read(favoritesProvider.notifier).toggle(r),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Filter chip ───────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final List<Color> colors;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.colors,
    required this.isDark,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(colors: colors)
                : null,
            color: selected ? null : (isDark ? AppColors.darkCard : Colors.white),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? Colors.transparent
                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            boxShadow: selected
                ? [BoxShadow(color: colors.first.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : (isDark ? AppColors.textDark : AppColors.textLight),
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      );
}

// ── Fav recipe card ───────────────────────────────────────────────────────────

class _FavRecipeCard extends StatelessWidget {
  final Recipe recipe;
  final bool isDark;
  final VoidCallback onUnfavorite;

  const _FavRecipeCard({
    required this.recipe,
    required this.isDark,
    required this.onUnfavorite,
  });

  int get _estimateTime => (recipe.steps.length * 5).clamp(15, 90);

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
                            ? CachedNetworkImage(
                                imageUrl: recipe.imageUrl!,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                color: isDark ? AppColors.darkBg : const Color(0xFFF5F2EE),
                                child: const Center(child: Text('🍽️', style: TextStyle(fontSize: 32))),
                              ),
                        // Gradient overlay
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.55),
                              ],
                              stops: const [0.5, 1.0],
                            ),
                          ),
                        ),
                        // Category pill
                        if (recipe.category != null)
                          Positioned(
                            bottom: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: _catColors(recipe.category),
                                ),
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
                      Row(
                        children: [
                          const Text('⏱', style: TextStyle(fontSize: 10)),
                          const SizedBox(width: 3),
                          Text(
                            '$_estimateTime min',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('🥕', style: TextStyle(fontSize: 10)),
                          const SizedBox(width: 3),
                          Text(
                            '${recipe.ingredients.length}',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Unfavorite button
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: onUnfavorite,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.favorite_rounded, color: Colors.red, size: 16),
                ),
              ),
            ),
          ],
        ),
      );

  static List<Color> _catColors(String? cat) {
    switch (cat?.toLowerCase()) {
      case 'beef': return [const Color(0xFFE74C3C), const Color(0xFFC0392B)];
      case 'chicken': return [const Color(0xFFF39C12), const Color(0xFFE67E22)];
      case 'seafood': return [const Color(0xFF3498DB), const Color(0xFF2980B9)];
      case 'vegetarian':
      case 'vegan': return [const Color(0xFF27AE60), const Color(0xFF229954)];
      case 'dessert': return [const Color(0xFF9B59B6), const Color(0xFF8E44AD)];
      case 'pasta': return [const Color(0xFFF1C40F), const Color(0xFFF39C12)];
      case 'miscellaneous': return [const Color(0xFF1ABC9C), const Color(0xFF16A085)];
      default: return [AppColors.primary, AppColors.yellow];
    }
  }
}

// ── Collection manager sheet ──────────────────────────────────────────────────

class _CollectionManagerSheet extends ConsumerWidget {
  final Recipe recipe;

  const _CollectionManagerSheet({required this.recipe});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider);
    final collections = ref.watch(collectionsProvider);
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
              width: 36, height: 4,
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
                width: 4, height: 18,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.primary, AppColors.yellow]),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(recipe.title,
                    style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Text('COLLECTIONS',
                style: TextStyle(color: subColor, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
          ),
          const SizedBox(height: 12),
          if (collections.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Aucune collection — crée-en une ci-dessous.',
                  style: TextStyle(color: subColor, fontSize: 13)),
            )
          else
            ...collections.map((col) {
              final has = col.recipeIds.contains(recipe.id);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    gradient: has ? const LinearGradient(colors: [AppColors.purple, Color(0xFF9B59B6)]) : null,
                    color: has ? null : (isDark ? AppColors.darkCard : AppColors.lightBorder),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    has ? Icons.check_rounded : Icons.add_rounded,
                    color: has ? Colors.white : subColor,
                    size: 18,
                  ),
                ),
                title: Text(col.name, style: TextStyle(color: textColor, fontSize: 14)),
                onTap: () {
                  if (has) {
                    ref.read(collectionsProvider.notifier).removeRecipe(col.id, recipe.id);
                  } else {
                    ref.read(collectionsProvider.notifier).addRecipe(col.id, recipe.id);
                  }
                },
              );
            }),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              final ctrl = TextEditingController();
              final isDark2 = ref.read(themeProvider);
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: isDark2 ? AppColors.darkCard : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: Text('Nouvelle collection',
                      style: TextStyle(
                        color: isDark2 ? AppColors.textDark : AppColors.textLight,
                        fontWeight: FontWeight.w700,
                      )),
                  content: TextField(
                    controller: ctrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Ex: Repas rapides',
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDark2 ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                    onSubmitted: (v) {
                      if (v.trim().isNotEmpty) _createAndAdd(ref, v.trim());
                      Navigator.pop(ctx);
                    },
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AppColors.primary, AppColors.yellow]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: TextButton(
                        onPressed: () {
                          if (ctrl.text.trim().isNotEmpty) _createAndAdd(ref, ctrl.text.trim());
                          Navigator.pop(ctx);
                        },
                        child: const Text('Créer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.add_rounded, color: AppColors.primary),
            label: const Text('Nouvelle collection', style: TextStyle(color: AppColors.primary)),
          ),
          const Divider(height: 24),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.favorite_rounded, color: Colors.red, size: 20),
            ),
            title: const Text('Retirer des favoris', style: TextStyle(color: Colors.red)),
            onTap: () {
              ref.read(favoritesProvider.notifier).toggle(recipe);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _createAndAdd(WidgetRef ref, String name) {
    final notifier = ref.read(collectionsProvider.notifier);
    notifier.create(name);
    final newCol = ref.read(collectionsProvider).last;
    notifier.addRecipe(newCol.id, recipe.id);
  }
}
