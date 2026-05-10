import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/shopping_item.dart';

class _Store {
  final String emoji;
  final String name;
  final String sub;
  final String url;
  final Color color;

  const _Store({
    required this.emoji,
    required this.name,
    required this.sub,
    required this.url,
    required this.color,
  });
}

const _stores = [
  _Store(
    emoji: '🔵',
    name: 'Carrefour Drive',
    sub: 'Retrait en magasin',
    url: 'https://www.carrefour.fr/drive',
    color: Color(0xFF004A9F),
  ),
  _Store(
    emoji: '🟡',
    name: 'E.Leclerc Drive',
    sub: 'Retrait en magasin',
    url: 'https://www.e.leclerc/',
    color: Color(0xFFFFC200),
  ),
  _Store(
    emoji: '🛒',
    name: 'Amazon Fresh',
    sub: 'Livraison rapide',
    url: 'https://www.amazon.fr/alm/storefront',
    color: Color(0xFFFF9900),
  ),
  _Store(
    emoji: '🔴',
    name: 'Intermarché',
    sub: 'Drive & livraison',
    url: 'https://www.intermarche.com/drive',
    color: Color(0xFFD10000),
  ),
  _Store(
    emoji: '🟣',
    name: 'Monoprix',
    sub: 'Livraison à domicile',
    url: 'https://www.monoprix.fr/courses-en-ligne',
    color: Color(0xFF6A0DAD),
  ),
];

// Ingrédients de placard à décocher par défaut
const _pantryDefaults = [
  'salt', 'sel', 'pepper', 'poivre', 'flour', 'farine', 'sugar', 'sucre',
  'oil', 'huile', 'water', 'eau', 'baking powder', 'baking soda', 'bicarbonate',
  'levure', 'vinegar', 'vinaigre', 'butter', 'beurre',
];

bool _isPantry(String name) {
  final n = name.toLowerCase();
  return _pantryDefaults.any((p) => n.contains(p));
}

class OrderIngredientsSheet extends StatefulWidget {
  final List<ShoppingItem> items;

  const OrderIngredientsSheet({super.key, required this.items});

  @override
  State<OrderIngredientsSheet> createState() => _OrderIngredientsSheetState();
}

class _OrderIngredientsSheetState extends State<OrderIngredientsSheet> {
  late final Set<String> _selected;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    // Sélectionne tout sauf les ingrédients de placard courants
    _selected = {
      for (final item in widget.items)
        if (!_isPantry(item.name)) item.id,
    };
    // Si tout est décoché (recette très basique), tout sélectionner
    if (_selected.isEmpty) {
      _selected.addAll(widget.items.map((i) => i.id));
    }
  }

  List<ShoppingItem> get _selectedItems =>
      widget.items.where((i) => _selected.contains(i.id)).toList();

  String get _listText => _selectedItems.map((item) {
        final qty = item.measure.isNotEmpty ? ' (${item.measure})' : '';
        return '• ${item.name}$qty';
      }).join('\n');

  Future<void> _copyList() async {
    if (_selectedItems.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _listText));
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  Future<void> _openStore(_Store store) async {
    await _copyList();
    await launchUrl(Uri.parse(store.url), mode: LaunchMode.externalApplication);
  }

  void _toggleItem(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final navBar = MediaQuery.of(context).viewPadding.bottom;
    final count = _selectedItems.length;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + navBar),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.darkBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Titre
          Row(
            children: [
              const Text('🛒', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Commander mes courses',
                      style: TextStyle(
                        color: AppColors.textDark,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      count == 0
                          ? 'Aucun article sélectionné'
                          : '$count article${count > 1 ? 's' : ''} sélectionné${count > 1 ? 's' : ''}',
                      style: const TextStyle(
                          color: AppColors.textDarkSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              // Tout sélectionner / désélectionner
              TextButton(
                onPressed: () => setState(() {
                  if (_selected.length == widget.items.length) {
                    _selected.clear();
                  } else {
                    _selected.addAll(widget.items.map((i) => i.id));
                  }
                }),
                child: Text(
                  _selected.length == widget.items.length ? 'Tout retirer' : 'Tout sélectionner',
                  style: const TextStyle(
                      color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Liste des ingrédients avec cases à cocher
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: AppColors.darkBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: widget.items.length,
              itemBuilder: (_, i) {
                final item = widget.items[i];
                final isOn = _selected.contains(item.id);
                return InkWell(
                  onTap: () => _toggleItem(item.id),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: isOn ? AppColors.primary : Colors.transparent,
                            border: Border.all(
                              color: isOn ? AppColors.primary : AppColors.darkBorder,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: isOn
                              ? const Icon(Icons.check_rounded,
                                  size: 14, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.name,
                            style: TextStyle(
                              color: isOn
                                  ? AppColors.textDark
                                  : AppColors.textDarkSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              decoration: isOn ? null : TextDecoration.lineThrough,
                              decorationColor: AppColors.textDarkSecondary,
                            ),
                          ),
                        ),
                        if (item.measure.isNotEmpty)
                          Text(
                            item.measure,
                            style: TextStyle(
                              color: isOn
                                  ? AppColors.primary
                                  : AppColors.textDarkSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // Copier
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: count > 0 ? _copyList : null,
              icon: Icon(
                _copied ? Icons.check_rounded : Icons.copy_rounded,
                size: 18,
                color: _copied ? AppColors.green : AppColors.textDarkSecondary,
              ),
              label: Text(
                _copied ? 'Liste copiée !' : 'Copier la liste ($count)',
                style: TextStyle(
                  color: _copied ? AppColors.green : AppColors.textDarkSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                    color: _copied ? AppColors.green : AppColors.darkBorder),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          const SizedBox(height: 16),

          const Text(
            'OUVRIR DANS',
            style: TextStyle(
              color: AppColors.textDarkSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),

          const SizedBox(height: 8),

          // Enseignes
          ...(_stores.map((store) => _StoreTile(
                store: store,
                enabled: count > 0,
                onTap: () => _openStore(store),
              ))),
        ],
      ),
    );
  }
}

class _StoreTile extends StatelessWidget {
  final _Store store;
  final bool enabled;
  final VoidCallback onTap;

  const _StoreTile(
      {required this.store, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: AppColors.darkBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: store.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                    child: Text(store.emoji,
                        style: const TextStyle(fontSize: 18))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(store.name,
                        style: const TextStyle(
                            color: AppColors.textDark,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    Text(store.sub,
                        style: const TextStyle(
                            color: AppColors.textDarkSecondary, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.open_in_new_rounded,
                  color: AppColors.textDarkSecondary, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
