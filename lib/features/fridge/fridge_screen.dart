import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/models/recipe.dart';
import '../../shared/services/gemini_service.dart';
import '../../shared/services/meal_db_service.dart';

// ─── Screen ───────────────────────────────────────────────────────────────────

class FridgeScreen extends ConsumerStatefulWidget {
  const FridgeScreen({super.key});

  @override
  ConsumerState<FridgeScreen> createState() => _FridgeScreenState();
}

class _FridgeScreenState extends ConsumerState<FridgeScreen> {
  final _addController = TextEditingController();
  bool _isScanning = false;
  bool _isSuggesting = false;

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  // ── Add ingredient manually ───────────────────────────────────────────────

  void _showAddModal() {
    _addController.clear();
    final isDark = ref.read(themeProvider);
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final subColor = isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Ajouter un ingrédient', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textColor)),
            const SizedBox(height: 14),
            TextField(
              controller: _addController,
              autofocus: true,
              style: TextStyle(color: textColor),
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Ex: Tomates, Poulet, Farine…',
                hintStyle: TextStyle(color: subColor),
                filled: true,
                fillColor: isDark ? AppColors.darkBg : AppColors.lightBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.kitchen_rounded, color: AppColors.primary),
              ),
              onSubmitted: (val) {
                _doAdd(val);
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  _doAdd(_addController.text);
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Ajouter', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _doAdd(String val) {
    final trimmed = val.trim();
    if (trimmed.isEmpty) return;
    ref.read(fridgeProvider.notifier).add(trimmed);
  }

  // ── Photo → Gemini Vision ─────────────────────────────────────────────────

  Future<void> _scanPhoto() async {
    final isDark = ref.read(themeProvider);
    try {
      final picker = ImagePicker();
      final source = await _pickSource(isDark);
      if (source == null) return;

      final file = await picker.pickImage(source: source, imageQuality: 80, maxWidth: 1024);
      if (file == null) return;

      setState(() => _isScanning = true);
      final bytes = await file.readAsBytes();
      final ingredients = await GeminiService.recognizeIngredients(bytes);
      if (!mounted) return;
      setState(() => _isScanning = false);

      if (ingredients.isEmpty) {
        _showSnack('Aucun ingrédient détecté. Réessaie avec une meilleure photo.');
        return;
      }

      _showDetectedIngredients(ingredients, isDark);
    } catch (e) {
      if (mounted) setState(() => _isScanning = false);
      _showSnack('Erreur lors de l\'analyse de la photo.');
    }
  }

  Future<ImageSource?> _pickSource(bool isDark) async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
              title: const Text('Choisir depuis la galerie'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetectedIngredients(List<String> detected, bool isDark) {
    final selected = Set<String>.from(detected);
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).padding.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('🤖', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('${detected.length} ingrédients détectés',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textColor)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('Sélectionne ceux à ajouter au frigo',
                  style: TextStyle(fontSize: 13, color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: detected.map((ing) {
                  final isSelected = selected.contains(ing);
                  return GestureDetector(
                    onTap: () => setModalState(() {
                      if (isSelected) {
                        selected.remove(ing);
                      } else {
                        selected.add(ing);
                      }
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : (isDark ? AppColors.darkBg : AppColors.lightBg),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSelected) ...[
                            const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            ing,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isSelected ? Colors.white : textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (selected.isNotEmpty) {
                      ref.read(fridgeProvider.notifier).addAll(selected.toList());
                      _showSnack('${selected.length} ingrédient${selected.length > 1 ? 's' : ''} ajouté${selected.length > 1 ? 's' : ''} 🎉');
                    }
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Ajouter ${selected.length} ingrédient${selected.length > 1 ? 's' : ''}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Suggest recipes from fridge ───────────────────────────────────────────

  Future<void> _suggestRecipes() async {
    final ingredients = ref.read(fridgeProvider);
    if (ingredients.isEmpty) {
      _showSnack('Ajoute d\'abord des ingrédients à ton frigo.');
      return;
    }

    setState(() => _isSuggesting = true);
    try {
      final profile = ref.read(userProfileProvider);
      final names = await GeminiService.suggestFromFridge(ingredients, profile);
      if (!mounted) return;

      if (names.isEmpty) {
        _showSnack('Aucune suggestion trouvée. Réessaie.');
        setState(() => _isSuggesting = false);
        return;
      }

      final results = await Future.wait(
        names.take(5).map((n) => MealDbService.search(n).then((r) => r.firstOrNull)),
      );
      if (!mounted) return;
      setState(() => _isSuggesting = false);

      final recipes = results.whereType<Recipe>().toList();
      if (recipes.isEmpty) {
        _showSnack('Aucune recette MealDB trouvée pour ces suggestions.');
        return;
      }

      _showRecipeSuggestions(recipes);
    } catch (_) {
      if (mounted) setState(() => _isSuggesting = false);
      _showSnack('Erreur lors de la génération des suggestions.');
    }
  }

  void _showRecipeSuggestions(List<Recipe> recipes) {
    final isDark = ref.read(themeProvider);
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final subColor = isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary;
    final cardColor = isDark ? AppColors.darkBg : AppColors.lightBg;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('✨', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 10),
                      Text('Recettes avec ton frigo',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textColor)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${recipes.length} recettes trouvées',
                      style: TextStyle(fontSize: 13, color: subColor)),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: recipes.length,
                itemBuilder: (_, i) {
                  final r = recipes[i];
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      context.push('/recipe/${r.id}', extra: r);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
                            child: r.imageUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: r.imageUrl!,
                                    width: 80, height: 80,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => _imgPlaceholder(),
                                    errorWidget: (context, url, err) => _imgPlaceholder(),
                                  )
                                : _imgPlaceholder(),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r.title,
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
                                    maxLines: 2, overflow: TextOverflow.ellipsis),
                                if (r.category != null)
                                  Text(r.category!, style: TextStyle(fontSize: 12, color: subColor)),
                              ],
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(right: 12),
                            child: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.primary),
                          ),
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
    );
  }

  Widget _imgPlaceholder() => Container(
        width: 80, height: 80,
        color: AppColors.darkBorder,
        child: const Center(child: Icon(Icons.restaurant_rounded, color: AppColors.primary, size: 24)),
      );

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF323232),
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final ingredients = ref.watch(fridgeProvider);
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final subColor = isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary;
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Mon Frigo', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: textColor)),
                        const SizedBox(height: 2),
                        Text(
                          ingredients.isEmpty
                              ? 'Frigo vide'
                              : '${ingredients.length} ingrédient${ingredients.length > 1 ? 's' : ''}',
                          style: TextStyle(fontSize: 13, color: subColor),
                        ),
                      ],
                    ),
                  ),
                  // Barcode scanner
                  _iconBtn(
                    icon: Icons.qr_code_scanner_rounded,
                    color: AppColors.primary,
                    onTap: () => context.push('/scanner'),
                  ),
                  const SizedBox(width: 8),
                  // Photo IA
                  _isScanning
                      ? const Padding(
                          padding: EdgeInsets.all(9),
                          child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                        )
                      : _iconBtn(
                          icon: Icons.camera_alt_rounded,
                          color: AppColors.blue,
                          onTap: _scanPhoto,
                        ),
                  const SizedBox(width: 8),
                  // Clear all
                  if (ingredients.isNotEmpty)
                    _iconBtn(
                      icon: Icons.delete_outline_rounded,
                      color: Colors.red,
                      onTap: () => _confirmClear(),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Ingrédients ───────────────────────────────────────────────────
            Expanded(
              child: ingredients.isEmpty
                  ? _emptyState(textColor, subColor)
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Info IA photo
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.blue.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.camera_alt_rounded, color: AppColors.blue, size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Prends en photo ton frigo pour détecter les ingrédients automatiquement.',
                                    style: TextStyle(fontSize: 12, color: isDark ? AppColors.textDark : AppColors.textLight),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Chips ingrédients
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: ingredients.map((ing) => _IngredientChip(
                              name: ing,
                              isDark: isDark,
                              textColor: textColor,
                              onRemove: () => ref.read(fridgeProvider.notifier).remove(ing),
                            )).toList(),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),

      // ── Bottom actions ────────────────────────────────────────────────────
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Plan semaine IA depuis frigo
          if (ingredients.isNotEmpty) ...[
            FloatingActionButton.extended(
              heroTag: 'fridgeplan',
              onPressed: () => context.push('/fridge-plan'),
              backgroundColor: AppColors.purple,
              foregroundColor: Colors.white,
              icon: const Text('📅', style: TextStyle(fontSize: 16)),
              label: const Text('Plan semaine', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 10),
          ],
          // Trouver recettes
          if (ingredients.isNotEmpty)
            FloatingActionButton.extended(
              heroTag: 'suggest',
              onPressed: _isSuggesting ? null : _suggestRecipes,
              backgroundColor: AppColors.green,
              foregroundColor: Colors.white,
              icon: _isSuggesting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('✨', style: TextStyle(fontSize: 16)),
              label: const Text('Trouver des recettes', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          const SizedBox(height: 10),
          // Ajouter
          FloatingActionButton(
            heroTag: 'add',
            onPressed: _showAddModal,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            child: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }

  Widget _iconBtn({required IconData icon, required Color color, required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 20, color: color),
        ),
      );

  Widget _emptyState(Color textColor, Color subColor) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🧊', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              Text('Frigo vide', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textColor)),
              const SizedBox(height: 8),
              Text(
                'Ajoute tes ingrédients manuellement\nou prends une photo de ton frigo.',
                style: TextStyle(fontSize: 14, color: subColor, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );

  void _confirmClear() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Vider le frigo ?'),
        content: const Text('Tous les ingrédients seront supprimés.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Annuler')),
          TextButton(
            onPressed: () {
              ref.read(fridgeProvider.notifier).clear();
              Navigator.pop(dialogCtx);
            },
            child: const Text('Vider', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ─── Ingredient Chip ──────────────────────────────────────────────────────────

class _IngredientChip extends StatelessWidget {
  final String name;
  final bool isDark;
  final Color textColor;
  final VoidCallback onRemove;

  const _IngredientChip({
    required this.name,
    required this.isDark,
    required this.textColor,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textColor)),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded, size: 14, color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
