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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouvelle collection'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Ex: Repas rapides'),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) {
              ref.read(collectionsProvider.notifier).create(v.trim());
            }
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                ref.read(collectionsProvider.notifier).create(ctrl.text.trim());
              }
              Navigator.pop(ctx);
            },
            child:
                const Text('Créer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showCollectionOptions(RecipeCollection col) {
    final isDark = ref.read(themeProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        final ctrl = TextEditingController(text: col.name);
        return Padding(
          padding: EdgeInsets.fromLTRB(
              20, 16, 20, 16 + MediaQuery.of(context).viewPadding.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(col.name,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: isDark ? AppColors.textDark : AppColors.textLight)),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading:
                    const Icon(Icons.edit_rounded, color: AppColors.primary),
                title: const Text('Renommer'),
                onTap: () {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Renommer'),
                      content: TextField(
                        controller: ctrl,
                        autofocus: true,
                        decoration:
                            const InputDecoration(hintText: 'Nouveau nom'),
                        onSubmitted: (v) {
                          if (v.trim().isNotEmpty) {
                            ref
                                .read(collectionsProvider.notifier)
                                .rename(col.id, v.trim());
                          }
                          Navigator.pop(ctx);
                        },
                      ),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Annuler')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary),
                          onPressed: () {
                            if (ctrl.text.trim().isNotEmpty) {
                              ref
                                  .read(collectionsProvider.notifier)
                                  .rename(col.id, ctrl.text.trim());
                            }
                            Navigator.pop(ctx);
                          },
                          child: const Text('OK',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.delete_outline_rounded,
                    color: Colors.red),
                title: const Text('Supprimer',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  ref.read(collectionsProvider.notifier).delete(col.id);
                  if (_selectedCollectionId == col.id) {
                    setState(() => _selectedCollectionId = null);
                  }
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
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final subColor =
        isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary;
    final navBar = MediaQuery.of(context).viewPadding.bottom;

    final favorites = ref.watch(favoritesProvider);
    final collections = ref.watch(collectionsProvider);

    final displayedRecipes = _selectedCollectionId == null
        ? favorites
        : () {
            final col = collections.firstWhere(
              (c) => c.id == _selectedCollectionId,
              orElse: () =>
                  const RecipeCollection(id: '', name: '', recipeIds: []),
            );
            return favorites
                .where((r) => col.recipeIds.contains(r.id))
                .toList();
          }();

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        iconTheme: IconThemeData(color: textColor),
        title: Text('Mes Favoris',
            style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 17, color: textColor)),
        elevation: 0,
        actions: [
          if (favorites.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${favorites.length}',
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Collections row ───────────────────────────────────────────────────
          Container(
            color: surfaceColor,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _CollectionChip(
                    label: 'Toutes',
                    selected: _selectedCollectionId == null,
                    color: AppColors.primary,
                    isDark: isDark,
                    onTap: () => setState(() => _selectedCollectionId = null),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _showCreateDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder),
                        borderRadius: BorderRadius.circular(20),
                        color: isDark
                            ? AppColors.darkCard
                            : AppColors.lightCard,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_rounded,
                              size: 14, color: AppColors.primary),
                          const SizedBox(width: 4),
                          const Text('Nouvelle',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary)),
                        ],
                      ),
                    ),
                  ),
                  ...collections.map((col) {
                    final selected = _selectedCollectionId == col.id;
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _CollectionChip(
                        label: col.name,
                        selected: selected,
                        color: AppColors.purple,
                        isDark: isDark,
                        onTap: () => setState(() =>
                            _selectedCollectionId = selected ? null : col.id),
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
                ? _buildEmptyFavorites(textColor, subColor)
                : displayedRecipes.isEmpty
                    ? _buildEmptyCollection(textColor, subColor)
                    : _buildGrid(displayedRecipes, cardColor, textColor,
                        subColor, isDark, navBar),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyFavorites(Color textColor, Color subColor) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('❤️', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 16),
              Text('Pas encore de favoris',
                  style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Appuie sur ❤️ sur n\'importe quelle\nrecette pour la retrouver ici.',
                  style: TextStyle(color: subColor, fontSize: 14, height: 1.5),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );

  Widget _buildEmptyCollection(Color textColor, Color subColor) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('📂', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 16),
              Text('Collection vide',
                  style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Dans "Toutes", appuie longuement\nsur une recette pour l\'ajouter ici.',
                  style: TextStyle(color: subColor, fontSize: 14, height: 1.5),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );

  Widget _buildGrid(List<Recipe> recipes, Color cardColor, Color textColor,
      Color subColor, bool isDark, double navBar) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Text(
            '${recipes.length} recette${recipes.length > 1 ? 's' : ''}',
            style: TextStyle(
                color: subColor, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 16 + navBar),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.78,
            ),
            itemCount: recipes.length,
            itemBuilder: (_, i) {
              final r = recipes[i];
              return GestureDetector(
                onTap: () => context.push('/recipe/${r.id}', extra: r),
                onLongPress: () => _showCollectionSheet(r),
                child: _FavRecipeCard(
                  recipe: r,
                  cardColor: cardColor,
                  textColor: textColor,
                  subColor: subColor,
                  isDark: isDark,
                  onUnfavorite: () =>
                      ref.read(favoritesProvider.notifier).toggle(r),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _CollectionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _CollectionChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.isDark,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.18)
                : (isDark ? AppColors.darkCard : AppColors.lightCard),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? color
                  : (isDark
                      ? AppColors.darkBorder
                      : AppColors.lightBorder),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? color
                  : (isDark ? AppColors.textDark : AppColors.textLight),
              fontSize: 12,
              fontWeight:
                  selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      );
}

class _FavRecipeCard extends StatelessWidget {
  final Recipe recipe;
  final Color cardColor;
  final Color textColor;
  final Color subColor;
  final bool isDark;
  final VoidCallback onUnfavorite;

  const _FavRecipeCard({
    required this.recipe,
    required this.cardColor,
    required this.textColor,
    required this.subColor,
    required this.isDark,
    required this.onUnfavorite,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
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
                          height: 110,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          height: 110,
                          color: isDark
                              ? AppColors.darkBg
                              : AppColors.lightBg,
                          child: const Center(
                              child: Text('🍽️',
                                  style: TextStyle(fontSize: 30)))),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
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
                      if (recipe.category != null) ...[
                        const SizedBox(height: 4),
                        Text(recipe.category!,
                            style:
                                TextStyle(color: subColor, fontSize: 10),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(Icons.touch_app_rounded,
                              size: 10,
                              color: subColor.withValues(alpha: 0.5)),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text('Appui long → collections',
                                style: TextStyle(
                                    color: subColor.withValues(alpha: 0.5),
                                    fontSize: 9,
                                    fontStyle: FontStyle.italic),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: onUnfavorite,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.favorite_rounded,
                      color: Colors.red, size: 16),
                ),
              ),
            ),
          ],
        ),
      );
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
          Text(recipe.title,
              style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w700),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text('COLLECTIONS',
              style: TextStyle(
                  color: subColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8)),
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
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: has
                        ? AppColors.purple.withValues(alpha: 0.15)
                        : (isDark
                            ? AppColors.darkCard
                            : AppColors.lightBorder),
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
                    ref
                        .read(collectionsProvider.notifier)
                        .removeRecipe(col.id, recipe.id);
                  } else {
                    ref
                        .read(collectionsProvider.notifier)
                        .addRecipe(col.id, recipe.id);
                  }
                },
              );
            }),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              final ctrl = TextEditingController();
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Nouvelle collection'),
                  content: TextField(
                    controller: ctrl,
                    autofocus: true,
                    decoration:
                        const InputDecoration(hintText: 'Ex: Repas rapides'),
                    onSubmitted: (v) {
                      if (v.trim().isNotEmpty) {
                        _createAndAdd(ref, v.trim());
                      }
                      Navigator.pop(ctx);
                    },
                  ),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Annuler')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary),
                      onPressed: () {
                        if (ctrl.text.trim().isNotEmpty) {
                          _createAndAdd(ref, ctrl.text.trim());
                        }
                        Navigator.pop(ctx);
                      },
                      child: const Text('Créer',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.add_rounded, color: AppColors.primary),
            label: const Text('Nouvelle collection',
                style: TextStyle(color: AppColors.primary)),
          ),
          const Divider(height: 24),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading:
                const Icon(Icons.favorite_rounded, color: Colors.red),
            title: const Text('Retirer des favoris',
                style: TextStyle(color: Colors.red)),
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
