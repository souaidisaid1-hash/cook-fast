import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../models/recipe.dart';
import '../providers/app_providers.dart';
import '../../core/theme/app_theme.dart';

class RecipeCard extends ConsumerWidget {
  final Recipe recipe;
  final bool showFavorite;

  const RecipeCard({super.key, required this.recipe, this.showFavorite = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider);
    final isFav = ref.watch(favoritesProvider).any((fav) => fav.id == recipe.id);
    final family = ref.watch(familyProfilesProvider);
    final compatible = family.isEmpty || ref.read(familyProfilesProvider.notifier).isCompatible(recipe);

    return GestureDetector(
      onTap: () => context.push('/recipe/${recipe.id}', extra: recipe),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: recipe.imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: recipe.imageUrl!,
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => _shimmer(isDark),
                          errorWidget: (_, __, ___) => _placeholder(isDark),
                        )
                      : _placeholder(isDark),
                ),
                if (recipe.category != null)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        recipe.category!,
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                if (showFavorite)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => ref.read(favoritesProvider.notifier).toggle(recipe),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: isFav ? Colors.red : Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                if (!compatible)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('⚠️ famille', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textDark : AppColors.textLight,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (recipe.cookTimeMinutes != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined, size: 13, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          '${recipe.cookTimeMinutes} min',
                          style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w500),
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
    );
  }

  Widget _shimmer(bool isDark) => Shimmer.fromColors(
        baseColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        highlightColor: isDark ? AppColors.darkCard : Colors.grey[100]!,
        child: Container(height: 150, color: Colors.white),
      );

  Widget _placeholder(bool isDark) => Container(
        height: 150,
        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        child: const Center(child: Icon(Icons.restaurant_rounded, size: 40, color: AppColors.primary)),
      );
}

class RecipeCardHorizontal extends ConsumerWidget {
  final Recipe recipe;

  const RecipeCardHorizontal({super.key, required this.recipe});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider);
    final isFav = ref.watch(favoritesProvider).any((fav) => fav.id == recipe.id);

    return GestureDetector(
      onTap: () => context.push('/recipe/${recipe.id}', extra: recipe),
      child: Container(
        width: 180,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: recipe.imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: recipe.imageUrl!,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            height: 120,
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          ),
                          errorWidget: (_, __, ___) => Container(
                            height: 120,
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                            child: const Icon(Icons.restaurant_rounded, color: AppColors.primary),
                          ),
                        )
                      : Container(
                          height: 120,
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          child: const Icon(Icons.restaurant_rounded, color: AppColors.primary),
                        ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => ref.read(favoritesProvider.notifier).toggle(recipe),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: isFav ? Colors.red : Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                recipe.title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textDark : AppColors.textLight,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
