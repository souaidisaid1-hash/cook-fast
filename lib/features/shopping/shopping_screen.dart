import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/models/shopping_item.dart';
import 'order_ingredients_sheet.dart';

class ShoppingScreen extends ConsumerStatefulWidget {
  const ShoppingScreen({super.key});

  @override
  ConsumerState<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends ConsumerState<ShoppingScreen> {
  final _addController = TextEditingController();
  final Set<String> _collapsed = {};

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final items = ref.watch(shoppingProvider);
    final notifier = ref.read(shoppingProvider.notifier);
    final bg = isDark ? AppColors.darkBg : const Color(0xFFF5F2EE);
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final subColor = isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary;
    final cardColor = isDark ? AppColors.darkCard : Colors.white;

    final byCategory = notifier.byCategory;
    final unchecked = notifier.uncheckedCount;
    final checkedCount = items.length - unchecked;

    // Ordre des catégories
    const categoryOrder = [
      'Fruits & Légumes',
      'Viandes & Poissons',
      'Produits laitiers',
      'Féculents',
      'Épicerie',
      'Autre',
    ];
    final sortedCategories = [
      ...categoryOrder.where((c) => byCategory.containsKey(c)),
      ...byCategory.keys.where((c) => !categoryOrder.contains(c)),
    ];

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
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
                            Text('Liste de courses', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: textColor)),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 14),
                          child: Text(
                            items.isEmpty ? 'Liste vide' : '$unchecked article${unchecked > 1 ? 's' : ''} restant${unchecked > 1 ? 's' : ''}',
                            style: TextStyle(fontSize: 12, color: subColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (items.isNotEmpty) ...[
                    GestureDetector(
                      onTap: () => _showOrderSheet(context, items),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, Color(0xFFE5501A)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.local_shipping_rounded, size: 16, color: Colors.white),
                            SizedBox(width: 4),
                            Text('Commander', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (checkedCount > 0)
                      _iconAction(
                        icon: Icons.cleaning_services_rounded,
                        color: AppColors.primary,
                        onTap: () => notifier.clearChecked(),
                      ),
                    const SizedBox(width: 8),
                    _iconAction(
                      icon: Icons.delete_outline_rounded,
                      color: Colors.red,
                      onTap: () => _confirmClear(context, notifier),
                    ),
                  ],
                ],
              ),
            ),

            // ── Progress bar ─────────────────────────────────────────────────
            if (items.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Progression', style: TextStyle(fontSize: 12, color: subColor)),
                        Text('$checkedCount/${items.length}', style: TextStyle(fontSize: 12, color: subColor)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Stack(
                      children: [
                        Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: items.isEmpty ? 0 : checkedCount / items.length,
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [AppColors.green, Color(0xFF27AE60)]),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 12),

            // ── Liste ─────────────────────────────────────────────────────────
            Expanded(
              child: items.isEmpty
                  ? _emptyState(isDark, textColor, subColor)
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: sortedCategories.length,
                      itemBuilder: (context, i) {
                        final cat = sortedCategories[i];
                        final catItems = byCategory[cat]!;
                        final isCollapsed = _collapsed.contains(cat);
                        final catChecked = catItems.where((i) => i.isChecked).length;

                        return _CategorySection(
                          category: cat,
                          items: catItems,
                          isCollapsed: isCollapsed,
                          catChecked: catChecked,
                          isDark: isDark,
                          textColor: textColor,
                          subColor: subColor,
                          cardColor: cardColor,
                          onToggleCollapse: () => setState(() {
                            if (isCollapsed) {
                              _collapsed.remove(cat);
                            } else {
                              _collapsed.add(cat);
                            }
                          }),
                          onToggleItem: (id) => notifier.toggle(id),
                          onRemoveItem: (id) => notifier.remove(id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),

      // ── FABs ────────────────────────────────────────────────────────────────
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'scan_fab',
            onPressed: () => context.push('/scanner'),
            backgroundColor: AppColors.darkCard,
            foregroundColor: AppColors.primary,
            mini: true,
            child: const Icon(Icons.qr_code_scanner_rounded),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'add_fab',
            onPressed: () => _showAddModal(context, ref, isDark, textColor, subColor, cardColor),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Ajouter', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _iconAction({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
      );

  Widget _emptyState(bool isDark, Color textColor, Color subColor) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🛒', style: const TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              Text('Liste vide', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textColor)),
              const SizedBox(height: 8),
              Text(
                'Ajoute des articles manuellement\nou génère depuis ton plan de semaine.',
                style: TextStyle(fontSize: 14, color: subColor, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );

  void _confirmClear(BuildContext context, ShoppingNotifier notifier) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Vider la liste ?'),
        content: const Text('Tous les articles seront supprimés.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Annuler')),
          TextButton(
            onPressed: () {
              notifier.clear();
              Navigator.pop(dialogCtx);
            },
            child: const Text('Vider', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAddModal(BuildContext context, WidgetRef ref, bool isDark, Color textColor, Color subColor, Color cardColor) {
    _addController.clear();
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
            Text('Ajouter un article', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textColor)),
            const SizedBox(height: 14),
            TextField(
              controller: _addController,
              autofocus: true,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: 'Ex: Tomates, Poulet, Farine…',
                hintStyle: TextStyle(color: subColor),
                filled: true,
                fillColor: isDark ? AppColors.darkBg : AppColors.lightBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.shopping_basket_outlined, color: AppColors.primary),
              ),
              onSubmitted: (val) {
                _doAdd(val, ref);
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  _doAdd(_addController.text, ref);
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

  void _doAdd(String val, WidgetRef ref) {
    final trimmed = val.trim();
    if (trimmed.isEmpty) return;
    ref.read(shoppingProvider.notifier).add(trimmed);
  }

  void _showOrderSheet(BuildContext context, List<ShoppingItem> items) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OrderIngredientsSheet(items: items),
    );
  }
}

// ── Category Section ──────────────────────────────────────────────────────────

class _CategorySection extends StatelessWidget {
  final String category;
  final List<ShoppingItem> items;
  final bool isCollapsed;
  final int catChecked;
  final bool isDark;
  final Color textColor;
  final Color subColor;
  final Color cardColor;
  final VoidCallback onToggleCollapse;
  final void Function(String id) onToggleItem;
  final void Function(String id) onRemoveItem;

  const _CategorySection({
    required this.category,
    required this.items,
    required this.isCollapsed,
    required this.catChecked,
    required this.isDark,
    required this.textColor,
    required this.subColor,
    required this.cardColor,
    required this.onToggleCollapse,
    required this.onToggleItem,
    required this.onRemoveItem,
  });

  static const _categoryIcons = <String, String>{
    'Fruits & Légumes': '🥦',
    'Viandes & Poissons': '🥩',
    'Produits laitiers': '🥛',
    'Féculents': '🍞',
    'Épicerie': '🫙',
    'Autre': '📦',
  };

  @override
  Widget build(BuildContext context) {
    final emoji = _categoryIcons[category] ?? '🛒';
    final allChecked = catChecked == items.length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header catégorie
          InkWell(
            onTap: onToggleCollapse,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      category,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: allChecked ? subColor : textColor),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: allChecked ? AppColors.green.withValues(alpha: 0.15) : AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$catChecked/${items.length}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: allChecked ? AppColors.green : AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isCollapsed ? Icons.expand_more_rounded : Icons.expand_less_rounded,
                    size: 20,
                    color: subColor,
                  ),
                ],
              ),
            ),
          ),

          // Items
          if (!isCollapsed)
            ...items.map((item) => _ItemTile(
                  item: item,
                  isDark: isDark,
                  textColor: textColor,
                  subColor: subColor,
                  onToggle: () => onToggleItem(item.id),
                  onRemove: () => onRemoveItem(item.id),
                )),

          if (!isCollapsed) const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ── Item Tile ─────────────────────────────────────────────────────────────────

class _ItemTile extends StatelessWidget {
  final ShoppingItem item;
  final bool isDark;
  final Color textColor;
  final Color subColor;
  final VoidCallback onToggle;
  final VoidCallback onRemove;

  const _ItemTile({
    required this.item,
    required this.isDark,
    required this.textColor,
    required this.subColor,
    required this.onToggle,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.red),
      ),
      onDismissed: (_) => onRemove(),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(
            children: [
              // Checkbox custom
              GestureDetector(
                onTap: onToggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: item.isChecked ? AppColors.green : Colors.transparent,
                    border: Border.all(
                      color: item.isChecked ? AppColors.green : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: item.isChecked
                      ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              // Nom + recette
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: item.isChecked ? subColor : textColor,
                        decoration: item.isChecked ? TextDecoration.lineThrough : null,
                        decorationColor: subColor,
                      ),
                    ),
                    if (item.recipeTitle != null)
                      Text(
                        item.recipeTitle!,
                        style: TextStyle(fontSize: 11, color: subColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              // Quantité
              if (item.measure.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 80),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      item.measure,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: item.isChecked ? subColor : AppColors.primary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
